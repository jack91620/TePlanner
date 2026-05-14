"""Active-trip auto-advance — pin the arrival-detection heuristics
and the no-op paths. Tesla nav is mocked end-to-end (TeslaClient +
push) so these tests run in-memory without touching the network.
"""

import json
from datetime import datetime, timedelta
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
async def test_soc_warning_fires_when_no_replan_available():
    """Phase 3a fallback: SOC unsafe + no reachable charger → warn."""
    trip = _trip_with_stops(_stops_a_to_b(), current_segment=0)
    # Car ~78 km north of A — well outside arrival radius — only 15% SOC.
    snap = VehicleStateSnapshot(
        latitude=A_LAT + 0.7, longitude=A_LNG,
        battery_level=15, charging_state="Disconnected",
        speed_kmh=80.0,
    )
    db = MagicMock()
    db.execute = AsyncMock(return_value=MagicMock(
        scalar_one_or_none=MagicMock(return_value=None),
    ))

    from app.services import active_trip_service as svc
    with patch.object(svc, "get_active_trip", AsyncMock(return_value=trip)), \
         patch.object(monitor, "_try_soc_auto_replan", AsyncMock(return_value=None)), \
         patch.object(monitor, "_push_soc_warning", AsyncMock()) as push_fn:
        await monitor.monitor_active_trip(db, user_id=1, snap=snap)

    push_fn.assert_awaited_once()
    assert trip.last_soc_warning_at is not None


@pytest.mark.asyncio
async def test_soc_warning_debounced():
    """Second tick within the debounce window — no re-push."""
    trip = _trip_with_stops(_stops_a_to_b(), current_segment=0)
    trip.last_soc_warning_at = datetime.utcnow()
    snap = VehicleStateSnapshot(
        latitude=A_LAT + 0.7, longitude=A_LNG,
        battery_level=15, charging_state="Disconnected",
    )
    db = MagicMock()
    db.execute = AsyncMock(return_value=MagicMock(
        scalar_one_or_none=MagicMock(return_value=None),
    ))

    from app.services import active_trip_service as svc
    with patch.object(svc, "get_active_trip", AsyncMock(return_value=trip)), \
         patch.object(monitor, "_push_soc_warning", AsyncMock()) as push_fn:
        await monitor.monitor_active_trip(db, user_id=1, snap=snap)

    push_fn.assert_not_awaited()


@pytest.mark.asyncio
async def test_soc_warning_not_fired_when_soc_sufficient():
    """Healthy SOC → no warning."""
    trip = _trip_with_stops(_stops_a_to_b(), current_segment=0)
    snap = VehicleStateSnapshot(
        latitude=A_LAT + 0.7, longitude=A_LNG,
        battery_level=80, charging_state="Disconnected",
    )
    db = MagicMock()
    db.execute = AsyncMock(return_value=MagicMock(
        scalar_one_or_none=MagicMock(return_value=None),
    ))

    from app.services import active_trip_service as svc
    with patch.object(svc, "get_active_trip", AsyncMock(return_value=trip)), \
         patch.object(monitor, "_push_soc_warning", AsyncMock()) as push_fn:
        await monitor.monitor_active_trip(db, user_id=1, snap=snap)

    push_fn.assert_not_awaited()
    assert trip.last_soc_warning_at is None


def test_project_arrival_soc_math():
    # 80 km × 0.18 kWh/km = 14.4 kWh ÷ 75 kWh = 19.2% drop
    # 50 - 19.2 ≈ 30.8
    projected = monitor._project_arrival_soc(50, 80)
    assert 30 < projected < 32


def test_project_arrival_soc_below_zero_possible():
    # Pessimistic projection can dip below 0 — caller decides what to
    # do with it. We don't clamp here.
    projected = monitor._project_arrival_soc(10, 200)
    assert projected < 0


# ---- phase 4 — off-route detection --------------------------------


def test_point_to_segment_on_segment_is_near_zero():
    # Point exactly between A and B → distance ~0.
    d = monitor._point_to_segment_m(
        31.235, 121.4737,    # P
        31.230, 121.4737,    # A
        31.240, 121.4737,    # B (straight north of A)
    )
    assert d < 50


