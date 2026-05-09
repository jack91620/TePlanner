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


async def test_one_user_failure_does_not_poison_other_users(monkeypatch):
    """Regression for the 2026-05-09 production incident — a single
    user's exception inside _tick_one_user used to leave the shared
    session in 'rollback required' state, cascading 40 ERRORs across
    every subsequent user. With the per-user-session fix in 914b497,
    failures isolate to that one user.

    We bypass the DB entirely here: monkeypatch _eligible_user_ids
    to return two ids, _tick_one_user to raise on user 1, and
    async_session to a no-op context manager. What we're testing is
    the loop semantics, not the SQL — that user 2 is still attempted
    after user 1 raises.
    """
    from app.services import cron_tick

    class _NoOpSessionCM:
        async def __aenter__(self):
            return _NoOpSession()
        async def __aexit__(self, *a):
            pass

    class _NoOpSession:
        async def commit(self): pass
        async def rollback(self): pass
        async def execute(self, *a, **kw): return _NoOpResult()
        async def flush(self): pass

    class _NoOpResult:
        def scalars(self): return self
        def all(self): return []

    seen_uids: list[int] = []

    async def _fake_eligible(_db):
        return [1, 2]

    async def _fake_tick(_db, uid, _engine):
        seen_uids.append(uid)
        if uid == 1:
            raise RuntimeError("simulated autoflush failure on user 1")

    monkeypatch.setattr(cron_tick, "async_session", lambda: _NoOpSessionCM())
    monkeypatch.setattr(cron_tick, "_eligible_user_ids", _fake_eligible)
    monkeypatch.setattr(cron_tick, "_tick_one_user", _fake_tick)

    polled = await cron_tick.run_one_tick(engine=object())

    # Both users were attempted (no early-exit on first failure).
    assert seen_uids == [1, 2]
    # Exactly one polled (user 2 — user 1 raised).
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
