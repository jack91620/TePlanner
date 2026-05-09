"""Phase 6 — cron_tick replaces polling. Pin the contract:

  * No /vehicle_data fetch (no TeslaClient instantiation).
  * Engine is invoked once per eligible user with a snapshot built
    from the local tel:* rows.
  * Users without a TeslaToken or DeviceToken are skipped.
  * Cron-trigger rules can fire purely from the periodic wakeup.
"""

import json
from datetime import datetime, timezone

import pytest

from app.db.models import (
    AutomationState,
    DeviceToken,
    TeslaToken,
    User,
    Vehicle,
)
from app.services.cron_tick import _eligible_user_ids, run_one_tick


VIN = "LRWYGCFS0NCABCDEF"


@pytest.fixture
async def patched_async_session(db_session, monkeypatch):
    """Route cron_tick's `async_session()` to the test session so it
    sees fixture data instead of the production DB."""
    from app.services import cron_tick

    class _SessionCM:
        async def __aenter__(self):
            return db_session
        async def __aexit__(self, *a):
            pass

    monkeypatch.setattr(cron_tick, "async_session", lambda: _SessionCM())
    return db_session


@pytest.fixture
async def eligible_user(patched_async_session):
    db_session = patched_async_session
    user = User(email="t@t.com", password_hash="x", is_active=True)
    db_session.add(user)
    await db_session.flush()
    db_session.add_all([
        Vehicle(user_id=user.id, vehicle_id="42", vin=VIN, display_name="T"),
        TeslaToken(
            user_id=user.id, access_token="x", refresh_token="x",
            expires_at=datetime(2099, 1, 1),
        ),
        DeviceToken(
            user_id=user.id, token="dev-token", bundle_id="com.teplanner.ios",
        ),
        # Telemetry seeded one row so build_snapshot has something.
        AutomationState(
            user_id=user.id, vehicle_id=VIN,
            key="tel:vehicle.locked:value", value=json.dumps(True),
        ),
        AutomationState(
            user_id=user.id, vehicle_id=VIN,
            key="tel:vehicle.locked:since",
            value=datetime(2026, 5, 8, 8, 16, 23, tzinfo=timezone.utc).isoformat(),
        ),
    ])
    await db_session.commit()
    return user


async def test_eligible_users_requires_both_tokens(db_session):
    only_tesla = User(email="a@a.com", password_hash="x", is_active=True)
    only_device = User(email="b@b.com", password_hash="x", is_active=True)
    full = User(email="c@c.com", password_hash="x", is_active=True)
    db_session.add_all([only_tesla, only_device, full])
    await db_session.flush()
    db_session.add_all([
        TeslaToken(
            user_id=only_tesla.id, access_token="x", refresh_token="x",
            expires_at=datetime(2099, 1, 1),
        ),
        DeviceToken(user_id=only_device.id, token="t1", bundle_id="b"),
        TeslaToken(
            user_id=full.id, access_token="x", refresh_token="x",
            expires_at=datetime(2099, 1, 1),
        ),
        DeviceToken(user_id=full.id, token="t2", bundle_id="b"),
    ])
    await db_session.commit()

    eligible = await _eligible_user_ids(db_session)
    assert eligible == [full.id]


async def test_run_one_tick_does_not_call_tesla(eligible_user, monkeypatch):
    """The whole point of Phase 6: zero outbound HTTP. We assert by
    monkey-patching TeslaClient to raise — if the cron path touches
    it, the test fails.
    """
    from app.services import cron_tick

    class _Boom:
        def __init__(self, *a, **kw):
            raise AssertionError(
                "cron_tick must not instantiate TeslaClient — "
                "state must come from telemetry rows."
            )

    monkeypatch.setattr(
        "app.integrations.tesla.TeslaClient", _Boom, raising=False,
    )
    # Run the tick. Should pass since we never construct a TeslaClient.
    polled = await run_one_tick()
    assert polled >= 1


