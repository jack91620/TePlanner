"""Phase E — /api/v1/devices/register accepts platform + provider_token."""

import pytest
from sqlalchemy import select

from app.db.models import DeviceToken, User


async def _make_user(db_session, email="dev@t.com") -> User:
    u = User(email=email, password_hash="x", is_active=True)
    db_session.add(u)
    await db_session.commit()
    return u


def _auth(user: User) -> dict:
    from app.core.security import create_access_token
    return {"Authorization": f"Bearer {create_access_token(data={'sub': str(user.id)})}"}


async def test_register_requires_auth(client):
    r = await client.post(
        "/api/v1/devices/register",
        json={"token": "x" * 16},
    )
    assert r.status_code == 401


async def test_register_legacy_payload_defaults_to_apns(client, db_session):
    user = await _make_user(db_session, "legacy@t.com")
    r = await client.post(
        "/api/v1/devices/register",
        json={"token": "abc1234567890def"},
        headers=_auth(user),
    )
    assert r.status_code == 200
    row = (await db_session.execute(
        select(DeviceToken).where(DeviceToken.user_id == user.id)
    )).scalar_one()
    assert row.platform == "apns"
    assert row.provider_token is None


async def test_register_explicit_apns(client, db_session):
    user = await _make_user(db_session, "apns@t.com")
    r = await client.post(
        "/api/v1/devices/register",
        json={"token": "apnsapns" * 4, "platform": "apns"},
        headers=_auth(user),
    )
    assert r.status_code == 200
    row = (await db_session.execute(
        select(DeviceToken).where(DeviceToken.user_id == user.id)
    )).scalar_one()
    assert row.platform == "apns"


async def test_register_jpush_with_provider_token(client, db_session):
    user = await _make_user(db_session, "jpush@t.com")
    r = await client.post(
        "/api/v1/devices/register",
        json={
            "token": "raw-installation-token-1234",
            "platform": "jpush",
            "provider_token": "rid-12345abcdef",
            "bundle_id": "com.teplanner.android",
        },
        headers=_auth(user),
    )
    assert r.status_code == 200
    row = (await db_session.execute(
        select(DeviceToken).where(DeviceToken.user_id == user.id)
    )).scalar_one()
    assert row.platform == "jpush"
    assert row.provider_token == "rid-12345abcdef"
    assert row.bundle_id == "com.teplanner.android"


async def test_register_harmony(client, db_session):
    user = await _make_user(db_session, "harm@t.com")
    r = await client.post(
        "/api/v1/devices/register",
        json={
            "token": "hms-token-xyz-12345",
            "platform": "harmony",
            "provider_token": "hms-rid-xyz789",
        },
        headers=_auth(user),
    )
    assert r.status_code == 200
    row = (await db_session.execute(
        select(DeviceToken).where(DeviceToken.user_id == user.id)
    )).scalar_one()
    assert row.platform == "harmony"
    assert row.provider_token == "hms-rid-xyz789"


async def test_register_unknown_platform_returns_400(client, db_session):
    user = await _make_user(db_session, "bad-pf@t.com")
    r = await client.post(
        "/api/v1/devices/register",
        json={"token": "x" * 16, "platform": "fcm"},
        headers=_auth(user),
    )
    assert r.status_code == 400


async def test_register_legacy_ios_value_normalises_to_apns(client, db_session):
    user = await _make_user(db_session, "ios-norm@t.com")
    r = await client.post(
        "/api/v1/devices/register",
        json={"token": "x" * 16, "platform": "ios"},
        headers=_auth(user),
    )
    assert r.status_code == 200
    row = (await db_session.execute(
        select(DeviceToken).where(DeviceToken.user_id == user.id)
    )).scalar_one()
    assert row.platform == "apns", \
        "back-compat: clients still sending 'ios' must be normalized to 'apns'"


async def test_reregister_updates_platform_and_provider_token(client, db_session):
    user = await _make_user(db_session, "reg@t.com")
    token = "stable-token-1234abcdef"
    await client.post(
        "/api/v1/devices/register",
        json={"token": token, "platform": "apns"},
        headers=_auth(user),
    )
    await client.post(
        "/api/v1/devices/register",
        json={"token": token, "platform": "jpush", "provider_token": "new-rid"},
        headers=_auth(user),
    )
    rows = (await db_session.execute(
        select(DeviceToken).where(DeviceToken.user_id == user.id)
    )).scalars().all()
    assert len(rows) == 1
    assert rows[0].platform == "jpush"
    assert rows[0].provider_token == "new-rid"
