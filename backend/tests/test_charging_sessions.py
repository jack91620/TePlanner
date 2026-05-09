"""Phase A.4 — /vehicles/{vid}/sessions + /suggest-charge-limit endpoints."""

import uuid
from datetime import datetime, timedelta

import pytest
from sqlalchemy import select

from app.db.models import ChargingSession, ScheduledDeparture, User


VIN_A = "LRWYGCFS0NC517553"
VIN_B = "LRWYGCFS0NC517999"


async def _make_user(db_session, email="cs@t.com") -> User:
    user = User(email=email, password_hash="x", is_active=True)
    db_session.add(user)
    await db_session.commit()
    return user


def _auth(user: User) -> dict:
    from app.core.security import create_access_token
    token = create_access_token(data={"sub": str(user.id)})
    return {"Authorization": f"Bearer {token}"}


# ---------------------------------------------------------------------------
# POST /sessions

async def test_post_requires_auth(client):
    r = await client.post(
        f"/api/v1/vehicles/{VIN_A}/sessions",
        json={"started_at": "2026-05-09T10:00:00"},
    )
    assert r.status_code == 401


async def test_post_creates_session(client, db_session):
    user = await _make_user(db_session, "create-session@t.com")
    started = datetime.utcnow().isoformat()
    r = await client.post(
        f"/api/v1/vehicles/{VIN_A}/sessions",
        json={
            "client_session_id": "client-1",
            "started_at": started,
            "start_soc": 30,
            "start_range_km": 120.5,
            "location_name": "公司",
        },
        headers=_auth(user),
    )
    assert r.status_code == 200
    body = r.json()
    assert body["start_soc"] == 30
    assert body["vehicle_id"] == VIN_A
    assert body["ended_at"] is None
    assert body["duration_minutes"] is None


async def test_post_upserts_on_client_session_id(client, db_session):
    user = await _make_user(db_session, "upsert@t.com")
    started = (datetime.utcnow() - timedelta(hours=1)).isoformat()
    sid = str(uuid.uuid4())

    r1 = await client.post(
        f"/api/v1/vehicles/{VIN_A}/sessions",
        json={
            "client_session_id": sid,
            "started_at": started,
            "start_soc": 25,
            "start_range_km": 100,
        },
        headers=_auth(user),
    )
    assert r1.status_code == 200
    first_id = r1.json()["id"]

    r2 = await client.post(
        f"/api/v1/vehicles/{VIN_A}/sessions",
        json={
            "client_session_id": sid,
            "started_at": started,
            "ended_at": datetime.utcnow().isoformat(),
            "end_soc": 78,
            "end_range_km": 320,
            "energy_added_kwh": 32.5,
            "ended_as_complete": True,
        },
        headers=_auth(user),
    )
    assert r2.status_code == 200
    body = r2.json()
    assert body["id"] == first_id, "must upsert, not create new row"
    assert body["end_soc"] == 78
    assert body["soc_delta"] == 53
    assert body["range_added_km"] == 220.0
    assert body["duration_minutes"] is not None
    assert body["ended_as_complete"] is True


async def test_post_without_client_id_creates_per_call(client, db_session):
    user = await _make_user(db_session, "no-cid@t.com")
    for _ in range(3):
        await client.post(
            f"/api/v1/vehicles/{VIN_A}/sessions",
            json={"started_at": datetime.utcnow().isoformat()},
            headers=_auth(user),
        )
    rows = (await db_session.execute(
        select(ChargingSession).where(ChargingSession.user_id == user.id)
    )).scalars().all()
    assert len(rows) == 3


async def test_post_validates_soc_range(client, db_session):
    user = await _make_user(db_session, "soc-range@t.com")
    r = await client.post(
        f"/api/v1/vehicles/{VIN_A}/sessions",
        json={
            "started_at": datetime.utcnow().isoformat(),
            "start_soc": 150,
        },
        headers=_auth(user),
    )
    assert r.status_code == 422


# ---------------------------------------------------------------------------
# GET /sessions

async def test_get_requires_auth(client):
    r = await client.get(f"/api/v1/vehicles/{VIN_A}/sessions")
    assert r.status_code == 401


