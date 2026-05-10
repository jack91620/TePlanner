"""Tests for `tesla_auth_service.dedup_anon_by_vin`.

Scenario: every iOS first-launch hits `/auth/tesla/authorize` without
a `user_id`, so the backend creates an anon `android_<uuid>@test.local`
account. Without dedup, every install / keychain wipe spawned a new
orphan on the same VIN — 139 such users on a single VIN as of
2026-05-10. The dedup helper merges anon → canonical at OAuth-callback
time so the leak doesn't recur.
"""

from datetime import datetime, timedelta

import pytest
from sqlalchemy import select
from unittest.mock import patch, AsyncMock

from app.db.models import TeslaToken, User, Vehicle
from app.services.tesla_auth_service import dedup_anon_by_vin


def _expires():
    return datetime.utcnow() + timedelta(hours=8)


@pytest.fixture
async def anon_user(db_session):
    user = User(email="android_aaaa1111@test.local", nickname="Test User")
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest.fixture
async def real_user(db_session):
    user = User(email="real@example.com", nickname="Real User")
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest.fixture
async def canonical_user(db_session):
    """An older user already bound to the test VIN."""
    user = User(email="android_old0000@test.local", nickname="Test User")
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


VIN = "LRWY0000000000001"


def _mock_tesla_client(vin: str = VIN):
    """Patch TeslaClient so list_vehicles returns the supplied VIN."""
    mock = AsyncMock()
    mock.list_vehicles = AsyncMock(return_value={
        "response": [{"vin": vin, "id": 123}],
        "count": 1,
    })
    mock.__aenter__ = AsyncMock(return_value=mock)
    mock.__aexit__ = AsyncMock(return_value=None)
    return mock


@pytest.mark.asyncio
async def test_dedup_merges_anon_into_canonical(db_session, anon_user, canonical_user):
    """When an anon's VIN matches an existing user → returns canonical id,
    deletes the anon, moves the TeslaToken."""
    # Canonical already owns the VIN
    db_session.add(Vehicle(
        user_id=canonical_user.id, vehicle_id="v1", vin=VIN,
        display_name="Canonical Tesla",
    ))
    # Anon just OAuth'd; has a fresh token
    db_session.add(TeslaToken(
        user_id=anon_user.id, access_token="encrypted_new",
        refresh_token="encrypted_refresh_new",
        expires_at=_expires(),
    ))
    await db_session.commit()

    with patch(
        "app.services.tesla_auth_service.TeslaClient",
        return_value=_mock_tesla_client(),
    ):
        result = await dedup_anon_by_vin(
            db=db_session, user_id=anon_user.id, access_token="anything",
        )

    assert result == canonical_user.id

    # Anon user should be gone
    gone = (await db_session.execute(
        select(User).where(User.id == anon_user.id)
    )).scalar_one_or_none()
    assert gone is None

    # TeslaToken now belongs to canonical
    tokens = (await db_session.execute(
        select(TeslaToken).where(TeslaToken.user_id == canonical_user.id)
    )).scalars().all()
    assert len(tokens) == 1
    assert tokens[0].access_token == "encrypted_new"


@pytest.mark.asyncio
async def test_dedup_skips_real_user(db_session, real_user, canonical_user):
    """A non-anon user (real email) must be left alone even if a
    duplicate VIN binding exists. They're explicitly linking Tesla;
    we don't merge them away."""
    db_session.add(Vehicle(
        user_id=canonical_user.id, vehicle_id="v1", vin=VIN,
        display_name="Other",
    ))
    db_session.add(TeslaToken(
        user_id=real_user.id, access_token="enc", refresh_token="enc",
        expires_at=_expires(),
    ))
    await db_session.commit()

    with patch(
        "app.services.tesla_auth_service.TeslaClient",
        return_value=_mock_tesla_client(),
    ):
        result = await dedup_anon_by_vin(
            db=db_session, user_id=real_user.id, access_token="anything",
        )

    assert result == real_user.id  # unchanged
    still_exists = (await db_session.execute(
        select(User).where(User.id == real_user.id)
    )).scalar_one_or_none()
    assert still_exists is not None


@pytest.mark.asyncio
async def test_dedup_keeps_anon_when_vin_is_new(db_session, anon_user):
    """First time this VIN is seen → no merge. Anon stays as canonical."""
    db_session.add(TeslaToken(
        user_id=anon_user.id, access_token="enc", refresh_token="enc",
        expires_at=_expires(),
    ))
    await db_session.commit()

    with patch(
        "app.services.tesla_auth_service.TeslaClient",
        return_value=_mock_tesla_client(),
    ):
        result = await dedup_anon_by_vin(
            db=db_session, user_id=anon_user.id, access_token="anything",
        )

    assert result == anon_user.id
    still_exists = (await db_session.execute(
        select(User).where(User.id == anon_user.id)
    )).scalar_one_or_none()
    assert still_exists is not None


@pytest.mark.asyncio
async def test_dedup_softfails_on_tesla_api_error(db_session, anon_user):
    """If Tesla API call raises, dedup must not crash the OAuth flow —
    return original user_id, leave everything intact."""
    bad_mock = AsyncMock()
    bad_mock.list_vehicles = AsyncMock(side_effect=RuntimeError("Tesla 503"))
    bad_mock.__aenter__ = AsyncMock(return_value=bad_mock)
    bad_mock.__aexit__ = AsyncMock(return_value=None)

    with patch(
        "app.services.tesla_auth_service.TeslaClient",
        return_value=bad_mock,
    ):
        result = await dedup_anon_by_vin(
            db=db_session, user_id=anon_user.id, access_token="anything",
        )

    assert result == anon_user.id
