"""Cover the auto-opener that creates a ChargingSession server-side
when telemetry shows we're charging and iOS hasn't logged a row.

Sister of test_charging_session_closer.py. Bug context: census of
live route_plans + charging_session on 2026-05-12 found only 2
rows in months — most charges happen overnight when iOS is
suspended and its in-app tracker never fires.
"""

from datetime import datetime, timedelta

import pytest
from sqlalchemy import select

from app.db.models import ChargingSession, User
from app.services.automation.base import VehicleStateSnapshot
from app.services.charge_analysis.opener import open_session_if_charging


VIN = "LRWYGCFS0NC517553"


async def _user(db_session, email: str) -> User:
    u = User(email=email, password_hash="x", is_active=True)
    db_session.add(u)
    await db_session.commit()
    return u


async def test_opens_session_when_charging_and_no_open_row(db_session):
    user = await _user(db_session, "open-1@t.com")
    snap = VehicleStateSnapshot(charging_state="Charging", battery_level=37)

    new_id = await open_session_if_charging(
        db_session, user_id=user.id, vehicle_id=VIN, snap=snap,
    )
    await db_session.commit()

    assert new_id is not None
    row = (await db_session.execute(
        select(ChargingSession).where(ChargingSession.id == new_id)
    )).scalar_one()
    assert row.user_id == user.id
    assert row.vehicle_id == VIN
    assert row.ended_at is None
    assert row.start_soc == 37
    assert row.source == "server"
    # client_session_id must be non-null (NOT NULL column) and
    # uniquely server-stamped so the API upsert path can't collide.
    assert row.client_session_id is not None
    assert row.client_session_id.startswith("server:")


async def test_noop_when_already_open(db_session):
    """A second cron tick during the same charge must not insert
    a second row — that would split one charge into two
    half-sessions in the user's history."""
    user = await _user(db_session, "open-2@t.com")
    pre = ChargingSession(
        user_id=user.id, vehicle_id=VIN,
        client_session_id="ios:existing",
        started_at=datetime.utcnow() - timedelta(minutes=10),
        ended_at=None,
        start_soc=30,
        source="ios",
        created_at=datetime.utcnow(),
    )
    db_session.add(pre)
    await db_session.commit()

    snap = VehicleStateSnapshot(charging_state="Charging", battery_level=55)
    result = await open_session_if_charging(
        db_session, user_id=user.id, vehicle_id=VIN, snap=snap,
    )
    assert result is None

    rows = (await db_session.execute(
        select(ChargingSession).where(ChargingSession.user_id == user.id)
    )).scalars().all()
    assert len(rows) == 1


async def test_noop_when_not_charging(db_session):
    user = await _user(db_session, "open-3@t.com")
    snap = VehicleStateSnapshot(charging_state="Disconnected", battery_level=88)
    result = await open_session_if_charging(
        db_session, user_id=user.id, vehicle_id=VIN, snap=snap,
    )
    assert result is None

    rows = (await db_session.execute(
        select(ChargingSession).where(ChargingSession.user_id == user.id)
    )).scalars().all()
    assert rows == []


async def test_noop_when_snap_is_none(db_session):
    """No telemetry yet — never invent a session out of nothing."""
    user = await _user(db_session, "open-4@t.com")
    result = await open_session_if_charging(
        db_session, user_id=user.id, vehicle_id=VIN, snap=None,
    )
    assert result is None


async def test_opens_for_subsequent_charge_after_previous_closed(db_session):
    """User charged → unplugged → plugged in again. The first row
    is closed (ended_at set); the second tick on the new charge
    must open a fresh row, not skip because of the historical one."""
    user = await _user(db_session, "open-5@t.com")
    past = ChargingSession(
        user_id=user.id, vehicle_id=VIN,
        client_session_id="ios:past",
        started_at=datetime.utcnow() - timedelta(hours=8),
        ended_at=datetime.utcnow() - timedelta(hours=6),
        start_soc=20,
        end_soc=80,
        source="ios",
        created_at=datetime.utcnow() - timedelta(hours=8),
    )
    db_session.add(past)
    await db_session.commit()

    snap = VehicleStateSnapshot(charging_state="Charging", battery_level=45)
    new_id = await open_session_if_charging(
        db_session, user_id=user.id, vehicle_id=VIN, snap=snap,
    )
    await db_session.commit()
    assert new_id is not None
    assert new_id != past.id

    rows = (await db_session.execute(
        select(ChargingSession).where(ChargingSession.user_id == user.id)
        .order_by(ChargingSession.started_at)
    )).scalars().all()
    assert len(rows) == 2
    assert rows[0].ended_at is not None  # past row stayed closed
    assert rows[1].ended_at is None       # new row open
