"""Round-trip test for build_snapshot_from_telemetry.

The Phase 6 architecture replaces polling._build_snapshot with this
helper; pin the contract so a refactor of TelemetryStateWriter or
AutomationState's storage shape can't silently change what the
engine sees.
"""

import json
from datetime import datetime, timezone

import pytest

from app.db.models import AutomationState, User, Vehicle
from app.services.telemetry.snapshot import (
    build_snapshot_from_telemetry,
    has_any_telemetry,
)


VIN = "LRWYGCFS0NC123456"


@pytest.fixture
async def user(db_session):
    u = User(email="t@t.com", password_hash="x", is_active=True)
    db_session.add(u)
    await db_session.flush()
    db_session.add(Vehicle(user_id=u.id, vehicle_id="42", vin=VIN, display_name="T"))
    await db_session.commit()
    return u


def _row(user_id: int, key: str, value: object) -> AutomationState:
    return AutomationState(
        user_id=user_id, vehicle_id=VIN, key=key,
        value=json.dumps(value) if not isinstance(value, str) else json.dumps(value),
    )


def _value_row(user_id: int, entity: str, value: object) -> AutomationState:
    return AutomationState(
        user_id=user_id, vehicle_id=VIN,
        key=f"tel:{entity}:value",
        value=json.dumps(value),
    )


def _since_row(user_id: int, entity: str, when: datetime) -> AutomationState:
    return AutomationState(
        user_id=user_id, vehicle_id=VIN,
        key=f"tel:{entity}:since",
        value=when.isoformat(),
    )


async def test_empty_telemetry_returns_all_none(user, db_session):
    snap = await build_snapshot_from_telemetry(db_session, user.id, VIN)
    assert snap.climate_keeper_mode is None
    assert snap.sentry_mode_on is None
    assert snap.battery_level is None
    assert snap.locked is None
    assert snap.charging_state is None
    assert snap.shift_state is None
    assert snap.cabin_overheat_protection_on is None


async def test_full_seven_entity_round_trip(user, db_session):
    db_session.add_all([
        _value_row(user.id, "vehicle.climate.keeper_mode", 3),
        _value_row(user.id, "vehicle.sentry_mode_on", False),
        _value_row(user.id, "vehicle.cabin_overheat_protection_on", True),
        _value_row(user.id, "vehicle.charging.state", "Disconnected"),
        _value_row(user.id, "vehicle.battery_level", 52),
        _value_row(user.id, "vehicle.locked", True),
        _value_row(user.id, "vehicle.shift_state", "P"),
    ])
    await db_session.commit()

    snap = await build_snapshot_from_telemetry(db_session, user.id, VIN)
    assert snap.climate_keeper_mode == 3
    assert snap.sentry_mode_on is False
    assert snap.cabin_overheat_protection_on is True
    assert snap.charging_state == "Disconnected"
    assert snap.battery_level == 52
    assert snap.locked is True
    assert snap.shift_state == "P"
    # Snapshot's @property is_camp_mode_on must work (rules depend on it).
    assert snap.is_camp_mode_on is True


async def test_partial_population_keeps_others_none(user, db_session):
    # Only 2 entities recorded — the others stay None.
    db_session.add_all([
        _value_row(user.id, "vehicle.locked", False),
        _value_row(user.id, "vehicle.battery_level", 18),
    ])
    await db_session.commit()
    snap = await build_snapshot_from_telemetry(db_session, user.id, VIN)
    assert snap.locked is False
    assert snap.battery_level == 18
    assert snap.climate_keeper_mode is None
    assert snap.charging_state is None


async def test_other_users_telemetry_does_not_leak(user, db_session):
    other = User(email="b@b.com", password_hash="x", is_active=True)
    db_session.add(other)
    await db_session.flush()
    db_session.add_all([
        _value_row(other.id, "vehicle.climate.keeper_mode", 3),
        _value_row(other.id, "vehicle.locked", False),
    ])
    await db_session.commit()

    snap = await build_snapshot_from_telemetry(db_session, user.id, VIN)
    assert snap.climate_keeper_mode is None
    assert snap.locked is None


async def test_has_any_telemetry_returns_false_when_empty(user, db_session):
    assert await has_any_telemetry(db_session, user.id, VIN) is False


async def test_has_any_telemetry_returns_true_when_since_row_exists(user, db_session):
    db_session.add(_since_row(
        user.id, "vehicle.locked",
        datetime(2026, 5, 8, 8, 16, 23, tzinfo=timezone.utc),
    ))
    await db_session.commit()
    assert await has_any_telemetry(db_session, user.id, VIN) is True


async def test_has_any_telemetry_ignores_non_tel_keys(user, db_session):
    # A polling-era `campMode:startedAt` row should not confuse the
    # cold-start gate.
    db_session.add(AutomationState(
        user_id=user.id, vehicle_id=VIN,
        key="campMode:startedAt",
        value="2026-05-08T08:00:00+00:00",
    ))
    await db_session.commit()
    assert await has_any_telemetry(db_session, user.id, VIN) is False


async def test_phase7_entities_round_trip(user, db_session):
    """Phase 7 entities (location, temps, speed, charger_power,
    software_version, doors/windows/frunk/trunk aggregates) must be
    reconstructed into the snapshot dataclass."""
    db_session.add_all([
        _value_row(user.id, "vehicle.location.latitude", 39.9),
        _value_row(user.id, "vehicle.location.longitude", 116.4),
        _value_row(user.id, "vehicle.inside_temp_c", 22.5),
        _value_row(user.id, "vehicle.outside_temp_c", -3.0),
        _value_row(user.id, "vehicle.speed_kmh", 0.0),
        _value_row(user.id, "vehicle.charger_power_kw", 11.0),
        _value_row(user.id, "vehicle.software_version", "2024.44.25.5"),
        _value_row(user.id, "vehicle.door_open", True),
        _value_row(user.id, "vehicle.window_open", False),
        _value_row(user.id, "vehicle.frunk_open", False),
        _value_row(user.id, "vehicle.trunk_open", True),
    ])
    await db_session.commit()

    snap = await build_snapshot_from_telemetry(db_session, user.id, VIN)
    assert snap.latitude == 39.9
    assert snap.longitude == 116.4
    assert snap.inside_temp_c == 22.5
    assert snap.outside_temp_c == -3.0
    assert snap.speed_kmh == 0.0
    assert snap.charger_power_kw == 11.0
    assert snap.software_version == "2024.44.25.5"
    assert snap.door_open is True
    assert snap.window_open is False
    assert snap.frunk_open is False
    assert snap.trunk_open is True


async def test_malformed_value_decodes_gracefully(user, db_session):
    # Non-JSON garbage in the row — _decode falls back to raw string,
    # then type coercion drops it (battery_level isn't a string).
    db_session.add(AutomationState(
        user_id=user.id, vehicle_id=VIN,
        key="tel:vehicle.battery_level:value",
        value="not-json",
    ))
    await db_session.commit()
    snap = await build_snapshot_from_telemetry(db_session, user.id, VIN)
    assert snap.battery_level is None  # silently absent, no crash
