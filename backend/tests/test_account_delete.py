"""DELETE /api/v1/user/me — App Store 5.1.1(v) account deletion.

Pins the contract that calling the endpoint:
  1. Wipes every row tied to user_id across the schema, including
     vehicle-scoped child tables (CommandPending, CommandQueue, ...).
  2. Wipes Share.owner_user_id and OAuthState.user_id (non-standard FK
     column names).
  3. Drops the User row itself.
  4. Returns 204.

We invoke the handler directly rather than through the HTTP client
because the AsyncClient fixture is currently broken under the project's
httpx version (separate fix). Direct invocation also makes assertions
more surgical than `assert response.status_code == 204`.
"""

from __future__ import annotations

import json
from datetime import datetime, timedelta

import pytest
from sqlalchemy import select

from app.api.v1.user import delete_account
from app.db.models import (
    ActiveTrip,
    AutomationRule,
    AutomationSnooze,
    AutomationState,
    ChargingSession,
    CommandPending,
    CommandQueue,
    DeviceToken,
    OAuthState,
    PendingWait,
    PushedAlert,
    RoutePlan,
    ScheduledDeparture,
    Share,
    TeslaToken,
    User,
    UserSetting,
    Vehicle,
)


VIN = "VINDELETE01"


async def _make_user(db_session, email: str = "del@t.com") -> User:
    u = User(email=email, password_hash="x", is_active=True)
    db_session.add(u)
    await db_session.commit()
    return u


def _seed_full_user(db_session, user_id: int) -> dict[str, int]:
    """Insert one row per FK-bearing table for `user_id`. Returns
    {table_name: rowcount_inserted} so the assertion side can sanity-
    check the seed before claiming a successful delete."""
    seeded = {}

    now = datetime.utcnow()

    db_session.add(TeslaToken(
        user_id=user_id, access_token="at", refresh_token="rt",
        expires_at=now + timedelta(hours=8),
    ))
    seeded["tesla_tokens"] = 1

    db_session.add(Vehicle(
        user_id=user_id, vehicle_id="42", vin=VIN, display_name="T",
    ))
    seeded["vehicles"] = 1

    db_session.add(AutomationRule(
        id=f"rule-{user_id}",
        user_id=user_id, preset_id="camp_mode_overstay",
        name="露营模式过夜", enabled=True,
        spec_json=json.dumps({"trigger": {}, "actions": []}),
    ))
    seeded["automation_rules"] = 1

    db_session.add(UserSetting(
        user_id=user_id, key="ui.daily_charge_limit_soc",
        value_json=json.dumps(80),
    ))
    seeded["user_setting"] = 1

    db_session.add(ChargingSession(
        user_id=user_id, vehicle_id=VIN, started_at=now,
        start_soc=20, source="manual",
    ))
    seeded["charging_session"] = 1

    db_session.add(ScheduledDeparture(
        user_id=user_id, vehicle_id=VIN,
        departure_at_utc=now + timedelta(hours=12),
        lead_minutes=15, enabled=True, created_at=now,
    ))
    seeded["scheduled_departure"] = 1

    db_session.add(ActiveTrip(
        user_id=user_id, vehicle_id=VIN,
        stops_json=json.dumps([
            {"latitude": 31.23, "longitude": 121.47, "kind": "final"},
        ]),
        current_segment=-1, status="active",
        replan_count=0, created_at=now, updated_at=now,
    ))
    seeded["active_trip"] = 1

    db_session.add(AutomationSnooze(
        user_id=user_id, rule_id=f"rule-{user_id}",
        snoozed_until_utc=now + timedelta(hours=1),
    ))
    seeded["automation_snooze"] = 1

    db_session.add(AutomationState(
        user_id=user_id, vehicle_id=VIN,
        key="tel:vehicle.battery_level:value",
        value=json.dumps(72),
    ))
    seeded["automation_state"] = 1

    db_session.add(PushedAlert(
        user_id=user_id, vehicle_id=VIN,
        kind="campMode", pushed_at=now,
    ))
    seeded["pushed_alerts"] = 1

    db_session.add(DeviceToken(
        user_id=user_id, platform="apns", token="dt-token",
    ))
    seeded["device_tokens"] = 1

    db_session.add(PendingWait(
        user_id=user_id, vehicle_id=VIN, rule_id="rwait",
        predicate_json="{}", then_action_json="{}",
        deadline_at=now + timedelta(minutes=5),
    ))
    seeded["pending_wait"] = 1

    db_session.add(CommandQueue(
        user_id=user_id, vehicle_id=VIN, capability="tesla.security.set_sentry",
        params_json="{}", dispatch_policy="queue",
    ))
    seeded["command_queue"] = 1

    db_session.add(CommandPending(
        user_id=user_id, vehicle_id=VIN,
        capability="tesla.security.set_sentry",
        expected_state_json="{}",
    ))
    seeded["command_pending"] = 1

    db_session.add(RoutePlan(
        user_id=user_id,
        origin_lat=31.20, origin_lng=121.40,
        dest_lat=31.30, dest_lng=121.50,
        total_distance_km=30, total_duration_minutes=20,
    ))
    seeded["route_plans"] = 1

    db_session.add(Share(
        owner_user_id=user_id, share_type="rule",
        payload_json="{}",
        code=f"SHARE{user_id:01d}",
        created_at=now, expires_at=now + timedelta(days=30),
    ))
    seeded["shares"] = 1

    db_session.add(OAuthState(
        state=f"state-{user_id}", user_id=user_id, code_verifier="cv",
        created_at=now,
    ))
    seeded["oauth_states"] = 1

    return seeded


