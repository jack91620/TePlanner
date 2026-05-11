"""Cover the auto-closer that recovers from iOS missing the
chargingState→Disconnected transition (e.g. user killed the app).
"""

from datetime import datetime, timedelta

import pytest
from sqlalchemy import select

from app.db.models import ChargingSession, User
from app.services.automation.base import VehicleStateSnapshot
from app.services.charge_analysis.closer import (
    GRACE_MINUTES,
    close_stale_sessions,
)


VIN = "LRWYGCFS0NC517553"


async def _user(db_session, email):
    u = User(email=email, password_hash="x", is_active=True)
    db_session.add(u)
    await db_session.commit()
    return u


def _open_session(user_id: int, started_at: datetime) -> ChargingSession:
    return ChargingSession(
        user_id=user_id,
        vehicle_id=VIN,
        client_session_id=f"c-{started_at.timestamp()}",
        started_at=started_at,
        ended_at=None,
        start_soc=40,
        start_range_km=180.0,
        source="ios",
        created_at=datetime.utcnow(),
    )


async def test_closes_when_telemetry_says_disconnected(db_session):
    user = await _user(db_session, "close-1@t.com")
    started = datetime.utcnow() - timedelta(minutes=GRACE_MINUTES + 1)
    session = _open_session(user.id, started)
    db_session.add(session)
    await db_session.commit()

    snap = VehicleStateSnapshot(
        charging_state="Disconnected",
        battery_level=72,
        battery_range=320.0,
    )
    closed = await close_stale_sessions(
        db_session, user_id=user.id, vehicle_id=VIN, snap=snap,
    )
    await db_session.commit()
    assert closed == 1

    refreshed = (await db_session.execute(
        select(ChargingSession).where(ChargingSession.id == session.id)
    )).scalar_one()
    assert refreshed.ended_at is not None
    assert refreshed.end_soc == 72
    assert refreshed.end_range_km == 320.0
    assert refreshed.ended_as_complete is False  # disconnected ≠ Complete


async def test_marks_complete_when_telemetry_says_complete(db_session):
    user = await _user(db_session, "close-2@t.com")
    started = datetime.utcnow() - timedelta(hours=2)
    session = _open_session(user.id, started)
    db_session.add(session)
    await db_session.commit()

    snap = VehicleStateSnapshot(
        charging_state="Complete",
        battery_level=90,
        battery_range=400.0,
    )
    closed = await close_stale_sessions(
        db_session, user_id=user.id, vehicle_id=VIN, snap=snap,
    )
    await db_session.commit()
    assert closed == 1

    refreshed = (await db_session.execute(
        select(ChargingSession).where(ChargingSession.id == session.id)
    )).scalar_one()
    assert refreshed.ended_as_complete is True


async def test_noop_while_still_charging(db_session):
    user = await _user(db_session, "close-3@t.com")
    session = _open_session(user.id, datetime.utcnow() - timedelta(hours=2))
    db_session.add(session)
    await db_session.commit()

    snap = VehicleStateSnapshot(
        charging_state="Charging", battery_level=55, battery_range=240.0,
    )
    closed = await close_stale_sessions(
        db_session, user_id=user.id, vehicle_id=VIN, snap=snap,
    )
    assert closed == 0


async def test_grace_window_holds_off_immediate_close(db_session):
    user = await _user(db_session, "close-4@t.com")
    # Session started < grace ago — still racy, leave alone
    session = _open_session(user.id, datetime.utcnow() - timedelta(minutes=1))
    db_session.add(session)
    await db_session.commit()

    snap = VehicleStateSnapshot(
        charging_state="Disconnected", battery_level=70, battery_range=300.0,
    )
    closed = await close_stale_sessions(
        db_session, user_id=user.id, vehicle_id=VIN, snap=snap,
    )
    assert closed == 0


async def test_no_telemetry_is_noop(db_session):
    user = await _user(db_session, "close-5@t.com")
    session = _open_session(user.id, datetime.utcnow() - timedelta(hours=3))
    db_session.add(session)
    await db_session.commit()

    closed = await close_stale_sessions(
        db_session, user_id=user.id, vehicle_id=VIN, snap=None,
    )
    assert closed == 0


async def test_does_not_overwrite_existing_end_values(db_session):
    """If a row was partially populated by some earlier event we don't
    smash existing ended_at / end_soc — that data wins over telemetry."""
    user = await _user(db_session, "close-6@t.com")
    session = _open_session(user.id, datetime.utcnow() - timedelta(hours=1))
    session.end_soc = 80   # already filled in but ended_at NULL
    db_session.add(session)
    await db_session.commit()

    snap = VehicleStateSnapshot(
        charging_state="Disconnected", battery_level=65, battery_range=260.0,
    )
    await close_stale_sessions(
        db_session, user_id=user.id, vehicle_id=VIN, snap=snap,
    )
    await db_session.commit()
    refreshed = (await db_session.execute(
        select(ChargingSession).where(ChargingSession.id == session.id)
    )).scalar_one()
    assert refreshed.end_soc == 80   # unchanged
