"""Phase 10 — sleep-aware command dispatch.

Public API:
  * ``connectivity_state(db, user_id, vin)`` — read the cached
    Telemetry connectivity status (CONNECTED / DISCONNECTED / None).
  * ``enqueue(...)``   — write a CommandQueue row.
  * ``drain_for_vehicle(...)`` — try to dispatch every queued command
    for one (user, vehicle); skip TTL-expired rows; commit nothing
    here — caller owns the transaction.

The drain path runs in two places:
  1. Telemetry consumer's connectivity-online edge — fastest path,
     dispatches within ~1 s of the car coming online.
  2. Cron tick safety sweep — covers the case where a connectivity
     event was missed (server restart, ZMQ blip) and reaps TTL
     expirations.

Drain dispatches each capability identically to a fresh user-driven
HTTP call, including writing a CommandPending row for Phase 9
confirmation. Failures during drain mark ``dropped_at + error`` so
the row doesn't loop forever.
"""

from __future__ import annotations

import json
import logging
from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import TokenEncryption
from app.db.models import (
    AutomationState,
    CommandQueue,
    TeslaToken,
    Vehicle,
)
from app.integrations.tesla import TeslaAuth, TeslaClient
from app.services.capabilities import dispatch as capability_dispatch
from app.services.capabilities import get as get_capability
from app.services.capabilities.base import CapabilityCallContext
from app.services.automation.pending_resolver import write_pending
from app.services.telemetry.state_writer import telemetry_value_key

logger = logging.getLogger(__name__)


async def connectivity_state(
    db: AsyncSession, user_id: int, vin: str,
) -> Optional[str]:
    """Read the cached telemetry connectivity for the vehicle.
    Returns ``"CONNECTED"`` / ``"DISCONNECTED"`` / ``None`` (no
    telemetry seen yet — common right after first VCP pairing).
    """
    stmt = select(AutomationState).where(
        AutomationState.user_id == user_id,
        AutomationState.vehicle_id == vin,
        AutomationState.key == telemetry_value_key("vehicle.connectivity"),
    ).limit(1)
    row = (await db.execute(stmt)).scalars().first()
    if row is None or row.value is None:
        return None
    try:
        decoded = json.loads(row.value)
    except (json.JSONDecodeError, TypeError):
        return None
    return decoded if isinstance(decoded, str) else None


async def enqueue(
    db: AsyncSession,
    *,
    user_id: int,
    vin: str,
    capability_id: str,
    params: dict,
    dispatch_policy: str,
    ttl_seconds: int = 1800,
) -> CommandQueue:
    row = CommandQueue(
        user_id=user_id,
        vehicle_id=vin,
        capability=capability_id,
        params_json=json.dumps(params),
        dispatch_policy=dispatch_policy,
        ttl_seconds=ttl_seconds,
    )
    db.add(row)
    await db.flush()
    logger.info(
        "command queued user=%s vin=%s capability=%s id=%s",
        user_id, vin, capability_id, row.id,
    )
    return row


async def _get_user_access_token(
    db: AsyncSession, user_id: int,
) -> Optional[str]:
    """Load + auto-refresh the user's Tesla access token. Returns None
    when the user has no token row or refresh fails.
    Mirror of the helper in the deleted polling.py.
    """
    stmt = (
        select(TeslaToken)
        .where(TeslaToken.user_id == user_id)
        .order_by(TeslaToken.updated_at.desc())
    )
    token = (await db.execute(stmt)).scalars().first()
    if token is None:
        return None

    encryption = TokenEncryption()
    if token.expires_at is None or token.expires_at < datetime.utcnow():
        try:
            refresh_plain = encryption.decrypt(token.refresh_token)
        except Exception as exc:
            # Audit on 2026-05-09: 133/133 tokens encrypted. A decrypt
            # failure now means corruption, not a legacy plain row —
            # bail rather than feed garbage into Tesla's refresh path.
            logger.warning(
                "tesla refresh_token decrypt failed user=%s: %s",
                user_id, exc,
            )
            return None
        try:
            new_tokens = await TeslaAuth().refresh_token(refresh_plain)
            token.access_token = encryption.encrypt(new_tokens["access_token"])
            token.refresh_token = encryption.encrypt(new_tokens["refresh_token"])
            token.expires_at = datetime.utcnow() + timedelta(
                seconds=new_tokens.get("expires_in", 3600)
            )
            await db.flush()
            return new_tokens["access_token"]
        except Exception as exc:
            logger.warning(
                "tesla token refresh failed during drain user=%s: %s",
                user_id, exc,
            )
            return None
    try:
        return encryption.decrypt(token.access_token)
    except Exception as exc:
        logger.warning(
            "tesla access_token decrypt failed user=%s: %s",
            user_id, exc,
        )
        return None