async def test_get_returns_most_recent_first(client, db_session):
    user = await _make_user(db_session, "list@t.com")
    base = datetime.utcnow()
    for offset_hours in (5, 1, 10):
        await client.post(
            f"/api/v1/vehicles/{VIN_A}/sessions",
            json={
                "client_session_id": f"c-{offset_hours}",
                "started_at": (base - timedelta(hours=offset_hours)).isoformat(),
            },
            headers=_auth(user),
        )

    r = await client.get(
        f"/api/v1/vehicles/{VIN_A}/sessions", headers=_auth(user)
    )
    assert r.status_code == 200
    sessions = r.json()["sessions"]
    starts = [s["started_at"] for s in sessions]
    assert starts == sorted(starts, reverse=True), "most-recent first"


async def test_get_isolates_by_user_and_vehicle(client, db_session):
    user_a = await _make_user(db_session, "list-iso-a@t.com")
    user_b = await _make_user(db_session, "list-iso-b@t.com")
    await client.post(
        f"/api/v1/vehicles/{VIN_A}/sessions",
        json={"client_session_id": "a-1", "started_at": datetime.utcnow().isoformat()},
        headers=_auth(user_a),
    )
    await client.post(
        f"/api/v1/vehicles/{VIN_B}/sessions",
        json={"client_session_id": "a-vinb", "started_at": datetime.utcnow().isoformat()},
        headers=_auth(user_a),
    )
    r = await client.get(
        f"/api/v1/vehicles/{VIN_A}/sessions", headers=_auth(user_b)
    )
    assert r.status_code == 200
    assert r.json()["sessions"] == []


# ---------------------------------------------------------------------------
# POST /suggest-charge-limit

async def test_suggest_requires_auth(client):
    r = await client.post(
        f"/api/v1/vehicles/{VIN_A}/suggest-charge-limit",
        json={"daily_limit_soc": 80, "trip_limit_soc": 100},
    )
    assert r.status_code == 401


async def test_suggest_falls_back_to_daily_when_no_departure(client, db_session):
    user = await _make_user(db_session, "sug-daily@t.com")
    r = await client.post(
        f"/api/v1/vehicles/{VIN_A}/suggest-charge-limit",
        json={
            "current_limit": 90,
            "daily_limit_soc": 80,
            "trip_limit_soc": 100,
        },
        headers=_auth(user),
    )
    assert r.status_code == 200
    body = r.json()
    assert body["recommended_percent"] == 80
    assert body["reason"] == "daily"
    assert body["already_matches"] is False


async def test_suggest_uses_trip_when_departure_within_window(client, db_session):
    user = await _make_user(db_session, "sug-trip@t.com")
    db_session.add(ScheduledDeparture(
        user_id=user.id,
        departure_at_utc=datetime.utcnow() + timedelta(hours=4, minutes=30),
        lead_minutes=15,
        enabled=True,
        created_at=datetime.utcnow(),
    ))
    await db_session.commit()
    r = await client.post(
        f"/api/v1/vehicles/{VIN_A}/suggest-charge-limit",
        json={
            "current_limit": 80,
            "daily_limit_soc": 80,
            "trip_limit_soc": 100,
            "trip_window_hours": 12,
        },
        headers=_auth(user),
    )
    assert r.status_code == 200
    body = r.json()
    assert body["recommended_percent"] == 100
    assert body["reason"] == "upcoming_departure"
    # floor((4h30m - small handler latency) / 1h) = 4
    assert body["hours_away"] == 4


async def test_suggest_ignores_disabled_departure(client, db_session):
    user = await _make_user(db_session, "sug-disabled@t.com")
    db_session.add(ScheduledDeparture(
        user_id=user.id,
        departure_at_utc=datetime.utcnow() + timedelta(hours=2),
        lead_minutes=15,
        enabled=False,
        created_at=datetime.utcnow(),
    ))
    await db_session.commit()
    r = await client.post(
        f"/api/v1/vehicles/{VIN_A}/suggest-charge-limit",
        json={
            "current_limit": 80,
            "daily_limit_soc": 80,
            "trip_limit_soc": 100,
        },
        headers=_auth(user),
    )
    body = r.json()
    assert body["reason"] == "daily"


async def test_suggest_already_matches(client, db_session):
    user = await _make_user(db_session, "sug-match@t.com")
    r = await client.post(
        f"/api/v1/vehicles/{VIN_A}/suggest-charge-limit",
        json={
            "current_limit": 80,
            "daily_limit_soc": 80,
            "trip_limit_soc": 100,
        },
        headers=_auth(user),
    )
    body = r.json()
    assert body["already_matches"] is True
