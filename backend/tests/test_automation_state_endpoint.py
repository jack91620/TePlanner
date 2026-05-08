"""GET /api/v1/automations/state — Phase 5 telemetry-since endpoint.

Pins the contract iOS depends on:
  * 401 for unauthenticated callers
  * Empty entries list when the user has no Vehicle row
  * Pairs every `tel:<entity>:since` with its `tel:<entity>:value`
  * Decodes values from JSON (so booleans / ints round-trip)
"""

from datetime import datetime, timezone

import pytest
from sqlalchemy import select

from app.db.models import AutomationState, User, Vehicle


VIN = "LRWYGCFS0NC517553"


async def _make_user_and_vehicle(db_session) -> tuple[User, Vehicle]:
    user = User(email="t@t.com", password_hash="x", is_active=True)
    db_session.add(user)
    await db_session.flush()
    veh = Vehicle(
        user_id=user.id,
        vehicle_id="42",
        vin=VIN,
        display_name="Test",
    )
    db_session.add(veh)
    await db_session.commit()
    return user, veh


def _auth_headers_for(user: User) -> dict:
    """Build a JWT for the seeded user, matching the format
    AuthService.create_access_token produces."""
    from app.core.security import create_access_token
    token = create_access_token(data={"sub": str(user.id)})
    return {"Authorization": f"Bearer {token}"}


async def test_state_endpoint_requires_auth(client):
    r = await client.get("/api/v1/automations/state")
    assert r.status_code == 401


async def test_state_endpoint_empty_when_no_vehicle(client, db_session):
    user = User(email="empty@t.com", password_hash="x", is_active=True)
    db_session.add(user)
    await db_session.commit()

    r = await client.get(
        "/api/v1/automations/state",
        headers=_auth_headers_for(user),
    )
    assert r.status_code == 200
    body = r.json()
    assert body["vehicle_id"] is None
    assert body["entries"] == []


async def test_state_endpoint_returns_paired_since_and_value(client, db_session):
    user, _ = await _make_user_and_vehicle(db_session)

    # Mimic what TelemetryStateWriter would write on a transition.
    keeper_since = datetime(2026, 5, 8, 7, 56, 5, tzinfo=timezone.utc)
    locked_since = datetime(2026, 5, 8, 8, 15, 53, 384112, tzinfo=timezone.utc)
    db_session.add_all([
        AutomationState(
            user_id=user.id, vehicle_id=VIN,
            key="tel:vehicle.climate.keeper_mode:since",
            value=keeper_since.isoformat(),
        ),
        AutomationState(
            user_id=user.id, vehicle_id=VIN,
            key="tel:vehicle.climate.keeper_mode:value",
            value="3",
        ),
        AutomationState(
            user_id=user.id, vehicle_id=VIN,
            key="tel:vehicle.locked:since",
            value=locked_since.isoformat(),
        ),
        AutomationState(
            user_id=user.id, vehicle_id=VIN,
            key="tel:vehicle.locked:value",
            value="false",
        ),
        # Non-telemetry key — must NOT appear in the response.
        AutomationState(
            user_id=user.id, vehicle_id=VIN,
            key="campMode:startedAt",
            value=keeper_since.isoformat(),
        ),
    ])
    await db_session.commit()

    r = await client.get(
        "/api/v1/automations/state",
        headers=_auth_headers_for(user),
    )
    assert r.status_code == 200
    body = r.json()
    assert body["vehicle_id"] == VIN

    entries = {e["entity"]: e for e in body["entries"]}
    assert set(entries.keys()) == {
        "vehicle.climate.keeper_mode",
        "vehicle.locked",
    }
    assert entries["vehicle.climate.keeper_mode"]["value"] == 3
    assert entries["vehicle.locked"]["value"] is False
    # ISO 8601 round-trips fine through json.
    assert entries["vehicle.climate.keeper_mode"]["since"].startswith(
        "2026-05-08T07:56:05"
    )


async def test_state_endpoint_handles_orphan_since_without_value(client, db_session):
    """A `since` row without its sibling `value` row is still surfaced
    — old data from before the value-tracking change."""
    user, _ = await _make_user_and_vehicle(db_session)

    db_session.add(AutomationState(
        user_id=user.id, vehicle_id=VIN,
        key="tel:vehicle.sentry_mode_on:since",
        value=datetime(2026, 5, 8, 7, 0, 0, tzinfo=timezone.utc).isoformat(),
    ))
    await db_session.commit()

    r = await client.get(
        "/api/v1/automations/state",
        headers=_auth_headers_for(user),
    )
    assert r.status_code == 200
    entries = r.json()["entries"]
    assert len(entries) == 1
    assert entries[0]["entity"] == "vehicle.sentry_mode_on"
    assert entries[0]["value"] is None


async def test_state_endpoint_only_returns_callers_data(client, db_session):
    """Multi-tenancy gate: user A's tel:* rows must not leak to user B."""
    user_a, _ = await _make_user_and_vehicle(db_session)
    user_b = User(email="b@t.com", password_hash="x", is_active=True)
    db_session.add(user_b)
    await db_session.flush()
    db_session.add(Vehicle(
        user_id=user_b.id, vehicle_id="99",
        vin="LRWYAAAAA00000099",
        display_name="OtherCar",
    ))
    db_session.add_all([
        AutomationState(
            user_id=user_a.id, vehicle_id=VIN,
            key="tel:vehicle.locked:since",
            value="2026-05-08T08:15:53+00:00",
        ),
        AutomationState(
            user_id=user_a.id, vehicle_id=VIN,
            key="tel:vehicle.locked:value",
            value="false",
        ),
    ])
    await db_session.commit()

    r = await client.get(
        "/api/v1/automations/state",
        headers=_auth_headers_for(user_b),
    )
    assert r.status_code == 200
    body = r.json()
    assert body["vehicle_id"] == "LRWYAAAAA00000099"
    assert body["entries"] == []
