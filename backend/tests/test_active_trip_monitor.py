"""Active-trip auto-advance — pin the arrival-detection heuristics
and the no-op paths. Tesla nav is mocked end-to-end (TeslaClient +
push) so these tests run in-memory without touching the network.
"""

import json
from datetime import datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.db.models import ActiveTrip
from app.services import active_trip_monitor as monitor
from app.services.automation.base import VehicleStateSnapshot


def _trip_with_stops(stops, current_segment=0) -> ActiveTrip:
    return ActiveTrip(
        id=1,
        user_id=1,
        vehicle_id="tesla_42",
        stops_json=json.dumps(stops, ensure_ascii=False),
        current_segment=current_segment,
        status="active",
        replan_count=0,
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
    )


# Coordinates: A → B ~9 km apart in Shanghai.
A_LAT, A_LNG = 31.2304, 121.4737
B_LAT, B_LNG = 31.2304, 121.5737  # ~10 km east


def _stops_a_to_b():
    return [
        {"latitude": A_LAT, "longitude": A_LNG, "name": "A 充电站",
         "kind": "charging"},
        {"latitude": B_LAT, "longitude": B_LNG, "name": "终点",
         "kind": "final"},
    ]


def test_haversine_known_distance():
    """Sanity: 1° longitude at lat=31 ≈ 95 km."""
    d = monitor._haversine_m(31.0, 121.0, 31.0, 122.0)
    assert 94000 < d < 96000


def test_arrival_charging_state_charging_short_circuits():
    """Charging stop: charging_state="Charging" is enough — even a
    big distance still counts as arrival (covers GPS lag at the
    moment the car plugs in)."""
    stop = {"latitude": A_LAT, "longitude": A_LNG, "kind": "charging"}
    snap = VehicleStateSnapshot(
        latitude=A_LAT + 0.005, longitude=A_LNG,  # ~550 m away
        charging_state="Charging",
    )
    assert monitor._has_arrived(snap, stop, is_final=False)


def test_arrival_no_charging_geometry_threshold():
    """Without charging_state, charging-stop arrival uses 300 m radius."""
    stop = {"latitude": A_LAT, "longitude": A_LNG, "kind": "charging"}
    near = VehicleStateSnapshot(
        latitude=A_LAT + 0.001, longitude=A_LNG,  # ~110 m
        charging_state=None,
    )
    assert monitor._has_arrived(near, stop, is_final=False)
    far = VehicleStateSnapshot(
        latitude=A_LAT + 0.01, longitude=A_LNG,  # ~1.1 km
        charging_state=None,
    )
    assert not monitor._has_arrived(far, stop, is_final=False)


def test_arrival_charging_state_disconnected_blocks():
    """Negative signal: disconnected explicitly rules out arrival
    even at very close range (car drove past without plugging in)."""
    stop = {"latitude": A_LAT, "longitude": A_LNG, "kind": "charging"}
    snap = VehicleStateSnapshot(
        latitude=A_LAT + 0.0005, longitude=A_LNG,  # ~55 m
        charging_state="Disconnected",
    )
    assert not monitor._has_arrived(snap, stop, is_final=False)


def test_arrival_final_stop_geometry_and_speed():
    """Final stop: in-radius AND speed<=5 km/h."""
    stop = {"latitude": B_LAT, "longitude": B_LNG, "kind": "final"}
    arrived = VehicleStateSnapshot(
        latitude=B_LAT + 0.0005, longitude=B_LNG,  # ~55 m
        speed_kmh=2.0,
    )
    assert monitor._has_arrived(arrived, stop, is_final=True)

    moving = VehicleStateSnapshot(
        latitude=B_LAT + 0.0005, longitude=B_LNG,
        speed_kmh=30.0,
    )
    assert not monitor._has_arrived(moving, stop, is_final=True)

    too_far = VehicleStateSnapshot(
        latitude=B_LAT + 0.005, longitude=B_LNG,  # ~550 m
        speed_kmh=0.0,
    )
    assert not monitor._has_arrived(too_far, stop, is_final=True)


def test_arrival_no_telemetry_no_advance():
    """Missing lat/lng (cold cache, asleep car) → never claim arrival."""
    stop = {"latitude": A_LAT, "longitude": A_LNG, "kind": "charging"}
    snap = VehicleStateSnapshot()
    assert not monitor._has_arrived(snap, stop, is_final=False)


