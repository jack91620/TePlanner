"""Phase 11.x — comfort capabilities (seat heat, steering wheel,
media volume / play).

Pin the param schema validation + dispatch contract. Real Tesla
calls are mocked so no actual VCP hits during unit tests.
"""

from unittest.mock import AsyncMock

import pytest

from app.services.capabilities import all_capabilities, dispatch, get
from app.services.capabilities.base import CapabilityCallContext


def _ctx(client) -> CapabilityCallContext:
    return CapabilityCallContext(
        vehicle_id="42", vin="LRWYGCFS0NC517553",
        tesla_client=client, user_id=1,
    )


async def test_seat_heater_dispatches_to_tesla_client():
    client = AsyncMock()
    cap = get("tesla.comfort.set_seat_heater")
    assert cap is not None
    result = await cap.invoke(_ctx(client), {"seat": 0, "level": 2})
    assert result.success is True
    client.remote_seat_heater_request.assert_awaited_once_with(
        "LRWYGCFS0NC517553", 0, 2,
    )


async def test_seat_heater_rejects_invalid_seat():
    client = AsyncMock()
    cap = get("tesla.comfort.set_seat_heater")
    result = await cap.invoke(_ctx(client), {"seat": 99, "level": 1})
    assert result.success is False


async def test_seat_heater_rejects_invalid_level():
    client = AsyncMock()
    cap = get("tesla.comfort.set_seat_heater")
    result = await cap.invoke(_ctx(client), {"seat": 0, "level": 5})
    assert result.success is False


async def test_steering_wheel_heater_dispatches():
    client = AsyncMock()
    cap = get("tesla.comfort.set_steering_wheel_heater")
    result = await cap.invoke(_ctx(client), {"on": True})
    assert result.success is True
    client.remote_steering_wheel_heater_request.assert_awaited_once_with(
        "LRWYGCFS0NC517553", True,
    )


async def test_media_toggle_dispatches():
    client = AsyncMock()
    cap = get("tesla.media.toggle_playback")
    result = await cap.invoke(_ctx(client), {})
    assert result.success is True
    client.media_toggle_playback.assert_awaited_once_with("LRWYGCFS0NC517553")


async def test_set_volume_clamps_invalid_input():
    client = AsyncMock()
    cap = get("tesla.media.set_volume")
    result = await cap.invoke(_ctx(client), {"volume": 99})
    assert result.success is False
    client.adjust_volume.assert_not_awaited()


async def test_set_volume_dispatches_valid():
    client = AsyncMock()
    cap = get("tesla.media.set_volume")
    result = await cap.invoke(_ctx(client), {"volume": 5.5})
    assert result.success is True
    client.adjust_volume.assert_awaited_once_with("LRWYGCFS0NC517553", 5.5)


async def test_capabilities_listed_in_registry():
    """Every comfort capability self-registers on import — check
    they show up in the registry so the iOS visual builder picks
    them up automatically."""
    ids = {c.id for c in all_capabilities()}
    for expected in [
        "tesla.comfort.set_seat_heater",
        "tesla.comfort.set_steering_wheel_heater",
        "tesla.media.toggle_playback",
        "tesla.media.set_volume",
    ]:
        assert expected in ids, f"missing capability {expected}"
