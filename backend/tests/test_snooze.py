"""Phase A.1 — automation_snooze API + engine gate."""

import json
import uuid
from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import select

from app.db.models import (
    AutomationRule,
    AutomationSnooze,
    PushedAlert,
    User,
    Vehicle,
)


VIN = "LRWYGCFS0NC517553"


async def _make_user(db_session, email="snooze@t.com") -> User:
    user = User(email=email, password_hash="x", is_active=True)
    db_session.add(user)
    await db_session.commit()
    return user


async def _make_rule(db_session, user_id: int, name="r") -> AutomationRule:
    spec = {
        "kind": "camp_mode",
        "trigger": {
            "type": "state_duration",
            "entity": "vehicle.climate.keeper_mode",
            "equals": 3,
            "for_minutes": 120,
            "state_key": "camp_mode_first_seen",
        },
        "actions_above": [],
    }
    row = AutomationRule(
        id=str(uuid.uuid4()),
        user_id=user_id,
        preset_id=None,
        name=name,
        enabled=True,
        spec_json=json.dumps(spec),
        version=1,
    )
    db_session.add(row)
    await db_session.commit()
    return row


def _auth(user: User) -> dict:
    from app.core.security import create_access_token
    token = create_access_token(data={"sub": str(user.id)})
    return {"Authorization": f"Bearer {token}"}


async def test_snooze_requires_auth(client):
    r = await client.post(
        "/api/v1/automations/anyrule/snooze",
        json={"hours": 1},
    )
    assert r.status_code == 401


async def test_snooze_404_when_rule_missing(client, db_session):
    user = await _make_user(db_session, "missing@t.com")
    r = await client.post(
        "/api/v1/automations/does-not-exist/snooze",
        json={"hours": 1},
        headers=_auth(user),
    )
    assert r.status_code == 404


async def test_snooze_requires_until_xor_hours(client, db_session):
    user = await _make_user(db_session, "xor@t.com")
    rule = await _make_rule(db_session, user.id)

    r = await client.post(
        f"/api/v1/automations/{rule.id}/snooze",
        json={},
        headers=_auth(user),
    )
    assert r.status_code == 400

    r = await client.post(
        f"/api/v1/automations/{rule.id}/snooze",
        json={"hours": 2, "until": "2030-01-01T00:00:00"},
        headers=_auth(user),
    )
    assert r.status_code == 400


async def test_snooze_in_past_rejected(client, db_session):
    user = await _make_user(db_session, "past@t.com")
    rule = await _make_rule(db_session, user.id)
    r = await client.post(
        f"/api/v1/automations/{rule.id}/snooze",
        json={"until": "2020-01-01T00:00:00"},
        headers=_auth(user),
    )
    assert r.status_code == 400


async def test_snooze_create_then_list(client, db_session):
    user = await _make_user(db_session, "create@t.com")
    rule = await _make_rule(db_session, user.id)
    r = await client.post(
        f"/api/v1/automations/{rule.id}/snooze",
        json={"hours": 6, "reason": "充电中，别打扰"},
        headers=_auth(user),
    )
    assert r.status_code == 200
    body = r.json()
    assert body["rule_id"] == rule.id
    assert body["reason"] == "充电中，别打扰"
    snoozed_until = datetime.fromisoformat(body["snoozed_until_utc"])
    delta = snoozed_until - datetime.utcnow()
    assert timedelta(hours=5, minutes=58) < delta < timedelta(hours=6, minutes=2)

    r = await client.get("/api/v1/automations/snoozes", headers=_auth(user))
    assert r.status_code == 200
    assert len(r.json()["snoozes"]) == 1


async def test_snooze_replace_on_resnooze(client, db_session):
    user = await _make_user(db_session, "replace@t.com")
    rule = await _make_rule(db_session, user.id)
    r1 = await client.post(
        f"/api/v1/automations/{rule.id}/snooze",
        json={"hours": 1},
        headers=_auth(user),
    )
    assert r1.status_code == 200
    r2 = await client.post(
        f"/api/v1/automations/{rule.id}/snooze",
        json={"hours": 24, "reason": "extended"},
        headers=_auth(user),
    )
    assert r2.status_code == 200
    rows = (await db_session.execute(
        select(AutomationSnooze).where(AutomationSnooze.rule_id == rule.id)
    )).scalars().all()
    assert len(rows) == 1
    assert rows[0].reason == "extended"


