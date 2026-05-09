"""Phase A.3 — /api/v1/user/scheduled-departure CRUD."""

from datetime import datetime, timedelta

import pytest
from sqlalchemy import select

from app.db.models import ScheduledDeparture, User


VIN = "LRWYGCFS0NC517553"


async def _make_user(db_session, email="dep@t.com") -> User:
    user = User(email=email, password_hash="x", is_active=True)
    db_session.add(user)
    await db_session.commit()
    return user


def _auth(user: User) -> dict:
    from app.core.security import create_access_token
    token = create_access_token(data={"sub": str(user.id)})
    return {"Authorization": f"Bearer {token}"}


async def test_get_requires_auth(client):
    r = await client.get("/api/v1/user/scheduled-departure")
    assert r.status_code == 401


async def test_put_requires_auth(client):
    r = await client.put(
        "/api/v1/user/scheduled-departure",
        json={"departure_at_utc": "2030-01-01T08:00:00"},
    )
    assert r.status_code == 401


async def test_get_returns_null_when_unset(client, db_session):
    user = await _make_user(db_session, "unset@t.com")
    r = await client.get("/api/v1/user/scheduled-departure", headers=_auth(user))
    assert r.status_code == 200
    assert r.json() is None


async def test_put_creates_then_get_returns_it(client, db_session):
    user = await _make_user(db_session, "create@t.com")
    departure = datetime.utcnow() + timedelta(hours=2)
    r = await client.put(
        "/api/v1/user/scheduled-departure",
        json={
            "departure_at_utc": departure.isoformat(),
            "lead_minutes": 20,
            "label": "上班",
            "vehicle_id": VIN,
        },
        headers=_auth(user),
    )
    assert r.status_code == 200
    body = r.json()
    assert body["lead_minutes"] == 20
    assert body["label"] == "上班"
    assert body["vehicle_id"] == VIN
    fire_at = datetime.fromisoformat(body["fire_at_utc"])
    assert (departure - fire_at).total_seconds() == 20 * 60

    r2 = await client.get("/api/v1/user/scheduled-departure", headers=_auth(user))
    assert r2.status_code == 200
    assert r2.json()["label"] == "上班"


async def test_put_replaces_existing(client, db_session):
    user = await _make_user(db_session, "replace@t.com")
    await client.put(
        "/api/v1/user/scheduled-departure",
        json={
            "departure_at_utc": (datetime.utcnow() + timedelta(hours=1)).isoformat(),
            "lead_minutes": 10,
            "label": "first",
        },
        headers=_auth(user),
    )
    await client.put(
        "/api/v1/user/scheduled-departure",
        json={
            "departure_at_utc": (datetime.utcnow() + timedelta(hours=5)).isoformat(),
            "lead_minutes": 30,
            "label": "second",
        },
        headers=_auth(user),
    )
    rows = (await db_session.execute(
        select(ScheduledDeparture).where(ScheduledDeparture.user_id == user.id)
    )).scalars().all()
    assert len(rows) == 1
    assert rows[0].label == "second"
    assert rows[0].lead_minutes == 30


async def test_put_clamps_lead_minutes_range(client, db_session):
    user = await _make_user(db_session, "clamp@t.com")
    r = await client.put(
        "/api/v1/user/scheduled-departure",
        json={
            "departure_at_utc": (datetime.utcnow() + timedelta(hours=1)).isoformat(),
            "lead_minutes": 0,
        },
        headers=_auth(user),
    )
    assert r.status_code == 422
    r = await client.put(
        "/api/v1/user/scheduled-departure",
        json={
            "departure_at_utc": (datetime.utcnow() + timedelta(hours=1)).isoformat(),
            "lead_minutes": 999,
        },
        headers=_auth(user),
    )
    assert r.status_code == 422


async def test_put_target_charge_soc_range(client, db_session):
    user = await _make_user(db_session, "soc@t.com")
    r = await client.put(
        "/api/v1/user/scheduled-departure",
        json={
            "departure_at_utc": (datetime.utcnow() + timedelta(hours=1)).isoformat(),
            "target_charge_soc": 19,
        },
        headers=_auth(user),
    )
    assert r.status_code == 422
    r = await client.put(
        "/api/v1/user/scheduled-departure",
        json={
            "departure_at_utc": (datetime.utcnow() + timedelta(hours=1)).isoformat(),
            "target_charge_soc": 80,
        },
        headers=_auth(user),
    )
    assert r.status_code == 200
    assert r.json()["target_charge_soc"] == 80


async def test_delete_clears(client, db_session):
    user = await _make_user(db_session, "del@t.com")
    await client.put(
        "/api/v1/user/scheduled-departure",
        json={
            "departure_at_utc": (datetime.utcnow() + timedelta(hours=1)).isoformat(),
        },
        headers=_auth(user),
    )
    r = await client.delete(
        "/api/v1/user/scheduled-departure", headers=_auth(user)
    )
    assert r.status_code == 200
    rows = (await db_session.execute(
        select(ScheduledDeparture).where(ScheduledDeparture.user_id == user.id)
    )).scalars().all()
    assert rows == []


async def test_delete_idempotent(client, db_session):
    user = await _make_user(db_session, "idem-del@t.com")
    r = await client.delete(
        "/api/v1/user/scheduled-departure", headers=_auth(user)
    )
    assert r.status_code == 200
    body = r.json()
    assert body == {"success": True}


async def test_each_user_isolated(client, db_session):
    user_a = await _make_user(db_session, "iso-a@t.com")
    user_b = await _make_user(db_session, "iso-b@t.com")
    await client.put(
        "/api/v1/user/scheduled-departure",
        json={
            "departure_at_utc": (datetime.utcnow() + timedelta(hours=1)).isoformat(),
            "label": "user-a",
        },
        headers=_auth(user_a),
    )
    r = await client.get(
        "/api/v1/user/scheduled-departure", headers=_auth(user_b)
    )
    assert r.status_code == 200
    assert r.json() is None
