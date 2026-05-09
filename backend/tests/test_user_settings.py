"""Phase A.5 — /api/v1/user/settings endpoints."""

import pytest
from sqlalchemy import select

from app.db.models import User, UserSetting


async def _make_user(db_session, email="set@t.com") -> User:
    user = User(email=email, password_hash="x", is_active=True)
    db_session.add(user)
    await db_session.commit()
    return user


def _auth(user: User) -> dict:
    from app.core.security import create_access_token
    token = create_access_token(data={"sub": str(user.id)})
    return {"Authorization": f"Bearer {token}"}


async def test_get_requires_auth(client):
    r = await client.get("/api/v1/user/settings")
    assert r.status_code == 401


async def test_put_requires_auth(client):
    r = await client.put(
        "/api/v1/user/settings",
        json={"settings": {"x": 1}},
    )
    assert r.status_code == 401


async def test_get_returns_empty_when_unset(client, db_session):
    user = await _make_user(db_session, "empty-set@t.com")
    r = await client.get("/api/v1/user/settings", headers=_auth(user))
    assert r.status_code == 200
    body = r.json()
    assert body["settings"] == {}
    assert body["updated_at"] is None


async def test_put_creates_then_get_returns(client, db_session):
    user = await _make_user(db_session, "create-set@t.com")
    r = await client.put(
        "/api/v1/user/settings",
        json={
            "settings": {
                "daily_charge_limit_soc": 80,
                "trip_charge_limit_soc": 100,
                "preheat_lead_minutes": 15,
                "hub.show_welcome_banner": True,
                "departures": ["08:00", "17:30"],
            },
        },
        headers=_auth(user),
    )
    assert r.status_code == 200
    settings = r.json()["settings"]
    assert settings["daily_charge_limit_soc"] == 80
    assert settings["departures"] == ["08:00", "17:30"]

    r = await client.get("/api/v1/user/settings", headers=_auth(user))
    assert r.json()["settings"] == settings


async def test_put_merges_by_default(client, db_session):
    user = await _make_user(db_session, "merge@t.com")
    await client.put(
        "/api/v1/user/settings",
        json={"settings": {"a": 1, "b": 2}},
        headers=_auth(user),
    )
    await client.put(
        "/api/v1/user/settings",
        json={"settings": {"b": 3, "c": 4}},
        headers=_auth(user),
    )
    r = await client.get("/api/v1/user/settings", headers=_auth(user))
    assert r.json()["settings"] == {"a": 1, "b": 3, "c": 4}


async def test_put_replace_all_wipes_unmentioned(client, db_session):
    user = await _make_user(db_session, "replace-all@t.com")
    await client.put(
        "/api/v1/user/settings",
        json={"settings": {"a": 1, "b": 2, "c": 3}},
        headers=_auth(user),
    )
    await client.put(
        "/api/v1/user/settings",
        json={"settings": {"b": 99}, "replace_all": True},
        headers=_auth(user),
    )
    r = await client.get("/api/v1/user/settings", headers=_auth(user))
    assert r.json()["settings"] == {"b": 99}


async def test_put_rejects_invalid_keys(client, db_session):
    user = await _make_user(db_session, "bad-key@t.com")
    long_key = "x" * 81
    r = await client.put(
        "/api/v1/user/settings",
        json={"settings": {long_key: "v"}},
        headers=_auth(user),
    )
    assert r.status_code == 400


async def test_values_round_trip_unicode_and_nested(client, db_session):
    user = await _make_user(db_session, "unicode@t.com")
    payload = {
        "中文键": "值",
        "nested": {"a": [1, 2, {"deep": True}]},
        "boolean": False,
        "null_value": None,
    }
    await client.put(
        "/api/v1/user/settings",
        json={"settings": payload},
        headers=_auth(user),
    )
    r = await client.get("/api/v1/user/settings", headers=_auth(user))
    assert r.json()["settings"] == payload


async def test_user_isolation(client, db_session):
    user_a = await _make_user(db_session, "iso-set-a@t.com")
    user_b = await _make_user(db_session, "iso-set-b@t.com")
    await client.put(
        "/api/v1/user/settings",
        json={"settings": {"private": 42}},
        headers=_auth(user_a),
    )
    r = await client.get("/api/v1/user/settings", headers=_auth(user_b))
    assert r.json()["settings"] == {}


async def test_put_persists_via_db_query(client, db_session):
    user = await _make_user(db_session, "persist-set@t.com")
    await client.put(
        "/api/v1/user/settings",
        json={"settings": {"k": 123}},
        headers=_auth(user),
    )
    rows = (await db_session.execute(
        select(UserSetting).where(UserSetting.user_id == user.id)
    )).scalars().all()
    assert len(rows) == 1
    assert rows[0].key == "k"
    assert rows[0].value_json == "123"
