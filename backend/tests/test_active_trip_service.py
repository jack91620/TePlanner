"""Active trip orchestration — pin the merge semantics for advance /
replan / final-stop completion. The Tesla nav send is mocked; we
care about the row mutations + which stop_index gets pushed.
"""

import json
from datetime import datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.db.models import ActiveTrip
from app.services import active_trip_service as svc


def _trip(stops, segment=-1, **kw) -> ActiveTrip:
    return ActiveTrip(
        id=1,
        user_id=1,
        vehicle_id="tesla_42",
        stops_json=json.dumps(stops, ensure_ascii=False),
        current_segment=segment,
        status="active",
        replan_count=0,
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
        **kw,
    )


def test_decode_and_current_stop_track_segment():
    stops = [
        {"latitude": 31.2, "longitude": 121.4, "kind": "charging", "name": "A"},
        {"latitude": 32.0, "longitude": 121.0, "kind": "final", "name": "终点"},
    ]
    trip = _trip(stops, segment=0)
    assert svc.decode_stops(trip) == stops
    assert svc.current_stop(trip)["name"] == "A"

    trip.current_segment = 1
    assert svc.current_stop(trip)["name"] == "终点"

    trip.current_segment = -1
    assert svc.current_stop(trip) is None


def test_advance_index_returns_next_or_none_at_end():
    stops = [
        {"latitude": 0.0, "longitude": 0.0, "kind": "charging"},
        {"latitude": 1.0, "longitude": 1.0, "kind": "final"},
    ]
    trip = _trip(stops, segment=-1)
    assert svc.advance_index(trip) == 0

    trip.current_segment = 0
    assert svc.advance_index(trip) == 1

    trip.current_segment = 1
    assert svc.advance_index(trip) is None


def test_is_final_stop_matches_last_index():
    stops = [
        {"latitude": 0.0, "longitude": 0.0, "kind": "charging"},
        {"latitude": 1.0, "longitude": 1.0, "kind": "final"},
    ]
    trip = _trip(stops, segment=0)
    assert not svc.is_final_stop(trip)
    trip.current_segment = 1
    assert svc.is_final_stop(trip)


def test_stop_display_address_no_reason_uses_bare_address():
    stop = {"address": "上海市浦东新区张江路 123 号", "name": "A 桩"}
    assert svc.stop_display_address(stop, None) == "上海市浦东新区张江路 123 号"


def test_stop_display_address_with_reason_prepends_bracket():
    """Tesla car screen truncates ~40 chars — keep reason short."""
    stop = {"address": "上海市浦东新区张江路 123 号", "name": "A"}
    addr = svc.stop_display_address(stop, "原桩满")
    assert addr.startswith("[原桩满] ")
    assert "上海市浦东新区" in addr


def test_stop_display_address_truncates_long_reason():
    """Reasons longer than 8 chars get an ellipsis so we don't eat
    the whole address line."""
    stop = {"address": "目的地"}
    addr = svc.stop_display_address(stop, "电耗超出预期需要切换至更近站")
    # 8-char cap → 7 chars + …
    assert addr.startswith("[电耗超出预期需…] ")


def test_stop_display_address_falls_back_to_name_when_no_address():
    stop = {"name": "凯德 MALL 充电站", "address": None}
    assert svc.stop_display_address(stop, None) == "凯德 MALL 充电站"


@pytest.mark.asyncio
async def test_send_stop_pushes_address_and_advances_segment():
    """send_stop_to_vehicle should call Tesla's navigation_request with
    the formatted address AND mutate trip.current_segment."""
    stops = [
        {"address": "A 充电站", "kind": "charging"},
        {"address": "终点", "kind": "final"},
    ]
    trip = _trip(stops, segment=-1)
    client = AsyncMock()
    client.navigation_request = AsyncMock()

    await svc.send_stop_to_vehicle(client, trip, stop_index=0)

    assert trip.current_segment == 0
    client.navigation_request.assert_awaited_once()
    kwargs = client.navigation_request.call_args.kwargs
    assert kwargs["vehicle_tag"] == "tesla_42"
    assert kwargs["address"] == "A 充电站"
    assert kwargs["locale"] == "zh-CN"


@pytest.mark.asyncio
async def test_send_stop_with_reason_prepends_bracket_to_address():
    stops = [
        {"address": "B 充电站", "kind": "charging"},
        {"address": "终点", "kind": "final"},
    ]
    trip = _trip(stops, segment=0)
    client = AsyncMock()
    client.navigation_request = AsyncMock()

    await svc.send_stop_to_vehicle(
        client, trip, stop_index=1, reason="A 桩位已满",
    )

    assert trip.current_segment == 1
    assert trip.last_replan_reason == "A 桩位已满"
    addr = client.navigation_request.call_args.kwargs["address"]
    assert addr.startswith("[A 桩位已满] ") or addr.startswith("[A 桩位已…] ")
    assert "终点" in addr


@pytest.mark.asyncio
async def test_send_stop_out_of_range_raises():
    stops = [{"address": "终点", "kind": "final"}]
    trip = _trip(stops, segment=-1)
    client = AsyncMock()

    with pytest.raises(ValueError):
        await svc.send_stop_to_vehicle(client, trip, stop_index=5)
    with pytest.raises(ValueError):
        await svc.send_stop_to_vehicle(client, trip, stop_index=-1)
