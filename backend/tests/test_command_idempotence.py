"""Command idempotence guard.

Pins the rule: if Tesla telemetry already shows the car at the target
state declared by a capability's ``expected_state(params)``, the
dispatcher skips the Fleet API call entirely. Prevents collisions with
Tesla 车机 Routines (which may already be steering toward the same
state) and with our own cron-driven re-fires.

Only covers capabilities that declare ``expected_state`` — others
(preheat, navigation, set_charge_limit today) always dispatch because
we have no observable telemetry to compare against.
"""

from __future__ import annotations

import json
from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.db.models import AutomationState, User, Vehicle
from app.services.capabilities import get as get_capability
from app.services.vehicle_commands import (
    _already_at_target,
    _values_equal,
    invoke_capability,
)

VIN = "VINIDEMPO01"


async def _user(db_session) -> User:
    u = User(email="idem@test.local", password_hash="x", is_active=True)
    db_session.add(u)
    await db_session.flush()
    db_session.add(Vehicle(user_id=u.id, vehicle_id="42", vin=VIN, display_name="T"))
    await db_session.commit()
    return u


def _value_row(user_id: int, entity: str, value: object) -> AutomationState:
    return AutomationState(
        user_id=user_id, vehicle_id=VIN,
        key=f"tel:{entity}:value",
        value=json.dumps(value),
    )


# ----------------------------- _values_equal -----------------------------

def test_values_equal_bool_strict():
    assert _values_equal(True, True)
    assert _values_equal(False, False)
    assert not _values_equal(True, False)
    # Don't let 1/0 sneak into a bool comparison.
    assert not _values_equal(1, True)
    assert not _values_equal(0, False)


def test_values_equal_numeric_normalizes():
    assert _values_equal(3, 3)
    assert _values_equal(3.0, 3)
    assert _values_equal(80, 80.0)
    assert not _values_equal(3, 4)


def test_values_equal_string_exact():
    assert _values_equal("Charging", "Charging")
    assert not _values_equal("charging", "Charging")


# --------------------------- _already_at_target --------------------------

@pytest.mark.asyncio
async def test_already_at_target_returns_match_when_telemetry_aligns(db_session):
    user = await _user(db_session)
    db_session.add(_value_row(user.id, "vehicle.sentry_mode_on", True))
    await db_session.commit()
    cap = get_capability("tesla.security.set_sentry")
    out = await _already_at_target(db_session, user.id, VIN, cap, {"on": True})
    assert out is not None
    assert out["target"] == {"vehicle.sentry_mode_on": True}
    assert out["current"] == {"vehicle.sentry_mode_on": True}


@pytest.mark.asyncio
async def test_already_at_target_returns_none_when_mismatch(db_session):
    user = await _user(db_session)
    db_session.add(_value_row(user.id, "vehicle.sentry_mode_on", False))
    await db_session.commit()
    cap = get_capability("tesla.security.set_sentry")
    out = await _already_at_target(db_session, user.id, VIN, cap, {"on": True})
    assert out is None


@pytest.mark.asyncio
async def test_already_at_target_returns_none_when_telemetry_missing(db_session):
    """No telemetry row → _read_value returns None → we cannot prove
    the car is already at target, so dispatch must proceed."""
    user = await _user(db_session)
    cap = get_capability("tesla.security.set_sentry")
    out = await _already_at_target(db_session, user.id, VIN, cap, {"on": True})
    assert out is None


@pytest.mark.asyncio
async def test_already_at_target_returns_none_for_empty_expected_state(db_session):
    """preheat / navigation don't declare expected_state — guard
    cannot engage and dispatch must proceed."""
    user = await _user(db_session)
    cap = get_capability("tesla.climate.preheat")
    out = await _already_at_target(db_session, user.id, VIN, cap, {})
    assert out is None


@pytest.mark.asyncio
async def test_already_at_target_skips_when_keeper_mode_matches(db_session):
    user = await _user(db_session)
    db_session.add(_value_row(user.id, "vehicle.climate.keeper_mode", 3))
    await db_session.commit()
    cap = get_capability("tesla.climate.set_keeper_mode")
    out = await _already_at_target(db_session, user.id, VIN, cap, {"mode": 3})
    assert out is not None
    assert out["current"]["vehicle.climate.keeper_mode"] == 3


