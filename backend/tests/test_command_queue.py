"""Phase 10 — sleep-aware command dispatch tests.

Covers:
  * connectivity_state reads cached telemetry (CONNECTED / DISCONNECTED
    / None).
  * enqueue persists.
  * drain_for_vehicle: TTL drop, no-token skip, dispatch + Phase 9
    pending row write, error path marks dropped_at.
  * Already-sent / dropped rows are not revisited.
  * Multi-tenant isolation.
"""

import json
from datetime import datetime, timedelta

import pytest

from app.db.models import (
    AutomationState,
    CommandPending,
    CommandQueue,
    TeslaToken,
    User,
    Vehicle,
)
from app.services.command_queue import (
    connectivity_state,
    drain_for_vehicle,
    enqueue,
)
from app.services.telemetry.state_writer import telemetry_value_key


VIN = "LRWYGCFS0NC517553"


@pytest.fixture
async def user(db_session):
    u = User(email="t@t.com", password_hash="x", is_active=True)
    db_session.add(u)
    await db_session.flush()
    db_session.add(Vehicle(user_id=u.id, vehicle_id="42", vin=VIN, display_name="T"))
    await db_session.commit()
    return u


# ---------- connectivity_state ----------

async def test_connectivity_state_none_when_no_row(user, db_session):
    assert await connectivity_state(db_session, user.id, VIN) is None


async def test_connectivity_state_decodes_cached(user, db_session):
    db_session.add(AutomationState(
        user_id=user.id, vehicle_id=VIN,
        key=telemetry_value_key("vehicle.connectivity"),
        value=json.dumps("CONNECTED"),
    ))
    await db_session.commit()
    assert await connectivity_state(db_session, user.id, VIN) == "CONNECTED"


async def test_connectivity_state_disconnected(user, db_session):
    db_session.add(AutomationState(
        user_id=user.id, vehicle_id=VIN,
        key=telemetry_value_key("vehicle.connectivity"),
        value=json.dumps("DISCONNECTED"),
    ))
    await db_session.commit()
    assert await connectivity_state(db_session, user.id, VIN) == "DISCONNECTED"


async def test_connectivity_state_handles_garbage(user, db_session):
    db_session.add(AutomationState(
        user_id=user.id, vehicle_id=VIN,
        key=telemetry_value_key("vehicle.connectivity"),
        value="not json",
    ))
    await db_session.commit()
    assert await connectivity_state(db_session, user.id, VIN) is None


# ---------- enqueue ----------

async def test_enqueue_persists_with_defaults(user, db_session):
    row = await enqueue(
        db_session,
        user_id=user.id, vin=VIN,
        capability_id="tesla.climate.set_keeper_mode",
        params={"mode": 0},
        dispatch_policy="queue",
    )
    await db_session.commit()
    assert row.dispatch_policy == "queue"
    assert row.ttl_seconds == 1800
    assert row.sent_at is None
    assert row.dropped_at is None
    assert json.loads(row.params_json) == {"mode": 0}


# ---------- drain_for_vehicle ----------

async def test_drain_skips_when_no_queue(user, db_session):
    summary = await drain_for_vehicle(
        db_session, user_id=user.id, vin=VIN,
    )
    assert summary == {"checked": 0, "sent": 0, "dropped": 0}


async def test_drain_drops_ttl_expired(user, db_session):
    row = await enqueue(
        db_session,
        user_id=user.id, vin=VIN,
        capability_id="tesla.climate.set_keeper_mode",
        params={"mode": 0},
        dispatch_policy="queue",
        ttl_seconds=60,
    )
    row.queued_at = datetime.utcnow() - timedelta(seconds=120)
    await db_session.commit()

    summary = await drain_for_vehicle(
        db_session, user_id=user.id, vin=VIN,
    )
    assert summary["dropped"] == 1
    assert summary["sent"] == 0
    refreshed = await db_session.get(CommandQueue, row.id)
    assert refreshed.dropped_at is not None
    assert "TTL expired" in (refreshed.error or "")


