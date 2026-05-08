"""DB-level tests for TelemetryStateWriter.

Verifies the transition-only write semantics: same value back-to-back
is a no-op (since stays pinned to the original transition); different
value updates both `value` and `since`. The interpreter relies on
that contract — if `since` re-stamped on every event, it would equal
the most recent observation time and we'd be back to the polling-era
inaccuracy this whole phase exists to fix.
"""

from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import select

from app.db.models import AutomationState, User, Vehicle
from app.services.telemetry.state_writer import (
    TelemetryStateWriter,
    telemetry_since_key,
    telemetry_value_key,
)


VIN = "LRWYGCFS0NC123456"


@pytest.fixture
async def seeded_user(db_session):
    user = User(email="t@t.com", password_hash="x", is_active=True)
    db_session.add(user)
    await db_session.flush()
    veh = Vehicle(
        user_id=user.id,
        vehicle_id="123",
        vin=VIN,
        display_name="Test",
    )
    db_session.add(veh)
    await db_session.commit()
    return user


async def _state_value(db, user_id: int, key: str):
    stmt = select(AutomationState).where(
        AutomationState.user_id == user_id,
        AutomationState.key == key,
    )
    row = (await db.execute(stmt)).scalar_one_or_none()
    return row.value if row else None


async def test_resolve_user_id_picks_most_recent_vehicle(db_session):
    u1 = User(email="a@a.com", password_hash="x", is_active=True)
    u2 = User(email="b@b.com", password_hash="x", is_active=True)
    db_session.add_all([u1, u2])
    await db_session.flush()
    db_session.add(Vehicle(user_id=u1.id, vehicle_id="1", vin=VIN, display_name="A"))
    await db_session.flush()
    db_session.add(Vehicle(user_id=u2.id, vehicle_id="2", vin=VIN, display_name="B"))
    await db_session.commit()

    writer = TelemetryStateWriter()
    resolved = await writer.resolve_user_id(db_session, VIN)
    # Most recent Vehicle row → most recently active user.
    assert resolved == u2.id


async def test_first_observation_writes_since(seeded_user, db_session):
    writer = TelemetryStateWriter()
    t0 = datetime(2026, 5, 8, 7, 37, 5, tzinfo=timezone.utc)

    changed = await writer.record(
        db_session,
        user_id=seeded_user.id,
        vehicle_id=VIN,
        entity="vehicle.climate.keeper_mode",
        value=3,
        observed_at=t0,
    )
    await db_session.commit()

    assert changed is True
    since = await _state_value(
        db_session, seeded_user.id,
        telemetry_since_key("vehicle.climate.keeper_mode"),
    )
    assert since == t0.isoformat()


async def test_repeat_value_does_not_advance_since(seeded_user, db_session):
    writer = TelemetryStateWriter()
    t0 = datetime(2026, 5, 8, 7, 37, 5, tzinfo=timezone.utc)
    t1 = t0 + timedelta(minutes=15)

    await writer.record(
        db_session, user_id=seeded_user.id, vehicle_id=VIN,
        entity="vehicle.climate.keeper_mode", value=3, observed_at=t0,
    )
    await db_session.commit()

    changed = await writer.record(
        db_session, user_id=seeded_user.id, vehicle_id=VIN,
        entity="vehicle.climate.keeper_mode", value=3, observed_at=t1,
    )
    await db_session.commit()

    assert changed is False
    since = await _state_value(
        db_session, seeded_user.id,
        telemetry_since_key("vehicle.climate.keeper_mode"),
    )
    assert since == t0.isoformat()  # NOT t1


async def test_value_change_resets_since(seeded_user, db_session):
    writer = TelemetryStateWriter()
    t0 = datetime(2026, 5, 8, 7, 0, 0, tzinfo=timezone.utc)
    t1 = t0 + timedelta(hours=2)

    await writer.record(
        db_session, user_id=seeded_user.id, vehicle_id=VIN,
        entity="vehicle.climate.keeper_mode", value=3, observed_at=t0,
    )
    await writer.record(
        db_session, user_id=seeded_user.id, vehicle_id=VIN,
        entity="vehicle.climate.keeper_mode", value=0, observed_at=t1,
    )
    await db_session.commit()

    since = await _state_value(
        db_session, seeded_user.id,
        telemetry_since_key("vehicle.climate.keeper_mode"),
    )
    assert since == t1.isoformat()


async def test_cold_start_recovers_value_from_db(seeded_user, db_session):
    """Backend restart simulation: a fresh writer pulls last-seen value
    from the DB cache so it doesn't reset since on the next event.
    """
    writer1 = TelemetryStateWriter()
    t0 = datetime(2026, 5, 8, 7, 0, 0, tzinfo=timezone.utc)
    t1 = t0 + timedelta(hours=1)

    await writer1.record(
        db_session, user_id=seeded_user.id, vehicle_id=VIN,
        entity="vehicle.climate.keeper_mode", value=3, observed_at=t0,
    )
    await db_session.commit()

    # Simulate backend restart with a fresh writer instance.
    writer2 = TelemetryStateWriter()
    changed = await writer2.record(
        db_session, user_id=seeded_user.id, vehicle_id=VIN,
        entity="vehicle.climate.keeper_mode", value=3, observed_at=t1,
    )
    await db_session.commit()

    assert changed is False  # cold cache loaded prev=3 from DB
    since = await _state_value(
        db_session, seeded_user.id,
        telemetry_since_key("vehicle.climate.keeper_mode"),
    )
    assert since == t0.isoformat()


async def test_multiple_entities_independent(seeded_user, db_session):
    writer = TelemetryStateWriter()
    t0 = datetime(2026, 5, 8, 7, 0, 0, tzinfo=timezone.utc)

    await writer.record(
        db_session, user_id=seeded_user.id, vehicle_id=VIN,
        entity="vehicle.climate.keeper_mode", value=3, observed_at=t0,
    )
    await writer.record(
        db_session, user_id=seeded_user.id, vehicle_id=VIN,
        entity="vehicle.sentry_mode_on", value=True, observed_at=t0,
    )
    await db_session.commit()

    keeper_value = await _state_value(
        db_session, seeded_user.id,
        telemetry_value_key("vehicle.climate.keeper_mode"),
    )
    sentry_value = await _state_value(
        db_session, seeded_user.id,
        telemetry_value_key("vehicle.sentry_mode_on"),
    )
    assert keeper_value == "3"
    assert sentry_value == "true"
