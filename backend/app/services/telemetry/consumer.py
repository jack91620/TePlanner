"""ZMQ consumer that drains fleet-telemetry's record stream into our
AutomationState table.

Lifecycle is bound to FastAPI's lifespan — the consumer task is
cancellable; cancelling closes the SUB socket cleanly.

fleet-telemetry's ZMQ dispatcher publishes each record as a 2-frame
multipart message:
    frame[0] = topic (txtype: V / alerts / errors / connectivity)
    frame[1] = JSON payload (same shape as logger output)

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
from app.services.telemetry.mapping import map_v_payload
from app.services.telemetry.state_writer import TelemetryStateWriter

logger = logging.getLogger(__name__)


def _parse_v_timestamp(payload: dict) -> datetime:
    """Pick the most authoritative timestamp from a V record. Tesla
    fills ``CreatedAt`` (vehicle clock) most reliably; ``time`` is the
    server's receive time which can be skewed if the vehicle was
    offline for a while. Fall through gracefully — never throw.
    """
    data = payload.get("data") or {}
    raw = data.get("CreatedAt") or payload.get("time")
    if isinstance(raw, str):
        try:
            return datetime.fromisoformat(raw.replace("Z", "+00:00"))
        except ValueError:
            pass
    return datetime.now(timezone.utc)


def _vin_for_payload(payload: dict) -> Optional[str]:
    metadata = payload.get("metadata") or {}
    vin = metadata.get("vin") or payload.get("vin")
    if isinstance(vin, str) and vin:
        return vin
    data = payload.get("data") or {}
    if isinstance(data.get("Vin"), str):
        return data["Vin"]
    return None


async def _process_v_record(
    writer: TelemetryStateWriter,
    payload: dict,
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
    sock.setsockopt(zmq.SUBSCRIBE, b"V")
    logger.info("telemetry zmq consumer connected: %s", addr)

    writer = TelemetryStateWriter()

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
            if topic == "V":
                await _process_v_record(writer, payload)
    finally:
        sock.close(linger=0)
        logger.info("telemetry consumer stopped")
