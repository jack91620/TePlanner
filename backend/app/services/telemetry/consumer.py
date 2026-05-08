"""ZMQ consumer that drains fleet-telemetry's record stream into our
AutomationState table.

Lifecycle is bound to FastAPI's lifespan — the consumer task is
cancellable; cancelling closes the SUB socket cleanly.

fleet-telemetry's ZMQ dispatcher publishes each record as a 2-frame
multipart message via ``BuildTopicName(namespace, recordName)``, which
formats topic as ``"<namespace>_<recordName>"`` — e.g.
``"teplanner_telemetry_V"``. The payload is the raw flatbuffer-decoded
PayloadBytes; with ``transmit_decoded_records: true`` in
fleet-telemetry config that's already JSON-encoded.

We subscribe only to V (vehicle data) for now. Connectivity events
(online / offline) are useful but not yet consumed.
"""

from __future__ import annotations

import asyncio
import json
import logging
from datetime import datetime, timezone
from typing import Optional

from app.config import settings
from app.db.session import async_session
from app.services.automation.base import AutomationSettings
from app.services.automation.engine import AutomationEngine
from app.services.automation.pending_resolver import check_and_resolve
from app.services.command_queue import drain_for_vehicle
from app.services.telemetry.mapping import (
    map_connectivity_payload,
    map_v_payload,
)
from app.services.telemetry.snapshot import build_snapshot_from_telemetry
from app.services.telemetry.state_writer import TelemetryStateWriter

logger = logging.getLogger(__name__)


# Must match fleet-telemetry's `namespace` config field — fleet-tel
# prepends it to every record's topic via BuildTopicName.
TELEMETRY_NAMESPACE = "teplanner_telemetry"

# Coalesce engine evaluations within this many seconds per
# (user, vehicle). Telemetry can deliver bursts (multiple field deltas
# in the same V record, or multiple V records back-to-back); we want
# the rules to see the *settled* state, not run once per field.
ENGINE_DEBOUNCE_SECONDS = 0.5


def _parse_v_timestamp(payload: dict) -> datetime:
    """Pick the most authoritative timestamp from a V record. Tesla
    fills ``CreatedAt`` / ``createdAt`` (vehicle clock) most reliably;
    ``time`` is the server's receive time. Connectivity records use
    a unix-int ``CreatedAt``; fall through to ``time`` for those.
    Never throw — always return *some* datetime.
    """
    candidates = [
        payload.get("createdAt"),
        payload.get("created_at"),
    ]
    data = payload.get("data")
    if isinstance(data, dict):
        candidates.append(data.get("CreatedAt"))
    candidates.append(payload.get("time"))

    for raw in candidates:
        if isinstance(raw, str) and raw:
            try:
                return datetime.fromisoformat(raw.replace("Z", "+00:00"))
            except ValueError:
                continue
        if isinstance(raw, (int, float)) and raw > 0:
            try:
                return datetime.fromtimestamp(raw, tz=timezone.utc)
            except (ValueError, OSError, OverflowError):
                continue
    return datetime.now(timezone.utc)


def _vin_for_payload(payload: dict) -> Optional[str]:
    # protojson form: payload-level "vin"
    vin = payload.get("vin")
    if isinstance(vin, str) and vin:
        return vin
    # logger envelope form
    metadata = payload.get("metadata") or {}
    vin = metadata.get("vin")
    if isinstance(vin, str) and vin:
        return vin
    data = payload.get("data")
    if isinstance(data, dict) and isinstance(data.get("Vin"), str):
        return data["Vin"]
    return None