def test_point_to_segment_perpendicular_offset():
    # Shift P ~0.005° east of a north-running segment at lat 31.
    # 0.005° lng at lat 31 ≈ 475 m.
    d = monitor._point_to_segment_m(
        31.235, 121.479,
        31.230, 121.4737,
        31.240, 121.4737,
    )
    assert 400 < d < 600


def test_min_distance_to_polyline_empty_returns_inf():
    assert monitor._min_distance_to_polyline_m(31.0, 121.0, []) == float("inf")
    assert monitor._min_distance_to_polyline_m(
        31.0, 121.0, [[31.0, 121.0]]
    ) == float("inf")


def test_min_distance_to_polyline_finds_closest_segment():
    polyline = [[31.0, 121.0], [31.05, 121.0], [31.1, 121.0]]
    d = monitor._min_distance_to_polyline_m(31.05, 121.01, polyline)
    # 0.01° lng at lat 31 ≈ 950 m
    assert 800 < d < 1100


@pytest.mark.asyncio
async def test_off_route_first_tick_sets_marker_no_push():
    """First tick off-route → record timestamp, don't push yet."""
    trip = _trip_with_stops(_stops_a_to_b(), current_segment=0)
    trip.polyline_json = json.dumps([[A_LAT, A_LNG], [B_LAT, B_LNG]])
    # A→B runs east. Move car ~3.3 km north of the line.
    snap = VehicleStateSnapshot(
        latitude=A_LAT + 0.03, longitude=A_LNG,
        battery_level=80,
    )
    db = MagicMock()
    db.execute = AsyncMock(return_value=MagicMock(
        scalar_one_or_none=MagicMock(return_value=None),
    ))

    from app.services import active_trip_service as svc
    with patch.object(svc, "get_active_trip", AsyncMock(return_value=trip)), \
         patch.object(monitor, "_push_off_route", AsyncMock()) as push_fn:
        await monitor.monitor_active_trip(db, user_id=1, snap=snap)

    assert trip.off_route_since is not None
    push_fn.assert_not_awaited()


@pytest.mark.asyncio
async def test_off_route_sustained_fires_warning():
    """Off-route for > sustain window → push fires."""
    trip = _trip_with_stops(_stops_a_to_b(), current_segment=0)
    trip.polyline_json = json.dumps([[A_LAT, A_LNG], [B_LAT, B_LNG]])
    trip.off_route_since = datetime.utcnow() - timedelta(seconds=120)
    snap = VehicleStateSnapshot(
        latitude=A_LAT + 0.03, longitude=A_LNG,
        battery_level=80,
    )
    db = MagicMock()
    db.execute = AsyncMock(return_value=MagicMock(
        scalar_one_or_none=MagicMock(return_value=None),
    ))

    from app.services import active_trip_service as svc
    with patch.object(svc, "get_active_trip", AsyncMock(return_value=trip)), \
         patch.object(monitor, "_push_off_route", AsyncMock()) as push_fn:
        await monitor.monitor_active_trip(db, user_id=1, snap=snap)

    push_fn.assert_awaited_once()
    assert trip.last_off_route_warning_at is not None


@pytest.mark.asyncio
async def test_off_route_returning_clears_marker():
    """Car comes back to polyline → off_route_since reset to None."""
    trip = _trip_with_stops(_stops_a_to_b(), current_segment=0)
    trip.polyline_json = json.dumps([[A_LAT, A_LNG], [B_LAT, B_LNG]])
    trip.off_route_since = datetime.utcnow() - timedelta(seconds=200)
    # Snap onto the polyline.
    snap = VehicleStateSnapshot(
        latitude=A_LAT, longitude=A_LNG + 0.005,
        battery_level=80,
    )
    db = MagicMock()
    db.execute = AsyncMock(return_value=MagicMock(
        scalar_one_or_none=MagicMock(return_value=None),
    ))

    from app.services import active_trip_service as svc
    with patch.object(svc, "get_active_trip", AsyncMock(return_value=trip)), \
         patch.object(monitor, "_push_off_route", AsyncMock()) as push_fn:
        await monitor.monitor_active_trip(db, user_id=1, snap=snap)

    assert trip.off_route_since is None
    push_fn.assert_not_awaited()