async def _count(db_session, model, *predicates) -> int:
    """Convenience — COUNT(*) on a model with optional WHERE clauses."""
    stmt = select(model)
    for p in predicates:
        stmt = stmt.where(p)
    rows = (await db_session.execute(stmt)).scalars().all()
    return len(rows)


@pytest.mark.asyncio
async def test_delete_account_wipes_every_fk_table(db_session):
    user = await _make_user(db_session, "wipe@t.com")
    other = await _make_user(db_session, "keep@t.com")

    _seed_full_user(db_session, user.id)
    # Also seed the "other" user so the test catches a global wipe bug
    # (the deletion must only touch the requesting user).
    _seed_full_user(db_session, other.id)
    await db_session.commit()

    # Sanity — both users have data.
    assert await _count(db_session, User) == 2
    assert await _count(db_session, Vehicle) == 2
    assert await _count(db_session, TeslaToken) == 2

    # Direct invocation: the handler closes the transaction with
    # db.commit() inside, so we just await it.
    response = await delete_account(user=user, db=db_session)
    assert response.status_code == 204

    # Target user gone everywhere.
    for model in (
        TeslaToken, Vehicle, AutomationRule, UserSetting,
        ChargingSession, ScheduledDeparture, ActiveTrip,
        AutomationSnooze, AutomationState, PushedAlert,
        DeviceToken, PendingWait, CommandQueue, CommandPending,
        RoutePlan,
    ):
        remaining = await _count(db_session, model, model.user_id == user.id)
        assert remaining == 0, f"{model.__tablename__} still has rows for deleted user"

    assert await _count(db_session, Share, Share.owner_user_id == user.id) == 0
    assert await _count(db_session, OAuthState, OAuthState.user_id == user.id) == 0
    assert await _count(db_session, User, User.id == user.id) == 0

    # The other user must be intact — global wipe is the worst-case bug.
    assert await _count(db_session, User, User.id == other.id) == 1
    assert await _count(db_session, TeslaToken, TeslaToken.user_id == other.id) == 1
    assert await _count(db_session, Vehicle, Vehicle.user_id == other.id) == 1
    assert await _count(db_session, Share, Share.owner_user_id == other.id) == 1


@pytest.mark.asyncio
async def test_delete_account_no_child_rows_is_idempotent(db_session):
    """A freshly-created user with no automations / vehicles / etc.
    must still delete cleanly. Edge case for users who OAuth'd, never
    paired a car, then asked to delete."""
    user = await _make_user(db_session, "fresh@t.com")
    response = await delete_account(user=user, db=db_session)
    assert response.status_code == 204
    assert await _count(db_session, User, User.id == user.id) == 0