async def test_run_one_tick_invokes_engine_once_per_user(eligible_user):
    """Engine is called with the telemetry-derived snapshot."""
    from app.services import cron_tick
    from app.services.automation.engine import TickResult

    seen: list[dict] = []

    class _SpyEngine:
        async def run_for_vehicle(self, db, *, user_id, vehicle_id, state, settings):
            seen.append({
                "user_id": user_id, "vehicle_id": vehicle_id,
                "locked": state.locked,
            })
            return TickResult(alerts=[], pushed_count=0, cleared_count=0)

    polled = await cron_tick.run_one_tick(_SpyEngine())
    assert polled == 1
    assert len(seen) == 1
    assert seen[0]["vehicle_id"] == VIN
    assert seen[0]["locked"] is True


async def test_one_user_failure_does_not_poison_other_users(patched_async_session):
    """Regression for the 2026-05-09 production incident — a single
    user's exception inside _tick_one_user used to leave the shared
    session in 'rollback required' state, cascading 40 ERRORs across
    every subsequent user. With the per-user-session fix in 914b497,
    failures isolate to that one user.
    """
    db_session = patched_async_session
    user_a = User(email="a@a.com", password_hash="x", is_active=True)
    user_b = User(email="b@b.com", password_hash="x", is_active=True)
    db_session.add_all([user_a, user_b])
    await db_session.flush()
    for u in (user_a, user_b):
        db_session.add_all([
            Vehicle(user_id=u.id, vehicle_id=str(u.id), vin=VIN + str(u.id), display_name="T"),
            TeslaToken(
                user_id=u.id, access_token="x", refresh_token="x",
                expires_at=datetime(2099, 1, 1),
            ),
            DeviceToken(user_id=u.id, token=f"dev-{u.id}", bundle_id="com.teplanner.ios"),
            AutomationState(
                user_id=u.id, vehicle_id=VIN + str(u.id),
                key="tel:vehicle.locked:value", value=json.dumps(True),
            ),
            AutomationState(
                user_id=u.id, vehicle_id=VIN + str(u.id),
                key="tel:vehicle.locked:since",
                value=datetime(2026, 5, 8, 8, 16, 23, tzinfo=timezone.utc).isoformat(),
            ),
        ])
    await db_session.commit()

    from app.services import cron_tick
    from app.services.automation.engine import TickResult

    seen_users: list[int] = []

    class _PoisonOnFirstUser:
        async def run_for_vehicle(self, db, *, user_id, vehicle_id, state, settings):
            seen_users.append(user_id)
            if user_id == user_a.id:
                raise RuntimeError("simulated autoflush failure on user_a")
            return TickResult(alerts=[], pushed_count=0, cleared_count=0)

    polled = await cron_tick.run_one_tick(_PoisonOnFirstUser())

    # Both users were attempted (no early-exit on first failure).
    assert set(seen_users) == {user_a.id, user_b.id}
    # Exactly one polled (user_b — user_a raised).
    assert polled == 1


async def test_user_without_vehicle_is_skipped(patched_async_session):
    db_session = patched_async_session
    # Has both tokens but no Vehicle row → cron tick must early-return.
    u = User(email="x@x.com", password_hash="x", is_active=True)
    db_session.add(u)
    await db_session.flush()
    db_session.add_all([
        TeslaToken(
            user_id=u.id, access_token="x", refresh_token="x",
            expires_at=datetime(2099, 1, 1),
        ),
        DeviceToken(user_id=u.id, token="t", bundle_id="b"),
    ])
    await db_session.commit()

    from app.services import cron_tick
    from app.services.automation.engine import TickResult

    class _SpyEngine:
        called = False
        async def run_for_vehicle(self, *a, **kw):
            type(self).called = True
            return TickResult(alerts=[], pushed_count=0, cleared_count=0)

    polled = await cron_tick.run_one_tick(_SpyEngine())
    assert polled == 1  # user iterated, but…
    assert _SpyEngine.called is False  # …engine skipped (no vehicle).
