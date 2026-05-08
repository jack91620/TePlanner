"""Phase 9 — closed-loop VCP confirmation resolver.

Every successful capability dispatch with observable telemetry writes
a ``CommandPending`` row carrying the entity-value predicate that
should match once the command has actually taken effect on the car.
The Telemetry consumer's per-V engine path calls
``check_and_resolve(...)`` afterwards; on match we stamp
``confirmed_at`` and iOS sees "已关闭" within seconds. The cron tick
also calls it so timeouts fire even when the car never produces a
matching telemetry frame (signed command silently dropped, vehicle
went offline before applying, etc).

Match semantics: ALL entries in ``expected_state_json`` must match
the snapshot. Single-key predicates are the common case
(set_keeper_mode → keeper_mode == N), but multi-key works too.
"""

from __future__ import annotations

import json
import logging
from datetime import datetime, timedelta, timezone
from typing import Any, Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import CommandPending
from app.services.automation.base import VehicleStateSnapshot

logger = logging.getLogger(__name__)


# Snapshot field name lookup for an entity dotted path. Mirrors
# ``interpreters._ENTITY_MAP`` but we keep our own copy so the
# resolver doesn't depend on the interpreter import order. Add new
# observable entities here when you give a capability an
# expected_state predicate against them.
_ENTITY_TO_SNAPSHOT_FIELD = {
    "vehicle.climate.keeper_mode": "climate_keeper_mode",
    "vehicle.sentry_mode_on": "sentry_mode_on",
    "vehicle.cabin_overheat_protection_on": "cabin_overheat_protection_on",
    "vehicle.charging.state": "charging_state",
    "vehicle.battery_level": "battery_level",
    "vehicle.locked": "locked",
    "vehicle.shift_state": "shift_state",
    "vehicle.connectivity": "connectivity",
}


# How long a pending row waits before being declared timed-out.
# Vehicle-side application of a VCP command is usually < 5 s; the
# round-trip via fleet-telemetry is < 10 s P99 in our testing. 60 s
# gives generous slack for cellular hiccups without leaving stale
# pending rows hanging around forever.
_TIMEOUT_SECONDS = 60


def _read_snapshot_field(snap: VehicleStateSnapshot, entity: str) -> Any:
    field = _ENTITY_TO_SNAPSHOT_FIELD.get(entity)
    if field is None:
        return None
    return getattr(snap, field, None)


def _matches(snap: VehicleStateSnapshot, expected: dict) -> bool:
    for entity, expected_value in expected.items():
        actual = _read_snapshot_field(snap, entity)
        if actual is None:
            return False  # haven't observed this entity yet — defer
        if actual != expected_value:
            return False
    return True


async def check_and_resolve(
    db: AsyncSession,
    user_id: int,
    vehicle_id: str,
    snap: Optional[VehicleStateSnapshot],
    now: Optional[datetime] = None,
) -> dict:
    """Walk all unresolved CommandPending rows for one (user, vehicle)
    and try to resolve each. Returns a small summary dict for logging.

    Idempotent — calling repeatedly with the same snapshot is a no-op
    once predicates have matched (the row no longer comes back via the
    "unresolved" filter).
    """
    if now is None:
        now = datetime.now(timezone.utc)

    # SqlAlchemy stores DateTime without tz — strip for comparison.
    now_naive = now.replace(tzinfo=None) if now.tzinfo else now

    stmt = select(CommandPending).where(
        CommandPending.user_id == user_id,
        CommandPending.vehicle_id == vehicle_id,
        CommandPending.confirmed_at.is_(None),
        CommandPending.timed_out_at.is_(None),
    )
    rows = (await db.execute(stmt)).scalars().all()
    if not rows:
        return {"checked": 0}

    confirmed = 0
    timed_out = 0

    for row in rows:
        try:
            expected = json.loads(row.expected_state_json or "{}")
        except (json.JSONDecodeError, TypeError):
            expected = {}

        if snap is not None and expected and _matches(snap, expected):
            row.confirmed_at = now_naive
            confirmed += 1
            logger.info(
                "command confirmed user=%s vin=%s capability=%s elapsed=%ss",
                user_id, vehicle_id, row.capability,
                int((now_naive - row.dispatched_at).total_seconds()),
            )
            continue

        # Timeout check: dispatched_at is naive UTC.
        if (now_naive - row.dispatched_at).total_seconds() > _TIMEOUT_SECONDS:
            row.timed_out_at = now_naive
            timed_out += 1
            logger.info(
                "command timed out user=%s vin=%s capability=%s",
                user_id, vehicle_id, row.capability,
            )

    return {
        "checked": len(rows),
        "confirmed": confirmed,
        "timed_out": timed_out,
    }


async def write_pending(
    db: AsyncSession,
    *,
    user_id: int,
    vehicle_id: str,
    capability_id: str,
    expected: dict,
    now: Optional[datetime] = None,
) -> Optional[CommandPending]:
    """Insert a new pending row. No-op when ``expected`` is empty
    (capability has no observable telemetry — UI confirms on HTTP
    2xx alone)."""
    if not expected:
        return None
    if now is None:
        now = datetime.now(timezone.utc)
    row = CommandPending(
        user_id=user_id,
        vehicle_id=vehicle_id,
        capability=capability_id,
        expected_state_json=json.dumps(expected),
        dispatched_at=now.replace(tzinfo=None) if now.tzinfo else now,
    )
    db.add(row)
    await db.flush()
    return row