@pytest.mark.asyncio
async def test_off_route_no_polyline_skips_check():
    """Trip without polyline_json (legacy) → don't crash, don't fire."""
    trip = _trip_with_stops(_stops_a_to_b(), current_segment=0)
    trip.polyline_json = None
    snap = VehicleStateSnapshot(
        latitude=A_LAT + 1.0, longitude=A_LNG + 1.0,  # very far
        battery_level=80,
    )
    db = MagicMock()
    db.execute = AsyncMock(return_value=MagicMock(
        scalar_one_or_none=MagicMock(return_value=None),
    ))

    from app.services import active_trip_service as svc
    with patch.object(svc, "get_active_trip", AsyncMock(return_value=trip)), \
         patch.object(monitor, "_push_off_route", AsyncMock()) as push_fn:
        await monitor.monitor_active_trip(db, user_id=1, snap=snap)

    assert trip.off_route_since is None
    push_fn.assert_not_awaited()


@pytest.mark.asyncio
async def test_off_route_debounced_within_window():
    """Already warned recently → don't re-push even if still off-route."""
    trip = _trip_with_stops(_stops_a_to_b(), current_segment=0)
    trip.polyline_json = json.dumps([[A_LAT, A_LNG], [B_LAT, B_LNG]])
    trip.off_route_since = datetime.utcnow() - timedelta(seconds=200)
    trip.last_off_route_warning_at = datetime.utcnow() - timedelta(seconds=10)
    snap = VehicleStateSnapshot(
        latitude=A_LAT + 0.03, longitude=A_LNG,
        battery_level=80,
    )
    db = MagicMock()
    db.execute = AsyncMock(return_value=MagicMock(
        scalar_one_or_none=MagicMock(return_value=None),
    ))

    from app.services import active_trip_service as svc
    with patch.object(svc, "get_active_trip", AsyncMock(return_value=trip)), \
         patch.object(monitor, "_push_off_route", AsyncMock()) as push_fn:
        await monitor.monitor_active_trip(db, user_id=1, snap=snap)

    push_fn.assert_not_awaited()


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


# ---- phase 3b — SOC auto-replan -----------------------------------


def test_reachable_radius_math():
    # 30% SOC, 75 kWh, 0.18 kWh/km, 5% safety reserve →
    # usable = 25% → 18.75 kWh → 104.16 km
    r = monitor._reachable_radius_km(
        current_soc_pct=30, capacity_kwh=75.0,
    )
    assert 100 < r < 108


def test_reachable_radius_zero_when_below_reserve():
    # 3% < 5% reserve → 0 km reachable.
    r = monitor._reachable_radius_km(
        current_soc_pct=3, capacity_kwh=75.0,
    )
    assert r == 0