async def _process_v_record(
    writer: TelemetryStateWriter,
    payload: dict,
    engine: Optional[AutomationEngine] = None,
    debounce_until: Optional[dict] = None,
) -> None:
    vin = _vin_for_payload(payload)
    if not vin:
        logger.debug("telemetry V record without VIN, skipping")
        return
    data = payload.get("data") or {}
    observed_at = _parse_v_timestamp(payload)

    async with async_session() as db:
        try:
            user_id = await writer.resolve_user_id(db, vin)
            if user_id is None:
                logger.debug("telemetry: no user mapped for VIN %s", vin)
                return
            transitions = 0
            for entity, value in map_v_payload(data):
                changed = await writer.record(
                    db,
                    user_id=user_id,
                    vehicle_id=vin,
                    entity=entity,
                    value=value,
                    observed_at=observed_at,
                )
                if changed:
                    transitions += 1
            if transitions:
                await db.commit()
            else:
                await db.rollback()
        except Exception:
            logger.exception("telemetry record write failed (vin=%s)", vin)
            await db.rollback()
            return

        # Phase 6: drive the engine on every transition. We rebuild the
        # snapshot from telemetry rows (single source of truth post-
        # polling) and let the engine evaluate rules + fire APNs.
        if not transitions or engine is None:
            return

        if debounce_until is not None:
            now_ts = datetime.now(timezone.utc).timestamp()
            cooldown = debounce_until.get((user_id, vin), 0.0)
            if now_ts < cooldown:
                return
            debounce_until[(user_id, vin)] = now_ts + ENGINE_DEBOUNCE_SECONDS

        try:
            async with async_session() as eval_db:
                snap = await build_snapshot_from_telemetry(
                    eval_db, user_id=user_id, vehicle_id=vin,
                )
                result = await engine.run_for_vehicle(
                    eval_db,
                    user_id=user_id,
                    vehicle_id=vin,
                    state=snap,
                    settings=AutomationSettings(),
                )
                # Phase 9 — resolve any pending VCP commands now that
                # we have a fresh snapshot. Match → confirmed_at;
                # > 60 s elapsed → timed_out_at. Same eval_db, single
                # commit so partial-state never leaks.
                await check_and_resolve(
                    eval_db,
                    user_id=user_id, vehicle_id=vin, snap=snap,
                )
                await eval_db.commit()
            if result.pushed_count or result.cleared_count:
                logger.info(
                    "telemetry-driven tick user=%s vin=%s pushed=%s cleared=%s",
                    user_id, vin, result.pushed_count, result.cleared_count,
                )
        except Exception:
            logger.exception("telemetry-driven engine tick failed (vin=%s)", vin)


async def _drain_if_came_online(
    db, user_id: int, vin: str, payload: dict,
) -> None:
    """Phase 10 — when telemetry says the car just came back online,
    flush any commands that were queued while it was asleep. Errors
    are isolated so one bad row doesn't block subsequent drains."""
    data = payload.get("data") if isinstance(payload, dict) else None
    if not isinstance(data, dict):
        return
    if data.get("Status") != "CONNECTED":
        return
    try:
        summary = await drain_for_vehicle(
            db, user_id=user_id, vin=vin,
        )
        if summary.get("sent") or summary.get("dropped"):
            logger.info(
                "drain on connectivity-online user=%s vin=%s %s",
                user_id, vin, summary,
            )
    except Exception:
        logger.exception("queue drain after CONNECTED failed (vin=%s)", vin)