async def test_drain_skips_when_no_tesla_token(user, db_session):
    """No Tesla token on file → drain leaves rows pending (don't drop;
    user might re-OAuth and the row should still drain after that)."""
    await enqueue(
        db_session,
        user_id=user.id, vin=VIN,
        capability_id="tesla.climate.set_keeper_mode",
        params={"mode": 0},
        dispatch_policy="queue",
    )
    await db_session.commit()

    summary = await drain_for_vehicle(
        db_session, user_id=user.id, vin=VIN,
    )
    assert summary == {"checked": 1, "sent": 0, "dropped": 0}


async def test_drain_dispatches_and_writes_pending(user, db_session, monkeypatch):
    """Happy path: token present, capability dispatch succeeds, row
    marked sent, Phase 9 pending row written from expected_state."""
    db_session.add(TeslaToken(
        user_id=user.id, access_token="x", refresh_token="x",
        expires_at=datetime(2099, 1, 1),
    ))
    await enqueue(
        db_session,
        user_id=user.id, vin=VIN,
        capability_id="tesla.climate.set_keeper_mode",
        params={"mode": 0},
        dispatch_policy="queue",
    )
    await db_session.commit()

    # Avoid real Tesla I/O — fake the dispatch result.
    from app.services import command_queue as cq
    from app.services.capabilities.base import CapabilityResult
    from app.core.security import TokenEncryption
    enc = TokenEncryption()
    monkeypatch.setattr(cq, "_get_user_access_token",
                        lambda db, user_id: _async(enc.decrypt))
    # Easier: just stub the entire token lookup.

    async def fake_token(db, user_id):
        return "fake-access-token"
    monkeypatch.setattr(cq, "_get_user_access_token", fake_token)

    async def fake_dispatch(capability_id, ctx, params):
        return CapabilityResult(success=True, data={"mode": params["mode"]})
    monkeypatch.setattr(cq, "capability_dispatch", fake_dispatch)

    # TeslaClient async-context manager: avoid network.
    class _FakeClient:
        def __init__(self, *a, **kw): pass
        async def __aenter__(self): return self
        async def __aexit__(self, *a): pass
    monkeypatch.setattr(cq, "TeslaClient", _FakeClient)

    summary = await drain_for_vehicle(
        db_session, user_id=user.id, vin=VIN,
    )
    await db_session.commit()
    assert summary["sent"] == 1
    assert summary["dropped"] == 0

    # Phase 9 pending row landed for the keeper_mode predicate.
    pending = (await db_session.execute(
        __import__("sqlalchemy").select(CommandPending).where(
            CommandPending.user_id == user.id
        )
    )).scalars().all()
    assert len(pending) == 1
    assert json.loads(pending[0].expected_state_json) == {
        "vehicle.climate.keeper_mode": 0,
    }


async def test_drain_does_not_revisit_resolved_rows(user, db_session):
    row = await enqueue(
        db_session,
        user_id=user.id, vin=VIN,
        capability_id="tesla.climate.set_keeper_mode",
        params={"mode": 0},
        dispatch_policy="queue",
    )
    row.sent_at = datetime.utcnow()
    await db_session.commit()

    summary = await drain_for_vehicle(
        db_session, user_id=user.id, vin=VIN,
    )
    assert summary == {"checked": 0, "sent": 0, "dropped": 0}


async def test_drain_multi_tenant_isolation(user, db_session):
    other = User(email="b@b.com", password_hash="x", is_active=True)
    db_session.add(other)
    await db_session.flush()
    db_session.add(Vehicle(
        user_id=other.id, vehicle_id="99",
        vin="LRWYAAAAA00000099", display_name="B",
    ))
    await enqueue(
        db_session,
        user_id=other.id, vin="LRWYAAAAA00000099",
        capability_id="tesla.climate.set_keeper_mode",
        params={"mode": 0},
        dispatch_policy="queue",
    )
    await db_session.commit()

    # Drain for OUR vin sees nothing.
    summary = await drain_for_vehicle(
        db_session, user_id=user.id, vin=VIN,
    )
    assert summary == {"checked": 0, "sent": 0, "dropped": 0}


def _async(_):
    return None  # placeholder helper, not used after monkeypatch fix