@pytest.mark.asyncio
async def test_replan_picks_closest_reachable_amap_candidate():
    """When AMap returns several candidates, pick the closest that's
    within the reachable radius. Skip ones too far away."""
    trip = _trip_with_stops(_stops_a_to_b(), current_segment=0)
    trip.stops_json = json.dumps([
        {"latitude": A_LAT, "longitude": A_LNG, "name": "原桩",
         "kind": "charging", "station_id": "ORIG"},
        {"latitude": B_LAT, "longitude": B_LNG, "name": "终点",
         "kind": "final"},
    ], ensure_ascii=False)
    snap = VehicleStateSnapshot(
        latitude=31.235, longitude=121.4737,  # near A
        battery_level=20,
    )
    fake_token = SimpleNamespace(access_token="t")
    db = MagicMock()
    db.execute = AsyncMock(return_value=MagicMock(
        scalar_one_or_none=MagicMock(return_value=fake_token),
    ))

    # Fake AMap returns three candidates at varying distances.
    fake_candidates = [
        # Use GCJ-02-ish coords; gcj02_to_wgs84 will round-trip back
        # close enough. For test simplicity use raw lat/lng — the
        # converter is no-op outside China bbox.
        {"id": "FAR", "title": "远站", "address": "远",
         "location": {"lat": 30.5, "lng": 122.0}},  # very far
        {"id": "NEAR1", "title": "最近站", "address": "近",
         "location": {"lat": 31.236, "lng": 121.475}},  # ~200 m
        {"id": "NEAR2", "title": "稍远", "address": "稍远",
         "location": {"lat": 31.245, "lng": 121.475}},  # ~1.2 km
    ]

    class _FakeAmap:
        def __init__(self, *a, **kw): pass
        async def __aenter__(self): return self
        async def __aexit__(self, *exc): return False
        async def search_charging_stations(self, **kw):
            return fake_candidates

    class _FakeClient:
        def __init__(self, *a, **kw): pass
        async def __aenter__(self): return self
        async def __aexit__(self, *exc): return False
        async def navigation_request(self, **kw): pass

    sent_indices: list[int] = []
    sent_reasons: list[str] = []

    async def _fake_send(client, trip_obj, stop_index, reason=None):
        sent_indices.append(stop_index)
        sent_reasons.append(reason or "")
        trip_obj.current_segment = stop_index

    from app.services import active_trip_service as svc
    from app.integrations.amap import web_client as amap_web
    with patch.object(amap_web, "AmapWebClient", _FakeAmap), \
         patch.object(monitor, "TeslaClient", _FakeClient), \
         patch.object(svc, "send_stop_to_vehicle", AsyncMock(side_effect=_fake_send)):
        result = await monitor._try_soc_auto_replan(
            db=db, user_id=1, trip=trip, snap=snap, capacity_kwh=75.0,
        )

    assert result is not None
    # Closest viable candidate was NEAR1.
    assert result["station_id"] == "NEAR1"
    # Stops were rewritten: [new, final].
    stops = json.loads(trip.stops_json)
    assert len(stops) == 2
    assert stops[0]["station_id"] == "NEAR1"
    assert stops[1]["kind"] == "final"
    # Replan counter bumped and reason recorded.
    assert trip.replan_count == 1
    assert trip.last_replan_reason == "电耗高于预期"
    # New stop pushed to Tesla at the new charger index (0 here, since
    # cur_idx=0 means we replaced from the very first slot).
    assert sent_indices == [0]
    assert sent_reasons == ["电耗高于预期"]


@pytest.mark.asyncio
async def test_replan_returns_none_when_no_amap_candidate_reachable():
    """All AMap results outside reachable radius → no replan."""
    trip = _trip_with_stops(_stops_a_to_b(), current_segment=0)
    snap = VehicleStateSnapshot(
        latitude=A_LAT, longitude=A_LNG, battery_level=20,
    )
    db = MagicMock()
    db.execute = AsyncMock(return_value=MagicMock(
        scalar_one_or_none=MagicMock(return_value=None),
    ))

    class _FakeAmap:
        def __init__(self, *a, **kw): pass
        async def __aenter__(self): return self
        async def __aexit__(self, *exc): return False
        async def search_charging_stations(self, **kw):
            # All candidates 200 km away — beyond reachable radius.
            return [{"id": "FAR", "title": "远",
                     "location": {"lat": A_LAT + 2.0, "lng": A_LNG}}]

    from app.services import active_trip_service as svc
    from app.integrations.amap import web_client as amap_web
    with patch.object(amap_web, "AmapWebClient", _FakeAmap):
        result = await monitor._try_soc_auto_replan(
            db=db, user_id=1, trip=trip, snap=snap, capacity_kwh=75.0,
        )

    assert result is None
    assert trip.replan_count == 0


@pytest.mark.asyncio
async def test_replan_skips_when_current_stop_is_final():
    """SOC won't reach final destination → replan can't help."""
    trip = _trip_with_stops([
        {"latitude": A_LAT, "longitude": A_LNG, "kind": "final"},
    ], current_segment=0)
    snap = VehicleStateSnapshot(
        latitude=A_LAT + 0.1, longitude=A_LNG, battery_level=10,
    )
    db = MagicMock()

    result = await monitor._try_soc_auto_replan(
        db=db, user_id=1, trip=trip, snap=snap, capacity_kwh=75.0,
    )
    assert result is None
    assert trip.replan_count == 0


# ---- phase 4b — off-route auto re-send ----------------------------


