"""Phase 9 — closed-loop VCP confirmation: pending_resolver tests.

Pin the contract:
  * Match → row.confirmed_at stamped, no further state change.
  * Mismatch → row stays pending until match or timeout.
  * Elapsed > 60 s → row.timed_out_at stamped.
  * write_pending no-ops on empty expected (capability without
    observable telemetry).
  * Multi-tenant isolation: resolver only touches rows for
    (user_id, vehicle_id) it was called with.
"""

import json
from datetime import datetime, timedelta, timezone

import pytest

from app.db.models import CommandPending, User, Vehicle
from app.services.automation.base import VehicleStateSnapshot
from app.services.automation.pending_resolver import (
    check_and_resolve,
    write_pending,
    _TIMEOUT_SECONDS,
)


VIN = "LRWYGCFS0NC517553"


@pytest.fixture
async def user(db_session):
    u = User(email="t@t.com", password_hash="x", is_active=True)
    db_session.add(u)
    await db_session.flush()
    db_session.add(Vehicle(user_id=u.id, vehicle_id="42", vin=VIN, display_name="T"))
    await db_session.commit()
    return u


def _snap(**kwargs) -> VehicleStateSnapshot:
    return VehicleStateSnapshot(**kwargs)


# ---------- write_pending ----------

async def test_write_pending_skips_empty_expected(user, db_session):
    """Capability with no observable telemetry → no row written."""
    row = await write_pending(
        db_session,
        user_id=user.id, vehicle_id=VIN,
        capability_id="tesla.climate.preheat", expected={},
    )
    assert row is None


async def test_write_pending_persists_with_expected(user, db_session):
    row = await write_pending(
        db_session,
        user_id=user.id, vehicle_id=VIN,
        capability_id="tesla.climate.set_keeper_mode",
        expected={"vehicle.climate.keeper_mode": 0},
    )
    assert row is not None
    assert row.capability == "tesla.climate.set_keeper_mode"
    assert json.loads(row.expected_state_json) == {"vehicle.climate.keeper_mode": 0}
    assert row.confirmed_at is None
    assert row.timed_out_at is None


# ---------- check_and_resolve ----------

async def test_match_resolves_pending_to_confirmed(user, db_session):
    await write_pending(
        db_session,
        user_id=user.id, vehicle_id=VIN,
        capability_id="tesla.climate.set_keeper_mode",
        expected={"vehicle.climate.keeper_mode": 0},
    )
    snap = _snap(climate_keeper_mode=0)
    summary = await check_and_resolve(
        db_session, user_id=user.id, vehicle_id=VIN, snap=snap,
    )
    assert summary == {"checked": 1, "confirmed": 1, "timed_out": 0}
    # Row updated.
    rows = (await db_session.execute(
        __import__("sqlalchemy").select(CommandPending)
        .where(CommandPending.user_id == user.id)
    )).scalars().all()
    assert len(rows) == 1
    assert rows[0].confirmed_at is not None


async def test_mismatch_stays_pending(user, db_session):
    await write_pending(
        db_session,
        user_id=user.id, vehicle_id=VIN,
        capability_id="tesla.climate.set_keeper_mode",
        expected={"vehicle.climate.keeper_mode": 0},
    )
    snap = _snap(climate_keeper_mode=3)  # camp still on, not yet applied
    summary = await check_and_resolve(
        db_session, user_id=user.id, vehicle_id=VIN, snap=snap,
    )
    assert summary["confirmed"] == 0
    assert summary["timed_out"] == 0


async def test_unobserved_entity_stays_pending(user, db_session):
    """If telemetry hasn't yet reported the entity (snapshot field is
    None), we must NOT mark confirmed — defer to a later frame."""
    await write_pending(
        db_session,
        user_id=user.id, vehicle_id=VIN,
        capability_id="tesla.climate.set_keeper_mode",
        expected={"vehicle.climate.keeper_mode": 0},
    )
    snap = _snap()  # no climate_keeper_mode set
    summary = await check_and_resolve(
        db_session, user_id=user.id, vehicle_id=VIN, snap=snap,
    )
    assert summary["confirmed"] == 0


async def test_timeout_after_60s_marks_timed_out(user, db_session):
    row = await write_pending(
        db_session,
        user_id=user.id, vehicle_id=VIN,
        capability_id="tesla.security.set_sentry",
        expected={"vehicle.sentry_mode_on": False},
    )
    # Backdate the dispatch by 61 s.
    row.dispatched_at = datetime.utcnow() - timedelta(seconds=_TIMEOUT_SECONDS + 1)
    await db_session.commit()

    snap = _snap(sentry_mode_on=True)  # still on, command never landed
    summary = await check_and_resolve(
        db_session, user_id=user.id, vehicle_id=VIN, snap=snap,
    )
    assert summary["timed_out"] == 1
    refreshed = (await db_session.execute(
        __import__("sqlalchemy").select(CommandPending).where(CommandPending.id == row.id)
    )).scalar_one()
    assert refreshed.timed_out_at is not None


async def test_resolved_rows_not_revisited(user, db_session):
    """Already-confirmed rows must be filtered out — calling resolver
    again is a no-op."""
    row = await write_pending(
        db_session,
        user_id=user.id, vehicle_id=VIN,
        capability_id="tesla.climate.set_keeper_mode",
        expected={"vehicle.climate.keeper_mode": 0},
    )
    row.confirmed_at = datetime.utcnow()
    await db_session.commit()

    snap = _snap(climate_keeper_mode=0)
    summary = await check_and_resolve(
        db_session, user_id=user.id, vehicle_id=VIN, snap=snap,
    )
    assert summary == {"checked": 0}


async def test_multi_tenant_isolation(user, db_session):
    other = User(email="b@b.com", password_hash="x", is_active=True)
    db_session.add(other)
    await db_session.flush()
    db_session.add(Vehicle(
        user_id=other.id, vehicle_id="99",
        vin="LRWYAAAAA00000099", display_name="B",
    ))
    # Another user has an unresolved keeper_mode pending.
    await write_pending(
        db_session,
        user_id=other.id, vehicle_id="LRWYAAAAA00000099",
        capability_id="tesla.climate.set_keeper_mode",
        expected={"vehicle.climate.keeper_mode": 0},
    )
    await db_session.commit()

    # Resolver for OUR user sees nothing — leak would be a privacy bug.
    summary = await check_and_resolve(
        db_session, user_id=user.id, vehicle_id=VIN,
        snap=_snap(climate_keeper_mode=0),
    )
    assert summary == {"checked": 0}


async def test_multi_key_predicate_requires_all_match(user, db_session):
    """A capability with a 2-key expected_state only confirms when
    BOTH match. Today no capability ships this, but the logic must
    support it for future composite commands."""
    await write_pending(
        db_session,
        user_id=user.id, vehicle_id=VIN,
        capability_id="tesla.future.composite",
        expected={
            "vehicle.climate.keeper_mode": 0,
            "vehicle.sentry_mode_on": True,
        },
    )
    # Half match — must NOT confirm.
    summary = await check_and_resolve(
        db_session, user_id=user.id, vehicle_id=VIN,
        snap=_snap(climate_keeper_mode=0, sentry_mode_on=False),
    )
    assert summary["confirmed"] == 0

    # Both match — confirms.
    summary = await check_and_resolve(
        db_session, user_id=user.id, vehicle_id=VIN,
        snap=_snap(climate_keeper_mode=0, sentry_mode_on=True),
    )
    assert summary["confirmed"] == 1