@pytest.mark.asyncio
async def test_monitor_noop_when_no_trip():
    """No active trip → don't touch anything."""
    from app.services import active_trip_service as svc
    with patch.object(svc, "get_active_trip", AsyncMock(return_value=None)):
        snap = VehicleStateSnapshot(latitude=A_LAT, longitude=A_LNG)
        # Should be a no-op (no exceptions, no DB writes).
        await monitor.monitor_active_trip(MagicMock(), user_id=1, snap=snap)


@pytest.mark.asyncio
async def test_monitor_records_last_position_without_arrival():
    """Even when not arriving, last_position_* is updated so the
    iOS Hub card can show distance + ETA later."""
    trip = _trip_with_stops(_stops_a_to_b(), current_segment=0)

    from app.services import active_trip_service as svc
    snap = VehicleStateSnapshot(
        latitude=31.0, longitude=121.0,  # nowhere near A or B
        charging_state="Disconnected",
    )
    with patch.object(svc, "get_active_trip", AsyncMock(return_value=trip)):
        await monitor.monitor_active_trip(MagicMock(), user_id=1, snap=snap)

    assert trip.last_position_lat == pytest.approx(31.0)
    assert trip.last_position_lng == pytest.approx(121.0)
    assert trip.current_segment == 0  # not advanced


@pytest.mark.asyncio
async def test_monitor_completes_trip_on_final_arrival():
    """Reaching the final destination flips status to completed."""
    trip = _trip_with_stops(_stops_a_to_b(), current_segment=1)
    snap = VehicleStateSnapshot(
        latitude=B_LAT, longitude=B_LNG, speed_kmh=0.0,
    )

    from app.services import active_trip_service as svc
    with patch.object(svc, "get_active_trip", AsyncMock(return_value=trip)), \
         patch.object(monitor, "_push_completed", AsyncMock()) as push_fn:
        await monitor.monitor_active_trip(MagicMock(), user_id=1, snap=snap)

    assert trip.status == "completed"
    push_fn.assert_awaited_once()


@pytest.mark.asyncio
async def test_monitor_advances_on_charging_arrival():
    """Charging at the current stop → send next stop to car + push."""
    trip = _trip_with_stops(_stops_a_to_b(), current_segment=0)
    snap = VehicleStateSnapshot(
        latitude=A_LAT, longitude=A_LNG,
        charging_state="Charging",
    )
    fake_token = SimpleNamespace(access_token="tok")
    db = MagicMock()
    db.execute = AsyncMock(return_value=MagicMock(
        scalar_one_or_none=MagicMock(return_value=fake_token),
    ))

    sent_indices: list[int] = []

    class _FakeClient:
        def __init__(self, *a, **kw): pass
        async def __aenter__(self): return self
        async def __aexit__(self, *exc): return False
        async def navigation_request(self, **kw): pass

    async def _fake_send(client, trip_obj, stop_index, reason=None):
        sent_indices.append(stop_index)
        trip_obj.current_segment = stop_index

    from app.services import active_trip_service as svc
    with patch.object(svc, "get_active_trip", AsyncMock(return_value=trip)), \
         patch.object(svc, "send_stop_to_vehicle", AsyncMock(side_effect=_fake_send)), \
         patch.object(monitor, "TeslaClient", _FakeClient), \
         patch.object(monitor, "_push_advanced", AsyncMock()) as push_fn:
        await monitor.monitor_active_trip(db, user_id=1, snap=snap)

    assert sent_indices == [1]
    assert trip.current_segment == 1
    push_fn.assert_awaited_once()


@pytest.mark.asyncio
async def test_monitor_no_advance_when_token_missing():
    """No TeslaToken on file → don't crash, don't advance."""
    trip = _trip_with_stops(_stops_a_to_b(), current_segment=0)
    snap = VehicleStateSnapshot(
        latitude=A_LAT, longitude=A_LNG,
        charging_state="Charging",
    )
    db = MagicMock()
    db.execute = AsyncMock(return_value=MagicMock(
        scalar_one_or_none=MagicMock(return_value=None),
    ))

    from app.services import active_trip_service as svc
    with patch.object(svc, "get_active_trip", AsyncMock(return_value=trip)):
        await monitor.monitor_active_trip(db, user_id=1, snap=snap)

    # current_segment unchanged.
    assert trip.current_segment == 0
