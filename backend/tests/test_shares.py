"""Cross-platform share codes — /api/v1/shares.

Coverage:
- POST creates a share, returns a 6-char base32 code + echoes payload
- GET by code returns the full payload + increments view_count
- GET unknown code → 404
- GET expired → 410, GET revoked → 410
- DELETE owner-only (non-owner gets 404, not 403, to hide existence)
- min_app_version gate via X-App-Version header → 412
- /shares/mine returns owner shares, newest first, with revoked flag
- code normalization: dash + spaces + lowercase all work
"""

from __future__ import annotations

from datetime import datetime, timedelta

import pytest
from sqlalchemy import select

from app.db.models import Share, User


async def _make_user(db_session, email="share@t.com") -> User:
    user = User(email=email, password_hash="x", is_active=True)
    db_session.add(user)
    await db_session.commit()
    return user


def _auth(user: User) -> dict:
    from app.core.security import create_access_token
    token = create_access_token(data={"sub": str(user.id)})
    return {"Authorization": f"Bearer {token}"}


SAMPLE_ACTION_PAYLOAD = {
    "name": "锁车",
    "icon": "lock",
    "tint": "blue",
    "steps": [{"capability": "tesla.security.door_lock", "params": {}}],
    "confirm_required": False,
}


# ---------------------------------------------------------------------------
# Auth gates


async def test_post_requires_auth(client):
    r = await client.post(
        "/api/v1/shares",
        json={"share_type": "action", "payload": SAMPLE_ACTION_PAYLOAD},
    )
    assert r.status_code == 401


async def test_get_requires_auth(client):
    r = await client.get("/api/v1/shares/ABCDEF")
    assert r.status_code == 401


async def test_delete_requires_auth(client):
    r = await client.delete("/api/v1/shares/ABCDEF")
    assert r.status_code == 401


# ---------------------------------------------------------------------------
# Happy paths


async def test_post_returns_code_and_echoes_payload(client, db_session):
    user = await _make_user(db_session, "post-ok@t.com")
    r = await client.post(
        "/api/v1/shares",
        json={"share_type": "action", "payload": SAMPLE_ACTION_PAYLOAD},
        headers=_auth(user),
    )
    assert r.status_code == 201, r.text
    body = r.json()
    code = body["code"]
    # 6 chars from the no-ambiguous alphabet.
    assert len(code) == 6
    assert all(c in "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" for c in code)
    assert body["payload"] == SAMPLE_ACTION_PAYLOAD
    assert body["share_type"] == "action"
    assert body["view_count"] == 0
    assert body["revoked"] is False


async def test_get_by_code_round_trips(client, db_session):
    user = await _make_user(db_session, "get-rt@t.com")
    post = await client.post(
        "/api/v1/shares",
        json={"share_type": "rule", "payload": {"name": "夜间限充", "spec": {"a": 1}}},
        headers=_auth(user),
    )
    code = post.json()["code"]

    importer = await _make_user(db_session, "importer-rt@t.com")
    r = await client.get(f"/api/v1/shares/{code}", headers=_auth(importer))
    assert r.status_code == 200
    body = r.json()
    assert body["payload"] == {"name": "夜间限充", "spec": {"a": 1}}
    assert body["share_type"] == "rule"
    assert body["view_count"] == 1

    # A second GET bumps the counter.
    r2 = await client.get(f"/api/v1/shares/{code}", headers=_auth(importer))
    assert r2.json()["view_count"] == 2


async def test_get_normalizes_dash_and_case(client, db_session):
    user = await _make_user(db_session, "norm@t.com")
    post = await client.post(
        "/api/v1/shares",
        json={"share_type": "action", "payload": SAMPLE_ACTION_PAYLOAD},
        headers=_auth(user),
    )
    code = post.json()["code"]
    # Insert a dash, lowercase half, add whitespace — server should
    # normalize all that into the same lookup.
    typed = f"{code[:4].lower()}-{code[4:]} "
    r = await client.get(f"/api/v1/shares/{typed}", headers=_auth(user))
    assert r.status_code == 200


# ---------------------------------------------------------------------------
# Negative paths


async def test_get_unknown_code_404(client, db_session):
    user = await _make_user(db_session, "404@t.com")
    r = await client.get("/api/v1/shares/ZZZZZZ", headers=_auth(user))
    assert r.status_code == 404