@pytest.mark.asyncio
async def test_already_at_target_skips_when_charge_limit_matches(db_session):
    """Highest-collision case with Tesla 车机 Routines: both systems
    aim charge_limit_pct at the same daily target. Guard must engage."""
    user = await _user(db_session)
    db_session.add(_value_row(user.id, "vehicle.charge_limit_pct", 80))
    await db_session.commit()
    cap = get_capability("tesla.charging.set_limit")
    out = await _already_at_target(db_session, user.id, VIN, cap, {"percent": 80})
    assert out is not None
    assert out["current"]["vehicle.charge_limit_pct"] == 80
    assert out["target"]["vehicle.charge_limit_pct"] == 80


@pytest.mark.asyncio
async def test_already_at_target_charge_limit_mismatch_dispatches(db_session):
    user = await _user(db_session)
    db_session.add(_value_row(user.id, "vehicle.charge_limit_pct", 70))
    await db_session.commit()
    cap = get_capability("tesla.charging.set_limit")
    out = await _already_at_target(db_session, user.id, VIN, cap, {"percent": 80})
    assert out is None  # mismatch → must dispatch


def test_set_charge_limit_expected_state_validates_bounds():
    """Out-of-range percent → empty expected_state so the regular
    validation error path in `invoke` runs and the user gets a 400."""
    cap = get_capability("tesla.charging.set_limit")
    assert cap.expected_state({"percent": 80}) == {"vehicle.charge_limit_pct": 80}
    assert cap.expected_state({"percent": 49}) == {}
    assert cap.expected_state({"percent": 101}) == {}
    assert cap.expected_state({}) == {}
    assert cap.expected_state({"percent": "80"}) == {}


# ---------------------- invoke_capability skip path ----------------------

class _FakeTeslaClient:
    """No-op async context manager. invoke_capability never actually
    calls into it when the idempotence guard triggers."""
    async def __aenter__(self):
        return self
    async def __aexit__(self, *_):
        return False


@pytest.mark.asyncio
async def test_invoke_capability_skips_dispatch_when_at_target(db_session, monkeypatch):
    """End-to-end: invoke_capability returns ``skipped=True`` without
    calling Tesla and without writing a CommandPending row."""
    user = await _user(db_session)
    db_session.add(_value_row(user.id, "vehicle.sentry_mode_on", True))
    await db_session.commit()

    # If dispatch ran, this would crash — confirms we short-circuit.
    from app.services import vehicle_commands as vc
    sentinel = AsyncMock(side_effect=AssertionError("dispatch should not run"))
    monkeypatch.setattr(vc, "capability_dispatch", sentinel)
    write_pending_sentinel = AsyncMock(side_effect=AssertionError(
        "write_pending should not run"))
    monkeypatch.setattr(vc, "write_pending", write_pending_sentinel)

    result = await invoke_capability(
        capability_id="tesla.security.set_sentry",
        vehicle_id="42",
        params={"on": True},
        user=user,
        tesla_client=_FakeTeslaClient(),
        db=db_session,
    )
    assert result["success"] is True
    assert result["skipped"] is True
    assert result["reason"] == "already_at_target"
    assert result["target"] == {"vehicle.sentry_mode_on": True}
    sentinel.assert_not_called()
    write_pending_sentinel.assert_not_called()


@pytest.mark.asyncio
async def test_invoke_capability_dispatches_when_state_diverges(db_session, monkeypatch):
    """Target ≠ current → dispatch must run."""
    user = await _user(db_session)
    db_session.add(_value_row(user.id, "vehicle.sentry_mode_on", False))
    await db_session.commit()

    from app.services import vehicle_commands as vc
    from app.services.capabilities.base import CapabilityResult

    dispatch_mock = AsyncMock(return_value=CapabilityResult(success=True, data={}))
    monkeypatch.setattr(vc, "capability_dispatch", dispatch_mock)
    monkeypatch.setattr(vc, "write_pending", AsyncMock(return_value=None))
    # Connectivity unknown → falls through to dispatch.
    monkeypatch.setattr(vc, "connectivity_state", AsyncMock(return_value="UNKNOWN"))

    result = await invoke_capability(
        capability_id="tesla.security.set_sentry",
        vehicle_id="42",
        params={"on": True},
        user=user,
        tesla_client=_FakeTeslaClient(),
        db=db_session,
    )
    assert result["success"] is True
    assert "skipped" not in result
    dispatch_mock.assert_awaited_once()