async def _resolve_numeric_vehicle_id(
    db: AsyncSession, user_id: int, vin: str,
) -> Optional[str]:
    stmt = (
        select(Vehicle.vehicle_id)
        .where(Vehicle.user_id == user_id, Vehicle.vin == vin)
        .order_by(Vehicle.id.desc())
        .limit(1)
    )
    return (await db.execute(stmt)).scalar_one_or_none()


async def drain_for_vehicle(
    db: AsyncSession,
    *,
    user_id: int,
    vin: str,
    now: Optional[datetime] = None,
) -> dict:
    """Dispatch every queued command for one (user, vehicle). Returns
    a summary dict with sent / dropped / skipped counts.

    Caller owns the transaction — this function flushes but never
    commits. That keeps drain atomic with whatever event triggered it
    (connectivity online edge or cron tick).
    """
    if now is None:
        now = datetime.utcnow()

    stmt = (
        select(CommandQueue)
        .where(
            CommandQueue.user_id == user_id,
            CommandQueue.vehicle_id == vin,
            CommandQueue.sent_at.is_(None),
            CommandQueue.dropped_at.is_(None),
        )
        .order_by(CommandQueue.queued_at.asc())
    )
    rows = (await db.execute(stmt)).scalars().all()
    if not rows:
        return {"checked": 0, "sent": 0, "dropped": 0}

    sent = 0
    dropped = 0

    # Step 1 — drop TTL-expired rows upfront, regardless of token state.
    # A user who logged out should still see stale "preheat at 7am"
    # rows expire instead of accumulating forever.
    live_rows: list[CommandQueue] = []
    for row in rows:
        elapsed = (now - row.queued_at).total_seconds()
        if elapsed > row.ttl_seconds:
            row.dropped_at = now
            row.error = f"TTL expired after {int(elapsed)}s"
            dropped += 1
        else:
            live_rows.append(row)

    if not live_rows:
        return {"checked": len(rows), "sent": sent, "dropped": dropped}

    access_token = await _get_user_access_token(db, user_id)
    if access_token is None:
        # Can't dispatch without a token; leave live rows pending —
        # next drain attempt may succeed if user re-OAuths.
        return {"checked": len(rows), "sent": sent, "dropped": dropped}

    numeric_id = await _resolve_numeric_vehicle_id(db, user_id, vin)

    async with TeslaClient(access_token=access_token) as client:
        for row in live_rows:
            cap = get_capability(row.capability)
            if cap is None:
                row.dropped_at = now
                row.error = "unknown capability"
                dropped += 1
                continue

            try:
                params = json.loads(row.params_json)
            except (json.JSONDecodeError, TypeError):
                row.dropped_at = now
                row.error = "params decode failed"
                dropped += 1
                continue

            ctx = CapabilityCallContext(
                vehicle_id=str(numeric_id) if numeric_id is not None else "",
                vin=vin,
                tesla_client=client,
                user_id=user_id,
            )
            try:
                result = await capability_dispatch(row.capability, ctx, params)
            except Exception as exc:
                logger.exception(
                    "drain dispatch crashed user=%s capability=%s",
                    user_id, row.capability,
                )
                row.dropped_at = now
                row.error = str(exc)[:255]
                dropped += 1
                continue

            if not result.success:
                row.dropped_at = now
                row.error = (result.error or "dispatch failed")[:255]
                dropped += 1
                continue

            row.sent_at = now
            sent += 1
            # Phase 9 — pending row for confirmation, same as a fresh
            # user-driven HTTP dispatch would write.
            expected = cap.expected_state(params)
            await write_pending(
                db,
                user_id=user_id, vehicle_id=vin,
                capability_id=row.capability,
                expected=expected, now=now,
            )

    if sent or dropped:
        logger.info(
            "command queue drain user=%s vin=%s sent=%s dropped=%s",
            user_id, vin, sent, dropped,
        )
    return {"checked": len(rows), "sent": sent, "dropped": dropped}
