"""Phase A.2 — PUT /api/v1/automations/order endpoint + display_order
override of `_sort_rules_canonically`."""

import json
import uuid
from datetime import datetime

import pytest
from sqlalchemy import select

from app.db.models import AutomationRule, User
from app.services.automation.engine import _sort_rules_canonically
from app.services.automation.presets import ALL_PRESETS


VIN = "LRWYGCFS0NC517553"


async def _make_user(db_session, email="ord@t.com") -> User:
    user = User(email=email, password_hash="x", is_active=True)
    db_session.add(user)
    await db_session.commit()
    return user


async def _make_rule(
    db_session, user_id: int, name="r", display_order=None, preset_id=None,
) -> AutomationRule:
    spec = {
        "kind": "camp_mode",
        "trigger": {
            "type": "state_duration",
            "entity": "vehicle.climate.keeper_mode",
            "equals": 3,
            "for_minutes": 120,
            "state_key": "k",
        },
        "actions_above": [],
    }
    row = AutomationRule(
        id=str(uuid.uuid4()),
        user_id=user_id,
        preset_id=preset_id,
        name=name,
        enabled=True,
        spec_json=json.dumps(spec),
        version=1,
        display_order=display_order,
    )
    db_session.add(row)
    await db_session.commit()
    return row


def _auth(user: User) -> dict:
    from app.core.security import create_access_token
    token = create_access_token(data={"sub": str(user.id)})
    return {"Authorization": f"Bearer {token}"}


def test_sort_honors_display_order_first():
    """Rows with explicit display_order sort ahead of unranked rows
    even if their preset/created_at would put them later."""
    rows = [
        AutomationRule(
            id="legacy", user_id=1, preset_id=ALL_PRESETS[0].preset_id,
            name="p0", enabled=True, spec_json="{}", version=1,
            created_at=datetime(2020, 1, 1), display_order=None,
        ),
        AutomationRule(
            id="ranked2", user_id=1, preset_id=None,
            name="r2", enabled=True, spec_json="{}", version=1,
            created_at=datetime(2026, 5, 1), display_order=1,
        ),
        AutomationRule(
            id="ranked1", user_id=1, preset_id=None,
            name="r1", enabled=True, spec_json="{}", version=1,
            created_at=datetime(2026, 5, 2), display_order=0,
        ),
    ]
    out = _sort_rules_canonically(rows)
    assert [r.id for r in out] == ["ranked1", "ranked2", "legacy"]


async def test_reorder_requires_auth(client):
    r = await client.put(
        "/api/v1/automations/order",
        json={"rule_ids": []},
    )
    assert r.status_code == 401


async def test_reorder_rejects_duplicates(client, db_session):
    user = await _make_user(db_session, "dup@t.com")
    rule = await _make_rule(db_session, user.id)
    r = await client.put(
        "/api/v1/automations/order",
        json={"rule_ids": [rule.id, rule.id]},
        headers=_auth(user),
    )
    assert r.status_code == 400


async def test_reorder_404_on_unknown_rule(client, db_session):
    user = await _make_user(db_session, "unk@t.com")
    rule = await _make_rule(db_session, user.id)
    r = await client.put(
        "/api/v1/automations/order",
        json={"rule_ids": [rule.id, "nope-id"]},
        headers=_auth(user),
    )
    assert r.status_code == 404


async def test_reorder_404_on_other_users_rule(client, db_session):
    """Owner check: we 404 when a rule_id belongs to another user.
    Defensive — silent skip would let attackers probe rule existence."""
    user_a = await _make_user(db_session, "a-owner@t.com")
    user_b = await _make_user(db_session, "b-owner@t.com")
    rule_a = await _make_rule(db_session, user_a.id, name="a")
    rule_b = await _make_rule(db_session, user_b.id, name="b")
    r = await client.put(
        "/api/v1/automations/order",
        json={"rule_ids": [rule_a.id, rule_b.id]},
        headers=_auth(user_a),
    )
    assert r.status_code == 404


async def test_reorder_persists_and_returns_sorted_list(client, db_session):
    user = await _make_user(db_session, "persist@t.com")
    r1 = await _make_rule(db_session, user.id, name="first")
    r2 = await _make_rule(db_session, user.id, name="second")
    r3 = await _make_rule(db_session, user.id, name="third")

    r = await client.put(
        "/api/v1/automations/order",
        json={"rule_ids": [r3.id, r1.id, r2.id]},
        headers=_auth(user),
    )
    assert r.status_code == 200
    body = r.json()
    returned_ids = [
        x["id"] for x in body["rules"] if x["display_order"] is not None
    ]
    assert returned_ids == [r3.id, r1.id, r2.id]

    # Round-trip via DB to ensure persistence.
    rows = (await db_session.execute(
        select(AutomationRule).where(AutomationRule.user_id == user.id)
    )).scalars().all()
    by_id = {r.id: r.display_order for r in rows}
    assert by_id[r3.id] == 0
    assert by_id[r1.id] == 1
    assert by_id[r2.id] == 2


async def test_reorder_clear_resets_unmentioned(client, db_session):
    """`clear=true` with rule_ids=[] resets ALL display_orders. With
    a non-empty rule_ids list, only the unmentioned ones reset."""
    user = await _make_user(db_session, "clear@t.com")
    r1 = await _make_rule(db_session, user.id, name="a", display_order=0)
    r2 = await _make_rule(db_session, user.id, name="b", display_order=1)
    r3 = await _make_rule(db_session, user.id, name="c", display_order=2)

    r = await client.put(
        "/api/v1/automations/order",
        json={"rule_ids": [r1.id], "clear": True},
        headers=_auth(user),
    )
    assert r.status_code == 200

    rows = (await db_session.execute(
        select(AutomationRule).where(AutomationRule.user_id == user.id)
    )).scalars().all()
    by_id = {r.id: r.display_order for r in rows}
    assert by_id[r1.id] == 0
    assert by_id[r2.id] is None
    assert by_id[r3.id] is None


async def test_listing_reflects_display_order(client, db_session):
    user = await _make_user(db_session, "list@t.com")
    r1 = await _make_rule(db_session, user.id, name="first")
    r2 = await _make_rule(db_session, user.id, name="second")

    await client.put(
        "/api/v1/automations/order",
        json={"rule_ids": [r2.id, r1.id]},
        headers=_auth(user),
    )

    r = await client.get("/api/v1/automations/", headers=_auth(user))
    assert r.status_code == 200
    body = r.json()
    user_rule_ids = [
        x["id"] for x in body["rules"]
        if x["preset_id"] is None and x["display_order"] is not None
    ]
    assert user_rule_ids == [r2.id, r1.id]
