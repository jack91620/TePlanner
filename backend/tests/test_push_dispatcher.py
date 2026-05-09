"""Phase E — push dispatcher routing.

Verifies that:
  - tokens with platform=apns route to the APNs client
  - tokens with platform=jpush route to the JPush client
  - tokens with platform=harmony route to Huawei Push Kit
  - unknown platforms are skipped (logged) rather than crashing
  - empty token list yields a 0-device summary
  - per-platform send results contribute independently to sent/failed
"""

from datetime import datetime
from unittest.mock import AsyncMock, patch

import pytest
from sqlalchemy import select

from app.db.models import DeviceToken, User
from app.services.push.dispatcher import PushDispatcher


async def _user(db_session, email="push@t.com") -> User:
    u = User(email=email, password_hash="x", is_active=True)
    db_session.add(u)
    await db_session.commit()
    return u


def _add_token(db_session, user_id: int, platform: str, token: str, provider_token: str = None):
    db_session.add(DeviceToken(
        user_id=user_id,
        token=token,
        platform=platform,
        provider_token=provider_token,
        bundle_id=None,
    ))


@pytest.mark.asyncio
async def test_dispatcher_no_devices_returns_zero_summary(db_session):
    user = await _user(db_session, "no-devices@t.com")
    dispatcher = PushDispatcher()
    summary = await dispatcher.send(
        db=db_session, user_id=user.id, title="t", body="b",
    )
    assert summary.devices == 0
    assert summary.sent == 0
    assert summary.failed == 0


@pytest.mark.asyncio
async def test_dispatcher_routes_apns_token_to_apns_client(db_session):
    user = await _user(db_session, "apns-route@t.com")
    _add_token(db_session, user.id, "apns", "abc123def456")
    await db_session.commit()

    with patch("app.services.push.dispatcher.apns_client") as apns, \
         patch("app.services.push.dispatcher.jpush_client") as jpush, \
         patch("app.services.push.dispatcher.harmony_push_client") as harmony:
        apns.send = AsyncMock(return_value=True)
        jpush.send = AsyncMock(return_value=True)
        harmony.send = AsyncMock(return_value=True)

        dispatcher = PushDispatcher()
        summary = await dispatcher.send(
            db=db_session, user_id=user.id, title="t", body="b",
        )

    apns.send.assert_awaited_once()
    jpush.send.assert_not_awaited()
    harmony.send.assert_not_awaited()
    assert summary.sent == 1
    assert summary.by_platform == {"apns": 1}


@pytest.mark.asyncio
async def test_dispatcher_routes_jpush_token_with_provider_token(db_session):
    user = await _user(db_session, "jpush-route@t.com")
    _add_token(db_session, user.id, "jpush", "raw-token", provider_token="rid-12345")
    await db_session.commit()

    with patch("app.services.push.dispatcher.apns_client") as apns, \
         patch("app.services.push.dispatcher.jpush_client") as jpush, \
         patch("app.services.push.dispatcher.harmony_push_client") as harmony:
        apns.send = AsyncMock(return_value=False)
        jpush.send = AsyncMock(return_value=True)
        harmony.send = AsyncMock(return_value=False)

        dispatcher = PushDispatcher()
        summary = await dispatcher.send(
            db=db_session, user_id=user.id, title="t", body="b",
        )

    jpush.send.assert_awaited_once()
    assert jpush.send.await_args.kwargs["provider_token"] == "rid-12345", \
        "JPush should receive the provider_token (registration_id), not the raw token"
    apns.send.assert_not_awaited()
    harmony.send.assert_not_awaited()
    assert summary.sent == 1
    assert summary.by_platform == {"jpush": 1}