@pytest.mark.asyncio
async def test_off_route_sustained_resends_current_stop():
    """When off-route fires, re-send the current next stop to Tesla
    so the car re-plans from new position. Push reflects the resend."""
    trip = _trip_with_stops(_stops_a_to_b(), current_segment=0)
    trip.polyline_json = json.dumps([[A_LAT, A_LNG], [B_LAT, B_LNG]])
    trip.off_route_since = datetime.utcnow() - timedelta(seconds=120)
    snap = VehicleStateSnapshot(
        latitude=A_LAT + 0.03, longitude=A_LNG,
        battery_level=80,
    )
    fake_token = SimpleNamespace(access_token="t")
    db = MagicMock()
    db.execute = AsyncMock(return_value=MagicMock(
        scalar_one_or_none=MagicMock(return_value=fake_token),
    ))

    sent_indices: list[int] = []
    sent_reasons: list[str] = []

    class _FakeClient:
        def __init__(self, *a, **kw): pass
        async def __aenter__(self): return self
        async def __aexit__(self, *exc): return False
        async def navigation_request(self, **kw): pass

    async def _fake_send(client, trip_obj, stop_index, reason=None):
        sent_indices.append(stop_index)
        sent_reasons.append(reason or "")

    from app.services import active_trip_service as svc
    with patch.object(svc, "get_active_trip", AsyncMock(return_value=trip)), \
         patch.object(monitor, "_check_soc_sufficiency", AsyncMock()), \
         patch.object(monitor, "TeslaClient", _FakeClient), \
         patch.object(svc, "send_stop_to_vehicle", AsyncMock(side_effect=_fake_send)), \
         patch.object(monitor, "_push_off_route", AsyncMock()) as push_fn:
        await monitor.monitor_active_trip(db, user_id=1, snap=snap)

    assert sent_indices == [0]
    assert sent_reasons == ["偏离原线路"]
    push_fn.assert_awaited_once()
    # Push was told that we DID resend.
    kwargs = push_fn.await_args.kwargs
    assert kwargs.get("resent") is True


@pytest.mark.asyncio
async def test_off_route_sustained_no_token_pushes_resent_false():
    """Sustained off-route but no TeslaToken → push but mark resent=False
    so the body falls back to the manual-replan copy."""
    trip = _trip_with_stops(_stops_a_to_b(), current_segment=0)
    trip.polyline_json = json.dumps([[A_LAT, A_LNG], [B_LAT, B_LNG]])
    trip.off_route_since = datetime.utcnow() - timedelta(seconds=120)
    snap = VehicleStateSnapshot(
        latitude=A_LAT + 0.03, longitude=A_LNG, battery_level=80,
    )
    db = MagicMock()
    db.execute = AsyncMock(return_value=MagicMock(
        scalar_one_or_none=MagicMock(return_value=None),
    ))

    from app.services import active_trip_service as svc
    with patch.object(svc, "get_active_trip", AsyncMock(return_value=trip)), \
         patch.object(monitor, "_push_off_route", AsyncMock()) as push_fn:
        await monitor.monitor_active_trip(db, user_id=1, snap=snap)

    push_fn.assert_awaited_once()
    kwargs = push_fn.await_args.kwargs
    assert kwargs.get("resent") is False


@pytest.mark.asyncio
async def test_soc_unsafe_triggers_replan_then_push_replanned():
    """End-to-end: monitor detects unsafe SOC + replan succeeds →
    we push the 'replanned' notification, NOT the warning one."""
    trip = _trip_with_stops(_stops_a_to_b(), current_segment=0)
    snap = VehicleStateSnapshot(
        latitude=A_LAT + 0.7, longitude=A_LNG,  # far from current target
        battery_level=15, charging_state="Disconnected",
    )
    db = MagicMock()
    db.execute = AsyncMock(return_value=MagicMock(
        scalar_one_or_none=MagicMock(return_value=None),
    ))

    fake_new_stop = {"name": "新桩", "kind": "charging"}

    from app.services import active_trip_service as svc
    with patch.object(svc, "get_active_trip", AsyncMock(return_value=trip)), \
         patch.object(monitor, "_try_soc_auto_replan",
                      AsyncMock(return_value=fake_new_stop)), \
         patch.object(monitor, "_push_soc_replanned", AsyncMock()) as push_replanned, \
         patch.object(monitor, "_push_soc_warning", AsyncMock()) as push_warning:
        await monitor.monitor_active_trip(db, user_id=1, snap=snap)

    push_replanned.assert_awaited_once()
    push_warning.assert_not_awaited()