async def _process_connectivity_record(
    writer: TelemetryStateWriter,
    payload: dict,
    engine: Optional[AutomationEngine] = None,
) -> None:
    """Phase 8: ingest fleet-telemetry's connectivity channel as the
    ``vehicle.connectivity`` entity (CONNECTED / DISCONNECTED). Drives
    the engine on each transition so a rule can react to online/offline
    edges via the existing ``state_transition`` trigger."""
    vin = _vin_for_payload(payload)
    if not vin:
        return
    observed_at = _parse_v_timestamp(payload)

    async with async_session() as db:
        try:
            user_id = await writer.resolve_user_id(db, vin)
            if user_id is None:
                return
            transitions = 0
            for entity, value in map_connectivity_payload(payload):
                changed = await writer.record(
                    db,
                    user_id=user_id,
                    vehicle_id=vin,
                    entity=entity,
                    value=value,
                    observed_at=observed_at,
                )
                if changed:
                    transitions += 1
            if transitions:
                await db.commit()
            else:
                await db.rollback()
        except Exception:
            logger.exception("connectivity record write failed (vin=%s)", vin)
            await db.rollback()
            return

        if not transitions:
            return
        try:
            async with async_session() as eval_db:
                # Phase 10 — if the car just came online, drain queued
                # commands first so a "queued at 7am" set_keeper_mode
                # fires within seconds of wake-up.
                await _drain_if_came_online(eval_db, user_id, vin, payload)
                if engine is not None:
                    snap = await build_snapshot_from_telemetry(
                        eval_db, user_id=user_id, vehicle_id=vin,
                    )
                    result = await engine.run_for_vehicle(
                        eval_db,
                        user_id=user_id,
                        vehicle_id=vin,
                        state=snap,
                        settings=AutomationSettings(),
                    )
                    await check_and_resolve(
                        eval_db,
                        user_id=user_id, vehicle_id=vin, snap=snap,
                    )
                    if result.pushed_count or result.cleared_count:
                        logger.info(
                            "connectivity-driven tick user=%s vin=%s pushed=%s",
                            user_id, vin, result.pushed_count,
                        )
                await eval_db.commit()
        except Exception:
            logger.exception("connectivity-driven engine tick failed (vin=%s)", vin)


async def consume(stop_event: asyncio.Event) -> None:
    """Long-running coroutine subscribing to fleet-telemetry's ZMQ
    socket. Pure no-op when ``TELEMETRY_ZMQ_ADDR`` is empty so dev
    environments without the telemetry server can run the backend
    unchanged.
    """
    addr = getattr(settings, "TELEMETRY_ZMQ_ADDR", "") or ""
    if not addr:
        logger.info("telemetry consumer disabled (TELEMETRY_ZMQ_ADDR empty)")
        return

    try:
        import zmq
        import zmq.asyncio
    except ImportError:
        logger.warning(
            "pyzmq not installed — telemetry consumer disabled. "
            "Add `pyzmq` to requirements.txt to enable."
        )
        return

    ctx = zmq.asyncio.Context.instance()
    sock = ctx.socket(zmq.SUB)
    sock.connect(addr)
    v_topic = f"{TELEMETRY_NAMESPACE}_V".encode()
    conn_topic = f"{TELEMETRY_NAMESPACE}_connectivity".encode()
    sock.setsockopt(zmq.SUBSCRIBE, v_topic)
    sock.setsockopt(zmq.SUBSCRIBE, conn_topic)
    logger.info(
        "telemetry zmq consumer connected: %s topics=[%s, %s]",
        addr, v_topic.decode(), conn_topic.decode(),
    )

    writer = TelemetryStateWriter()
    engine = AutomationEngine()
    debounce_until: dict = {}

    try:
        while not stop_event.is_set():
            try:
                parts = await asyncio.wait_for(
                    sock.recv_multipart(), timeout=1.0
                )
            except asyncio.TimeoutError:
                continue
            except Exception:
                logger.exception("zmq recv crashed")
                await asyncio.sleep(1)
                continue
            if len(parts) < 2:
                continue
            topic = parts[0].decode("utf-8", errors="replace")
            try:
                payload = json.loads(parts[1])
            except (json.JSONDecodeError, UnicodeDecodeError):
                logger.warning("telemetry: undecodable payload on topic=%s", topic)
                continue
            if topic.endswith("_V") or topic == "V":
                try:
                    await _process_v_record(
                        writer, payload,
                        engine=engine, debounce_until=debounce_until,
                    )
                except Exception:
                    # Never let a single bad record kill the loop —
                    # log + continue. Without this, an exception here
                    # propagates past the inner try, breaks the while,
                    # and we silently stop receiving.
                    logger.exception(
                        "telemetry V record handler crashed (topic=%s)", topic,
                    )
            elif topic.endswith("_connectivity") or topic == "connectivity":
                try:
                    await _process_connectivity_record(
                        writer, payload, engine=engine,
                    )
                except Exception:
                    logger.exception(
                        "telemetry connectivity handler crashed (topic=%s)", topic,
                    )
    finally:
        sock.close(linger=0)
        logger.info("telemetry consumer stopped")
