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
from datetime import datetime, timedelta
from typing import Any, Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import AutomationState
from app.services.automation.base import VehicleStateSnapshot
from app.services.telemetry.state_writer import telemetry_value_key

logger = logging.getLogger(__name__)

# 2026-05-10 — incident: a stale `tel:climate.keeper_mode:value=3`
# row from 06:11 fed the rules engine for 3+ hours after the user
# turned camp mode off. Tesla DID send the 3→0 transition, but the
# state_writer crashed on duplicate :since rows and silently lost
# the write. Defense in depth: any row not refreshed within
# MAX_TELEMETRY_AGE_MINUTES is treated as "no data" rather than
# authoritative truth. The interpreter already handles None as
# "absent" → is_on=False → no ghost alerts.
#
# 30 min covers normal Tesla Fleet Telemetry rhythm with margin
# (Tesla emits within seconds while car awake; idles when car
# sleeps). Trade-off: alerts that should fire silently while car
# sleeps won't — acceptable, since we have no proof the state is
# still true, and the next telemetry post-wake re-establishes it.
MAX_TELEMETRY_AGE_MINUTES = 30


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
    if row is None:
        return None
    if row.updated_at is None:
        return _decode(row.value)
    age = datetime.utcnow() - row.updated_at
    if age > timedelta(minutes=MAX_TELEMETRY_AGE_MINUTES):
        logger.debug(
            "telemetry value stale (age=%.1fmin > %dmin) — treating as None: "
            "user=%s vehicle=%s entity=%s",
            age.total_seconds() / 60, MAX_TELEMETRY_AGE_MINUTES,
            user_id, vehicle_id, entity,
        )
        return None
    return _decode(row.value)


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

    # Phase 7 entities.
    door_open = await _read_value(db, user_id, vehicle_id, "vehicle.door_open")
    window_open = await _read_value(db, user_id, vehicle_id, "vehicle.window_open")
    frunk_open = await _read_value(db, user_id, vehicle_id, "vehicle.frunk_open")
    trunk_open = await _read_value(db, user_id, vehicle_id, "vehicle.trunk_open")
    latitude = await _read_value(db, user_id, vehicle_id, "vehicle.location.latitude")
    longitude = await _read_value(db, user_id, vehicle_id, "vehicle.location.longitude")
    inside_temp = await _read_value(db, user_id, vehicle_id, "vehicle.inside_temp_c")
    outside_temp = await _read_value(db, user_id, vehicle_id, "vehicle.outside_temp_c")
    speed = await _read_value(db, user_id, vehicle_id, "vehicle.speed_kmh")
    charger_power = await _read_value(db, user_id, vehicle_id, "vehicle.charger_power_kw")
    software_version = await _read_value(db, user_id, vehicle_id, "vehicle.software_version")
    connectivity = await _read_value(db, user_id, vehicle_id, "vehicle.connectivity")

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
        door_open=door_open if isinstance(door_open, bool) else None,
        window_open=window_open if isinstance(window_open, bool) else None,
        frunk_open=frunk_open if isinstance(frunk_open, bool) else None,
        trunk_open=trunk_open if isinstance(trunk_open, bool) else None,
        latitude=float(latitude) if isinstance(latitude, (int, float)) else None,
        longitude=float(longitude) if isinstance(longitude, (int, float)) else None,
        inside_temp_c=float(inside_temp) if isinstance(inside_temp, (int, float)) else None,
        outside_temp_c=float(outside_temp) if isinstance(outside_temp, (int, float)) else None,
        speed_kmh=float(speed) if isinstance(speed, (int, float)) else None,
        charger_power_kw=(
            float(charger_power) if isinstance(charger_power, (int, float)) else None
        ),
        software_version=software_version if isinstance(software_version, str) else None,
        connectivity=connectivity if isinstance(connectivity, str) else None,
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
