"""Phase 11.x — vehicle_config prefetch (post-OAuth background fetch).

These tests cover the persist side of the prefetch — given a Tesla
`/vehicle_data?endpoints=vehicle_config` response, are the right
columns written to the vehicles row? The wake/poll/HTTP plumbing is
tested via integration (manual smoke) rather than mocked here.
"""

from datetime import datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.services.vehicle_config_prefetch import _fetch_one


def _vehicle(**kw) -> SimpleNamespace:
    return SimpleNamespace(
        vehicle_id=kw.get("vehicle_id", "tesla_42"),
        car_type=kw.get("car_type"),
        roof_color=kw.get("roof_color"),
        motorized_charge_port=kw.get("motorized_charge_port"),
        config_fetched_at=kw.get("config_fetched_at"),
    )


@pytest.mark.asyncio
async def test_fetch_one_persists_all_fields_when_present():
    """Happy path — Tesla returns the full block, we write all three
    capability-relevant fields + set config_fetched_at."""
    client = AsyncMock()
    client.wake_up = AsyncMock()
    client.get_vehicle = AsyncMock(
        return_value={"response": {"state": "online"}}
    )
    client.get_vehicle_data = AsyncMock(
        return_value={"response": {"vehicle_config": {
            "car_type": "modely",
            "roof_color": "Glass",
            "motorized_charge_port": True,
        }}}
    )
    vehicle = _vehicle()
    db = MagicMock()

    # Bypass wake-poll timing — patch _wake_until_online by direct call
    # path so the test takes ~0s.
    from app.services import vehicle_config_prefetch as svc
    svc._WAKE_POLL_SECONDS = 0.001  # noqa: SLF001 (test-only override)
    svc._WAKE_TIMEOUT_SECONDS = 0.05  # noqa: SLF001

    await _fetch_one(client, db, vehicle)

    assert vehicle.car_type == "modely"
    assert vehicle.roof_color == "Glass"
    assert vehicle.motorized_charge_port is True
    assert isinstance(vehicle.config_fetched_at, datetime)


@pytest.mark.asyncio
async def test_fetch_one_skips_when_wake_fails():
    """If wake_up never reaches online, leave the row untouched so the
    user's next /state call gets a fresh shot."""
    client = AsyncMock()
    client.wake_up = AsyncMock()
    # get_vehicle always returns asleep — wake timeout fires.
    client.get_vehicle = AsyncMock(
        return_value={"response": {"state": "asleep"}}
    )
    client.get_vehicle_data = AsyncMock()
    vehicle = _vehicle()

    from app.services import vehicle_config_prefetch as svc
    svc._WAKE_POLL_SECONDS = 0.001
    svc._WAKE_TIMEOUT_SECONDS = 0.05  # exit immediately

    await _fetch_one(client, MagicMock(), vehicle)

    # vehicle_data is never called when wake fails.
    client.get_vehicle_data.assert_not_called()
    assert vehicle.config_fetched_at is None
    assert vehicle.car_type is None


@pytest.mark.asyncio
async def test_fetch_one_motorized_port_false_persists():
    """Older trim with non-motorized port — `False` must not be
    confused with absent and dropped."""
    client = AsyncMock()
    client.wake_up = AsyncMock()
    client.get_vehicle = AsyncMock(
        return_value={"response": {"state": "online"}}
    )
    client.get_vehicle_data = AsyncMock(
        return_value={"response": {"vehicle_config": {
            "motorized_charge_port": False,
        }}}
    )
    vehicle = _vehicle()

    from app.services import vehicle_config_prefetch as svc
    svc._WAKE_POLL_SECONDS = 0.0
    svc._WAKE_TIMEOUT_SECONDS = 1.0

    await _fetch_one(client, MagicMock(), vehicle)

    assert vehicle.motorized_charge_port is False
    assert isinstance(vehicle.config_fetched_at, datetime)


@pytest.mark.asyncio
async def test_fetch_one_partial_block_preserves_existing():
    """Tesla sometimes returns only some sub-fields. Merge field-by-
    field so a partial response doesn't clobber a previous cache."""
    client = AsyncMock()
    client.wake_up = AsyncMock()
    client.get_vehicle = AsyncMock(
        return_value={"response": {"state": "online"}}
    )
    client.get_vehicle_data = AsyncMock(
        return_value={"response": {"vehicle_config": {
            "roof_color": "Sunroof",  # only this field returned
        }}}
    )
    vehicle = _vehicle(
        car_type="modely",
        roof_color="Glass",
        motorized_charge_port=True,
    )

    from app.services import vehicle_config_prefetch as svc
    svc._WAKE_POLL_SECONDS = 0.0
    svc._WAKE_TIMEOUT_SECONDS = 1.0

    await _fetch_one(client, MagicMock(), vehicle)

    # New roof_color wins; the rest of the cached values stay.
    assert vehicle.roof_color == "Sunroof"
    assert vehicle.car_type == "modely"
    assert vehicle.motorized_charge_port is True
