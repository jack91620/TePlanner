"""POST /routes/save — record a trip in the user's history.

Bug context: before this endpoint, the route_plans table had a GET
listing endpoint (/routes/) but no INSERT site anywhere in the
codebase. The "最近" tab on iOS was permanently empty. This file
pins the contract so that doesn't regress.
"""

from __future__ import annotations

import pytest

from app.db.models import RoutePlan, User


async def _make_user(db_session, email="rsave@t.com") -> User:
    user = User(email=email, password_hash="x", is_active=True)
    db_session.add(user)
    await db_session.commit()
    return user


def _auth(user: User) -> dict:
    from app.core.security import create_access_token
    token = create_access_token(data={"sub": str(user.id)})
    return {"Authorization": f"Bearer {token}"}


SAMPLE_BODY = {
    "origin": {"latitude": 39.9, "longitude": 116.4, "address": "北京"},
    "destination": {"latitude": 31.2, "longitude": 121.5, "address": "上海"},
    "total_distance_km": 1213.4,
    "total_duration_minutes": 720,
    "polyline_points": [[116.4, 39.9], [118.5, 35.6], [121.5, 31.2]],
    "charging_stops": [
        {
            "station_id": "amap-1",
            "name": "济南服务区",
            "latitude": 36.7,
            "longitude": 117.0,
            "arrival_soc": 30,
            "departure_soc": 80,
            "charging_duration_minutes": 35,
        },
    ],
}


# ---------------------------------------------------------------------------
# Auth gate


async def test_save_requires_auth(client):
    r = await client.post("/api/v1/routes/save", json=SAMPLE_BODY)
    assert r.status_code == 401


# ---------------------------------------------------------------------------
# Happy path


async def test_save_persists_row_and_returns_id(client, db_session):
    user = await _make_user(db_session, "save-ok@t.com")
    r = await client.post(
        "/api/v1/routes/save", json=SAMPLE_BODY, headers=_auth(user),
    )
    assert r.status_code == 201, r.text
    body = r.json()
    assert isinstance(body["id"], int)
    assert body["created_at"]  # non-empty ISO timestamp

    # Row landed in DB with all fields. Refresh-from-db to defeat any
    # session cache.
    row = await db_session.get(RoutePlan, body["id"])
    await db_session.refresh(row)
    assert row.user_id == user.id
    assert row.origin_address == "北京"
    assert row.dest_address == "上海"
    assert row.total_distance_km == pytest.approx(1213.4)
    assert row.total_duration_minutes == 720
    assert row.polyline_json is not None
    assert row.charging_stops_json is not None
    assert row.status == "sent_to_car"


async def test_save_minimal_body_just_origin_and_dest(client, db_session):
    """No totals, no polyline, no stops — still persists. A trip we
    forgot to enrich beats no history row at all."""
    user = await _make_user(db_session, "save-min@t.com")
    minimal = {
        "origin": {"latitude": 39.9, "longitude": 116.4},
        "destination": {"latitude": 31.2, "longitude": 121.5},
    }
    r = await client.post(
        "/api/v1/routes/save", json=minimal, headers=_auth(user),
    )
    assert r.status_code == 201
    rid = r.json()["id"]
    row = await db_session.get(RoutePlan, rid)
    assert row.polyline_json is None
    assert row.charging_stops_json is None


# ---------------------------------------------------------------------------
# Listing round-trip


async def test_saved_route_shows_up_in_list(client, db_session):
    user = await _make_user(db_session, "save-list@t.com")
    r1 = await client.post(
        "/api/v1/routes/save", json=SAMPLE_BODY, headers=_auth(user),
    )
    r2 = await client.get("/api/v1/routes/", headers=_auth(user))
    assert r2.status_code == 200
    body = r2.json()
    assert body["count"] >= 1
    ids = [r["id"] for r in body["routes"]]
    assert r1.json()["id"] in ids


async def test_list_is_per_user_only(client, db_session):
    """Owner sees their saves; another user does not."""
    owner = await _make_user(db_session, "save-owner@t.com")
    other = await _make_user(db_session, "save-other@t.com")
    await client.post(
        "/api/v1/routes/save", json=SAMPLE_BODY, headers=_auth(owner),
    )
    r = await client.get("/api/v1/routes/", headers=_auth(other))
    assert r.status_code == 200
    assert r.json()["count"] == 0