async def test_get_expired_410(client, db_session):
    user = await _make_user(db_session, "exp@t.com")
    # Create with min positive expiry then backdate.
    post = await client.post(
        "/api/v1/shares",
        json={
            "share_type": "action",
            "payload": SAMPLE_ACTION_PAYLOAD,
            "expires_in_days": 1,
        },
        headers=_auth(user),
    )
    code = post.json()["code"]
    row = await db_session.get(Share, code)
    row.expires_at = datetime.utcnow() - timedelta(seconds=1)
    await db_session.commit()

    r = await client.get(f"/api/v1/shares/{code}", headers=_auth(user))
    assert r.status_code == 410


async def test_delete_revokes_and_then_get_410(client, db_session):
    user = await _make_user(db_session, "rev@t.com")
    post = await client.post(
        "/api/v1/shares",
        json={"share_type": "action", "payload": SAMPLE_ACTION_PAYLOAD},
        headers=_auth(user),
    )
    code = post.json()["code"]

    r = await client.delete(f"/api/v1/shares/{code}", headers=_auth(user))
    assert r.status_code == 204

    r2 = await client.get(f"/api/v1/shares/{code}", headers=_auth(user))
    assert r2.status_code == 410


async def test_delete_by_non_owner_404(client, db_session):
    owner = await _make_user(db_session, "owner-del@t.com")
    other = await _make_user(db_session, "other-del@t.com")
    post = await client.post(
        "/api/v1/shares",
        json={"share_type": "action", "payload": SAMPLE_ACTION_PAYLOAD},
        headers=_auth(owner),
    )
    code = post.json()["code"]

    r = await client.delete(f"/api/v1/shares/{code}", headers=_auth(other))
    # 404 not 403 — don't leak existence of codes you don't own.
    assert r.status_code == 404

    # Owner's share is still alive.
    r2 = await client.get(f"/api/v1/shares/{code}", headers=_auth(owner))
    assert r2.status_code == 200


# ---------------------------------------------------------------------------
# Version gate


async def test_min_app_version_gate_412(client, db_session):
    user = await _make_user(db_session, "minver@t.com")
    post = await client.post(
        "/api/v1/shares",
        json={
            "share_type": "action",
            "payload": SAMPLE_ACTION_PAYLOAD,
            "min_app_version": "40",
        },
        headers=_auth(user),
    )
    code = post.json()["code"]

    # Importer on build 38 — below min 40 → 412.
    headers = {**_auth(user), "X-App-Version": "38"}
    r = await client.get(f"/api/v1/shares/{code}", headers=headers)
    assert r.status_code == 412
    assert "40" in r.json()["detail"]

    # Importer on build 41 — above min → 200.
    headers["X-App-Version"] = "41"
    r2 = await client.get(f"/api/v1/shares/{code}", headers=headers)
    assert r2.status_code == 200


async def test_min_app_version_unset_lets_old_clients_in(client, db_session):
    user = await _make_user(db_session, "no-minver@t.com")
    post = await client.post(
        "/api/v1/shares",
        json={"share_type": "action", "payload": SAMPLE_ACTION_PAYLOAD},
        headers=_auth(user),
    )
    code = post.json()["code"]

    headers = {**_auth(user), "X-App-Version": "1"}
    r = await client.get(f"/api/v1/shares/{code}", headers=headers)
    assert r.status_code == 200


# ---------------------------------------------------------------------------
# /shares/mine


async def test_list_mine_returns_my_shares_only(client, db_session):
    owner = await _make_user(db_session, "list-mine@t.com")
    other = await _make_user(db_session, "list-other@t.com")
    await client.post(
        "/api/v1/shares",
        json={"share_type": "action", "payload": SAMPLE_ACTION_PAYLOAD},
        headers=_auth(owner),
    )
    await client.post(
        "/api/v1/shares",
        json={"share_type": "rule", "payload": {"name": "夜限"}},
        headers=_auth(other),
    )

    r = await client.get("/api/v1/shares/mine", headers=_auth(owner))
    assert r.status_code == 200
    shares = r.json()["shares"]
    assert len(shares) == 1
    assert shares[0]["share_type"] == "action"


async def test_list_mine_shows_revoked_flag(client, db_session):
    user = await _make_user(db_session, "mine-rev@t.com")
    post = await client.post(
        "/api/v1/shares",
        json={"share_type": "action", "payload": SAMPLE_ACTION_PAYLOAD},
        headers=_auth(user),
    )
    code = post.json()["code"]
    await client.delete(f"/api/v1/shares/{code}", headers=_auth(user))

    r = await client.get("/api/v1/shares/mine", headers=_auth(user))
    assert r.json()["shares"][0]["revoked"] is True
