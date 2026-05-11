"""Phase 11 — state-gated wait actions: wait_resolver tests.

Pin the contract:
  * predicate match → resolved_at + emits the chained `then` notify
  * elapsed > deadline → timed_out_at, no alert
  * predicate mismatch + within deadline → row stays unresolved
  * enqueue with same rule_id supersedes prior unresolved row
  * Numeric ops (>=, <, etc) coerce both sides to float
  * `{entity_value}` substituted into title/body
"""

import json
from datetime import datetime, timedelta

import pytest
from sqlalchemy import select

from app.db.models import PendingWait, User, Vehicle
from app.services.automation.base import (
    AlertSeverity,
    VehicleStateSnapshot,
)
from app.services.automation.wait_resolver import (
    check_and_resolve,
    enqueue_wait,
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


# ---------- enqueue_wait ----------

async def test_enqueue_wait_persists_with_default_timeout(user, db_session):
    row = await enqueue_wait(
        db_session,
        user_id=user.id, vehicle_id=VIN,
        rule_id="rule-preheat",
        predicate={"entity": "vehicle.inside_temp_c", "op": ">=", "value": 20},
        then_action={"type": "notify", "title": "已就绪", "body": ""},
    )
    await db_session.commit()
    assert row.deadline_at - row.created_at == timedelta(minutes=15)
    assert json.loads(row.predicate_json)["op"] == ">="


async def test_enqueue_supersedes_prior_unresolved_row(user, db_session):
    first = await enqueue_wait(
        db_session,
        user_id=user.id, vehicle_id=VIN,
        rule_id="rule-preheat",
        predicate={"entity": "vehicle.inside_temp_c", "op": ">=", "value": 18},
        then_action={"type": "notify", "title": "X", "body": ""},
    )
    second = await enqueue_wait(
        db_session,
        user_id=user.id, vehicle_id=VIN,
        rule_id="rule-preheat",
        predicate={"entity": "vehicle.inside_temp_c", "op": ">=", "value": 20},
        then_action={"type": "notify", "title": "Y", "body": ""},
    )
    await db_session.commit()

    # First row was force-timed-out by the second enqueue.
    refreshed = await db_session.get(PendingWait, first.id)
    assert refreshed.timed_out_at is not None
    assert second.timed_out_at is None
    assert second.resolved_at is None


# ---------- check_and_resolve ----------

async def test_predicate_match_resolves_and_emits_alert(user, db_session):
    await enqueue_wait(
        db_session,
        user_id=user.id, vehicle_id=VIN, rule_id="r1",
        predicate={"entity": "vehicle.inside_temp_c", "op": ">=", "value": 20},
        then_action={
            "type": "notify",
            "title": "预热完成",
            "body": "舱内已达 {entity_value}°C，可以出发",
            "severity": "info",
        },
    )
    await db_session.commit()

    snap = VehicleStateSnapshot(inside_temp_c=21.5)
    alerts = await check_and_resolve(
        db_session, user_id=user.id, vehicle_id=VIN, snap=snap,
    )
    assert len(alerts) == 1
    a = alerts[0]
    assert a.title == "预热完成"
    assert "21.5" in a.detail
    assert a.severity == AlertSeverity.INFO
    # No explicit kind in then-action → falls back to WAIT_RESOLVED
    # (NOT chargeComplete — see #19 in tech-debt audit; CHARGE_COMPLETE
    # was the prior placeholder which mis-fired iOS chargeComplete UI).
    from app.services.automation.base import AlertKind
    assert a.kind == AlertKind.WAIT_RESOLVED

    # Row marked resolved.
    rows = (await db_session.execute(select(PendingWait))).scalars().all()
    assert rows[0].resolved_at is not None


async def test_explicit_kind_in_then_action_is_used(user, db_session):
    """Rule designers can set then.kind to any AlertKind for routing."""
    await enqueue_wait(
        db_session,
        user_id=user.id, vehicle_id=VIN, rule_id="r1",
        predicate={"entity": "vehicle.inside_temp_c", "op": ">=", "value": 20},
        then_action={
            "type": "notify", "title": "预热完成", "body": "",
            "kind": "weekdayPreheat",   # explicit override
        },
    )
    await db_session.commit()
    snap = VehicleStateSnapshot(inside_temp_c=21.5)
    alerts = await check_and_resolve(
        db_session, user_id=user.id, vehicle_id=VIN, snap=snap,
    )
    from app.services.automation.base import AlertKind
    assert alerts[0].kind == AlertKind.WEEKDAY_PREHEAT


async def test_unknown_kind_in_then_action_falls_back(user, db_session):
    await enqueue_wait(
        db_session,
        user_id=user.id, vehicle_id=VIN, rule_id="r1",
        predicate={"entity": "vehicle.inside_temp_c", "op": ">=", "value": 20},
        then_action={
            "type": "notify", "title": "预热完成", "body": "",
            "kind": "totallyMadeUpKind",
        },
    )
    await db_session.commit()
    snap = VehicleStateSnapshot(inside_temp_c=21.5)
    alerts = await check_and_resolve(
        db_session, user_id=user.id, vehicle_id=VIN, snap=snap,
    )
    from app.services.automation.base import AlertKind
    assert alerts[0].kind == AlertKind.WAIT_RESOLVED


async def test_predicate_mismatch_within_deadline_stays_unresolved(user, db_session):
    await enqueue_wait(
        db_session,
        user_id=user.id, vehicle_id=VIN, rule_id="r1",
        predicate={"entity": "vehicle.inside_temp_c", "op": ">=", "value": 20},
        then_action={"type": "notify", "title": "已就绪", "body": ""},
    )
    await db_session.commit()

    snap = VehicleStateSnapshot(inside_temp_c=12)
    alerts = await check_and_resolve(
        db_session, user_id=user.id, vehicle_id=VIN, snap=snap,
    )
    assert alerts == []
    rows = (await db_session.execute(select(PendingWait))).scalars().all()
    assert rows[0].resolved_at is None
    assert rows[0].timed_out_at is None


async def test_deadline_elapsed_marks_timed_out(user, db_session):
    row = await enqueue_wait(
        db_session,
        user_id=user.id, vehicle_id=VIN, rule_id="r1",
        predicate={"entity": "vehicle.inside_temp_c", "op": ">=", "value": 20},
        then_action={"type": "notify", "title": "X", "body": ""},
        timeout_minutes=15,
    )
    # Backdate deadline past now.
    row.deadline_at = datetime.utcnow() - timedelta(minutes=1)
    await db_session.commit()

    snap = VehicleStateSnapshot(inside_temp_c=12)
    alerts = await check_and_resolve(
        db_session, user_id=user.id, vehicle_id=VIN, snap=snap,
    )
    assert alerts == []
    refreshed = await db_session.get(PendingWait, row.id)
    assert refreshed.timed_out_at is not None
    assert refreshed.resolved_at is None


async def test_unobserved_entity_keeps_row_pending(user, db_session):
    """If the snapshot field is None (telemetry hasn't seen it yet),
    we must NOT resolve. Defer to a later tick when data arrives."""
    await enqueue_wait(
        db_session,
        user_id=user.id, vehicle_id=VIN, rule_id="r1",
        predicate={"entity": "vehicle.inside_temp_c", "op": ">=", "value": 20},
        then_action={"type": "notify", "title": "X", "body": ""},
    )
    await db_session.commit()

    snap = VehicleStateSnapshot()  # no inside_temp_c
    alerts = await check_and_resolve(
        db_session, user_id=user.id, vehicle_id=VIN, snap=snap,
    )
    assert alerts == []


async def test_resolved_rows_not_revisited(user, db_session):
    row = await enqueue_wait(
        db_session,
        user_id=user.id, vehicle_id=VIN, rule_id="r1",
        predicate={"entity": "vehicle.inside_temp_c", "op": ">=", "value": 20},
        then_action={"type": "notify", "title": "X", "body": ""},
    )
    row.resolved_at = datetime.utcnow()
    await db_session.commit()

    alerts = await check_and_resolve(
        db_session, user_id=user.id, vehicle_id=VIN,
        snap=VehicleStateSnapshot(inside_temp_c=21),
    )
    assert alerts == []


async def test_multi_tenant_isolation(user, db_session):
    other = User(email="b@b.com", password_hash="x", is_active=True)
    db_session.add(other)
    await db_session.flush()
    db_session.add(Vehicle(
        user_id=other.id, vehicle_id="99",
        vin="LRWYAAAAA00000099", display_name="B",
    ))
    await enqueue_wait(
        db_session,
        user_id=other.id, vehicle_id="LRWYAAAAA00000099", rule_id="r1",
        predicate={"entity": "vehicle.inside_temp_c", "op": ">=", "value": 20},
        then_action={"type": "notify", "title": "X", "body": ""},
    )
    await db_session.commit()

    alerts = await check_and_resolve(
        db_session, user_id=user.id, vehicle_id=VIN,
        snap=VehicleStateSnapshot(inside_temp_c=25),
    )
    assert alerts == []  # other user's wait must not leak


async def test_string_predicate_equality(user, db_session):
    """Non-numeric `==` works for string entities like
    vehicle.charging.state."""
    await enqueue_wait(
        db_session,
        user_id=user.id, vehicle_id=VIN, rule_id="r1",
        predicate={"entity": "vehicle.charging.state", "op": "==", "value": "Complete"},
        then_action={"type": "notify", "title": "充电完成", "body": ""},
    )
    await db_session.commit()
    alerts = await check_and_resolve(
        db_session, user_id=user.id, vehicle_id=VIN,
        snap=VehicleStateSnapshot(charging_state="Complete"),
    )
    assert len(alerts) == 1
