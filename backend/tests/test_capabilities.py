"""Smoke tests for the capability registry.

Phase 10.1: validates registration, lookup, and dispatch error paths.
Doesn't hit Tesla — capabilities are tested with a mock TeslaClient.
"""

from __future__ import annotations

from unittest.mock import AsyncMock

import pytest

from app.services.capabilities import (
    all_capabilities,
    dispatch,
    get,
)
from app.services.capabilities.base import (
    CapabilityCallContext,
    SafetyClass,
)


# Importing the package above triggers tesla/* self-registration.
# Now assert each expected capability is present.

EXPECTED_CAPABILITIES = {
    "tesla.climate.set_keeper_mode": SafetyClass.WRITABLE,
    "tesla.climate.preheat": SafetyClass.WRITABLE,
    "tesla.security.set_sentry": SafetyClass.SECURITY,
    "tesla.charging.set_limit": SafetyClass.WRITABLE,
    "tesla.navigation.send": SafetyClass.WRITABLE,
}


def test_registry_has_expected_capabilities():
    ids = {c.id for c in all_capabilities()}
    for expected_id in EXPECTED_CAPABILITIES:
        assert expected_id in ids, f"missing {expected_id}"


def test_registry_safety_classes_match():
    for cap_id, expected_class in EXPECTED_CAPABILITIES.items():
        cap = get(cap_id)
        assert cap is not None
        assert cap.safety_class == expected_class


def test_describe_serializes_cleanly():
    for cap in all_capabilities():
        d = cap.describe()
        assert d["id"] == cap.id
        assert d["brand"] in ("tesla",)
        assert d["safety_class"] in {s.value for s in SafetyClass}
        assert isinstance(d["params_schema"], dict)


@pytest.mark.asyncio
async def test_dispatch_unknown_returns_failure():
    ctx = CapabilityCallContext(
        vehicle_id="123", vin=None, tesla_client=None, user_id=1
    )
    result = await dispatch("not.a.real.capability", ctx, {})
    assert not result.success
    assert "Unknown capability" in (result.error or "")


@pytest.mark.asyncio
async def test_dispatch_set_climate_keeper_mode_validates_params():
    """Bad params should fail in-band as CapabilityResult, not raise."""
    ctx = CapabilityCallContext(
        vehicle_id="123", vin="VIN0001", tesla_client=AsyncMock(), user_id=1
    )
    result = await dispatch(
        "tesla.climate.set_keeper_mode", ctx, {"mode": 99}
    )
    assert not result.success
    assert "0..3" in (result.error or "")


@pytest.mark.asyncio
async def test_dispatch_set_climate_keeper_mode_calls_client():
    fake_client = AsyncMock()
    ctx = CapabilityCallContext(
        vehicle_id="123", vin="VIN0001", tesla_client=fake_client, user_id=1
    )
    result = await dispatch(
        "tesla.climate.set_keeper_mode", ctx, {"mode": 0}
    )
    assert result.success
    assert result.data == {"mode": 0}
    fake_client.set_climate_keeper_mode.assert_awaited_once_with("VIN0001", 0)


@pytest.mark.asyncio
async def test_dispatch_set_charge_limit_range_check():
    ctx = CapabilityCallContext(
        vehicle_id="123", vin="VIN0001", tesla_client=AsyncMock(), user_id=1
    )
    bad = await dispatch(
        "tesla.charging.set_limit", ctx, {"percent": 30}
    )
    assert not bad.success

    good = await dispatch(
        "tesla.charging.set_limit", ctx, {"percent": 70}
    )
    assert good.success


@pytest.mark.asyncio
async def test_dispatch_navigation_uses_vehicle_id_not_vin():
    fake_client = AsyncMock()
    ctx = CapabilityCallContext(
        vehicle_id="numeric_id_123", vin=None,
        tesla_client=fake_client, user_id=1,
    )
    result = await dispatch(
        "tesla.navigation.send",
        ctx,
        {"latitude": 39.9, "longitude": 116.4},
    )
    assert result.success
    fake_client.navigation_gps_request.assert_awaited_once_with(
        vehicle_tag="numeric_id_123", lat=39.9, lon=116.4, order=1
    )
