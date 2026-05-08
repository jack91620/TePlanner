"""Reconstruct a VehicleStateSnapshot from telemetry-recorded values.

Phase 6: with polling fully retired, the rules engine no longer
receives a snapshot built from a fresh /vehicle_data fetch. Instead,
we look up the latest ``tel:<entity>:value`` rows for one
(user, vehicle) — written by the Telemetry consumer on each
transition — and assemble the same dataclass shape the engine /
interpreter / preset rules already understand.

Field mapping mirrors ``polling._build_snapshot`` so existing rule
behaviour is preserved. Entities Telemetry doesn't yet emit (frunk,
trunk, individual doors before the Phase 7 expansion) come back as
None; rules treat None gracefully.
"""

from __future__ import annotations

import json
import logging
from typing import Any, Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import AutomationState
from app.services.automation.base import VehicleStateSnapshot
from app.services.telemetry.state_writer import telemetry_value_key

logger = logging.getLogger(__name__)


def _decode(raw: Optional[str]) -> Any:
    if raw is None:
        return None
    try:
        return json.loads(raw)
    except (json.JSONDecodeError, TypeError):
        return raw


async def _read_value(
    db: AsyncSession,
    user_id: int,
    vehicle_id: str,
    entity: str,
) -> Any:
    stmt = (
        select(AutomationState)
        .where(
            AutomationState.user_id == user_id,
            AutomationState.vehicle_id == vehicle_id,
            AutomationState.key == telemetry_value_key(entity),
        )
        .order_by(AutomationState.id.desc())
        .limit(1)
    )
    row = (await db.execute(stmt)).scalars().first()
    return _decode(row.value) if row else None


async def build_snapshot_from_telemetry(
    db: AsyncSession,
    user_id: int,
    vehicle_id: str,
) -> VehicleStateSnapshot:
    """Assemble a VehicleStateSnapshot from ``tel:<entity>:value`` rows.

    Returns a dataclass with all fields populated where Telemetry has
    seen at least one value. Other fields are None — rules already
    treat None as "absent / not yet observed" and skip evaluation.
    """
    # Read the seven entities the v1 mapping populates plus the
    # parked_* derived state the locked/closures rules read. Each
    # `await` is one indexed lookup; trivially cheap on SQLite.
    keeper_mode = await _read_value(db, user_id, vehicle_id, "vehicle.climate.keeper_mode")
    sentry_on = await _read_value(db, user_id, vehicle_id, "vehicle.sentry_mode_on")
    cabin_overheat_on = await _read_value(
        db, user_id, vehicle_id, "vehicle.cabin_overheat_protection_on"
    )
    charging_state = await _read_value(db, user_id, vehicle_id, "vehicle.charging.state")
    battery_level = await _read_value(db, user_id, vehicle_id, "vehicle.battery_level")
    locked = await _read_value(db, user_id, vehicle_id, "vehicle.locked")
    shift_state = await _read_value(db, user_id, vehicle_id, "vehicle.shift_state")

    return VehicleStateSnapshot(
        battery_level=int(battery_level) if isinstance(battery_level, (int, float)) else None,
        charging_state=charging_state if isinstance(charging_state, str) else None,
        sentry_mode_on=sentry_on if isinstance(sentry_on, bool) else None,
        cabin_overheat_protection_on=(
            cabin_overheat_on if isinstance(cabin_overheat_on, bool) else None
        ),
        climate_keeper_mode=int(keeper_mode) if isinstance(keeper_mode, (int, float)) else None,
        locked=locked if isinstance(locked, bool) else None,
        shift_state=shift_state if isinstance(shift_state, str) else None,
        # Doors / windows / frunk / trunk wait on Phase 7 (cross-event
        # aggregation in TelemetryStateWriter). Until then rules that
        # depend on them simply don't fire from telemetry-driven evals.
        door_open=None,
        window_open=None,
        frunk_open=None,
        trunk_open=None,
    )


async def has_any_telemetry(
    db: AsyncSession,
    user_id: int,
    vehicle_id: str,
) -> bool:
    """True if at least one `tel:*:since` row exists for the vehicle.
    Cold-start sentinel: iOS shows "等待车辆上线" until this returns true.
    """
    stmt = (
        select(AutomationState)
        .where(
            AutomationState.user_id == user_id,
            AutomationState.vehicle_id == vehicle_id,
            AutomationState.key.like("tel:%:since"),
        )
        .limit(1)
    )
    return (await db.execute(stmt)).scalars().first() is not None