async def test_unsnooze_clears(client, db_session):
    user = await _make_user(db_session, "unsnooze@t.com")
    rule = await _make_rule(db_session, user.id)
    await client.post(
        f"/api/v1/automations/{rule.id}/snooze",
        json={"hours": 1},
        headers=_auth(user),
    )
    r = await client.delete(
        f"/api/v1/automations/{rule.id}/snooze",
        headers=_auth(user),
    )
    assert r.status_code == 200
    rows = (await db_session.execute(
        select(AutomationSnooze).where(AutomationSnooze.rule_id == rule.id)
    )).scalars().all()
    assert rows == []


async def test_unsnooze_idempotent(client, db_session):
    user = await _make_user(db_session, "idem@t.com")
    rule = await _make_rule(db_session, user.id)
    r = await client.delete(
        f"/api/v1/automations/{rule.id}/snooze",
        headers=_auth(user),
    )
    assert r.status_code == 200


async def test_list_snoozes_hides_expired(client, db_session):
    user = await _make_user(db_session, "expired@t.com")
    rule = await _make_rule(db_session, user.id)
    expired = AutomationSnooze(
        user_id=user.id,
        rule_id=rule.id,
        snoozed_until_utc=datetime.utcnow() - timedelta(minutes=5),
        created_at=datetime.utcnow() - timedelta(hours=1),
    )
    db_session.add(expired)
    await db_session.commit()
    r = await client.get("/api/v1/automations/snoozes", headers=_auth(user))
    assert r.status_code == 200
    assert r.json()["snoozes"] == []


# ---------------------------------------------------------------------------
# Engine gate

@pytest.mark.asyncio
async def test_engine_skips_snoozed_rule(db_session):
    """All rules whose ids are in active snoozes must produce no alerts,
    even when their triggers match. Engine seeds presets first; we
    snooze every seeded rule, assert the tick is silent, then clear
    the snoozes and confirm the camp_mode preset fires.
    """
    from app.services.automation.engine import (
        AutomationEngine,
        ensure_presets_seeded,
    )
    from app.services.automation.base import (
        AutomationSettings,
        VehicleStateSnapshot,
    )

    user = User(email="engine-gate@t.com", password_hash="x", is_active=True)
    db_session.add(user)
    await db_session.commit()
    veh = Vehicle(user_id=user.id, vehicle_id="42", vin=VIN, display_name="V")
    db_session.add(veh)
    await db_session.commit()

    await ensure_presets_seeded(db_session, user.id)
    all_rules = (await db_session.execute(
        select(AutomationRule).where(AutomationRule.user_id == user.id)
    )).scalars().all()
    snoozes = [
        AutomationSnooze(
            user_id=user.id,
            rule_id=r.id,
            snoozed_until_utc=datetime.utcnow() + timedelta(hours=1),
            created_at=datetime.utcnow(),
        )
        for r in all_rules
    ]
    for s in snoozes:
        db_session.add(s)
    await db_session.commit()

    state = VehicleStateSnapshot(climate_keeper_mode=3)
    engine = AutomationEngine()
    result = await engine.run_for_vehicle(
        db_session,
        user_id=user.id,
        vehicle_id=VIN,
        state=state,
        settings=AutomationSettings(),
        push=False,
    )
    assert result.alerts == [], "every rule is snoozed — tick must be silent"

    for s in snoozes:
        s.snoozed_until_utc = datetime.utcnow() - timedelta(minutes=1)
    await db_session.commit()
    result2 = await engine.run_for_vehicle(
        db_session,
        user_id=user.id,
        vehicle_id=VIN,
        state=state,
        settings=AutomationSettings(),
        push=False,
    )
    assert any(a.kind.value == "camp_mode" for a in result2.alerts), \
        "camp_mode preset should fire once its snooze expires"