@pytest.mark.asyncio
async def test_dispatcher_routes_harmony_token(db_session):
    user = await _user(db_session, "harmony-route@t.com")
    _add_token(db_session, user.id, "harmony", "hms-token-xyz", provider_token="hms-rid-789")
    await db_session.commit()

    with patch("app.services.push.dispatcher.apns_client") as apns, \
         patch("app.services.push.dispatcher.jpush_client") as jpush, \
         patch("app.services.push.dispatcher.harmony_push_client") as harmony:
        apns.send = AsyncMock(return_value=False)
        jpush.send = AsyncMock(return_value=False)
        harmony.send = AsyncMock(return_value=True)

        dispatcher = PushDispatcher()
        summary = await dispatcher.send(
            db=db_session, user_id=user.id, title="t", body="b",
        )

    harmony.send.assert_awaited_once()
    assert harmony.send.await_args.kwargs["provider_token"] == "hms-rid-789"
    assert summary.sent == 1
    assert summary.by_platform == {"harmony": 1}


@pytest.mark.asyncio
async def test_dispatcher_fans_across_platforms_and_aggregates_summary(db_session):
    user = await _user(db_session, "fan@t.com")
    _add_token(db_session, user.id, "apns", "apns-token-1")
    _add_token(db_session, user.id, "apns", "apns-token-2")
    _add_token(db_session, user.id, "jpush", "j-token", provider_token="j-rid")
    _add_token(db_session, user.id, "harmony", "h-token", provider_token="h-rid")
    await db_session.commit()

    with patch("app.services.push.dispatcher.apns_client") as apns, \
         patch("app.services.push.dispatcher.jpush_client") as jpush, \
         patch("app.services.push.dispatcher.harmony_push_client") as harmony:
        # Mix of success/failure so the summary aggregator is exercised.
        apns.send = AsyncMock(side_effect=[True, False])
        jpush.send = AsyncMock(return_value=True)
        harmony.send = AsyncMock(return_value=False)

        dispatcher = PushDispatcher()
        summary = await dispatcher.send(
            db=db_session, user_id=user.id, title="t", body="b",
        )

    assert summary.devices == 4
    assert summary.sent == 2  # 1 apns + 1 jpush
    assert summary.failed == 2  # 1 apns + 1 harmony
    assert summary.by_platform == {"apns": 2, "jpush": 1, "harmony": 1}


@pytest.mark.asyncio
async def test_dispatcher_skips_unknown_platform(db_session):
    user = await _user(db_session, "unknown-pf@t.com")
    _add_token(db_session, user.id, "fcm", "shouldnt-route")
    await db_session.commit()

    with patch("app.services.push.dispatcher.apns_client") as apns, \
         patch("app.services.push.dispatcher.jpush_client") as jpush, \
         patch("app.services.push.dispatcher.harmony_push_client") as harmony:
        apns.send = AsyncMock(return_value=True)
        jpush.send = AsyncMock(return_value=True)
        harmony.send = AsyncMock(return_value=True)
        dispatcher = PushDispatcher()
        summary = await dispatcher.send(
            db=db_session, user_id=user.id, title="t", body="b",
        )

    apns.send.assert_not_awaited()
    jpush.send.assert_not_awaited()
    harmony.send.assert_not_awaited()
    assert summary.devices == 1
    assert summary.skipped == 1
    assert summary.sent == 0


@pytest.mark.asyncio
async def test_dispatcher_legacy_ios_platform_value_routes_to_apns(db_session):
    """Pre-Phase-E rows have platform='ios'; the back-fill migration
    rewrites them to 'apns', but the dispatcher must also accept the
    raw legacy value defensively (in case a migration was skipped)."""
    user = await _user(db_session, "legacy-ios@t.com")
    _add_token(db_session, user.id, "ios", "legacy-token")
    await db_session.commit()

    with patch("app.services.push.dispatcher.apns_client") as apns:
        apns.send = AsyncMock(return_value=True)
        with patch("app.services.push.dispatcher.jpush_client") as jpush, \
             patch("app.services.push.dispatcher.harmony_push_client") as harmony:
            jpush.send = AsyncMock()
            harmony.send = AsyncMock()
            dispatcher = PushDispatcher()
            summary = await dispatcher.send(
                db=db_session, user_id=user.id, title="t", body="b",
            )
    apns.send.assert_awaited_once()
    assert summary.sent == 1
