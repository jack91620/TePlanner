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
# Engine gate — test the helper directly (full integration is covered
# by the endpoint tests + the 4-line engine wiring).

@pytest.mark.asyncio
async def test_active_snoozes_filters_by_user_and_window(db_session):
    """Returns only the rule_ids whose snooze is still in the future
    AND belongs to the requested user. Expired rows are silently
    dropped; other users' rows never leak."""
    from app.services.automation.engine import _active_snoozes

    user_a = await _make_user(db_session, "user-a@t.com")
    rule_a1 = await _make_rule(db_session, user_a.id, name="a1")
    rule_a2 = await _make_rule(db_session, user_a.id, name="a2")
    user_b = await _make_user(db_session, "user-b@t.com")
    rule_b1 = await _make_rule(db_session, user_b.id, name="b1")

    now = datetime.utcnow()
    db_session.add(AutomationSnooze(
        user_id=user_a.id, rule_id=rule_a1.id,
        snoozed_until_utc=now + timedelta(hours=1),
        created_at=now,
    ))
    db_session.add(AutomationSnooze(
        user_id=user_a.id, rule_id=rule_a2.id,
        snoozed_until_utc=now - timedelta(minutes=5),  # expired
        created_at=now - timedelta(hours=1),
    ))
    db_session.add(AutomationSnooze(
        user_id=user_b.id, rule_id=rule_b1.id,
        snoozed_until_utc=now + timedelta(hours=1),
        created_at=now,
    ))
    await db_session.commit()

    active_a = await _active_snoozes(db_session, user_a.id, now)
    assert active_a == {rule_a1.id}

    active_b = await _active_snoozes(db_session, user_b.id, now)
    assert active_b == {rule_b1.id}

    future_now = now + timedelta(hours=2)
    assert await _active_snoozes(db_session, user_a.id, future_now) == set()
