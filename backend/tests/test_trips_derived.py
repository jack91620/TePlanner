"""Trip response derived fields — distance, ETA, projected SOC.

Pins the math + the "hide gracefully when inputs missing" contract.
The cron monitor fills last_position_*, last_speed_kmh,
last_battery_level_pct each tick; the API endpoint derives the
display fields from those + the current target stop's coords.
"""

import json
from datetime import datetime
from types import SimpleNamespace

from app.api.v1 import trips as trips_api
from app.db.models import ActiveTrip


def _trip(**kw) -> ActiveTrip:
    stops = kw.pop("stops", [
        {"latitude": 31.23, "longitude": 121.47, "kind": "charging",
         "name": "A"},
        {"latitude": 31.30, "longitude": 121.50, "kind": "final",
         "name": "终点"},
    ])
    base = ActiveTrip(
        id=1,
        user_id=1,
        vehicle_id="tesla_42",
        stops_json=json.dumps(stops, ensure_ascii=False),
        current_segment=0,
        status="active",
        replan_count=0,
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
    )
    for k, v in kw.items():
        setattr(base, k, v)
    return base


def test_compute_derived_returns_none_without_position():
    """Cold trip — no last_position_* yet → all derived fields None."""
    trip = _trip()
    d, eta, soc = trips_api._compute_derived(trip, json.loads(trip.stops_json))
    assert d is None
    assert eta is None
    assert soc is None


def test_compute_derived_distance_only_when_no_speed_or_soc():
    """Have position but no speed / SOC → distance set, others None."""
    trip = _trip(
        last_position_lat=31.20, last_position_lng=121.47,
    )
    d, eta, soc = trips_api._compute_derived(trip, json.loads(trip.stops_json))
    # ~3.3 km north → × 1.15 ≈ 3.8 km
    assert d is not None and 3.0 < d < 5.0
    assert eta is None  # no speed
    assert soc is None  # no battery


def test_compute_derived_eta_hidden_below_min_speed():
    """Speed < 5 km/h (parking lot / red light) → no ETA."""
    trip = _trip(
        last_position_lat=31.20, last_position_lng=121.47,
        last_speed_kmh=2.0,
    )
    d, eta, soc = trips_api._compute_derived(trip, json.loads(trip.stops_json))
    assert d is not None
    assert eta is None


def test_compute_derived_full_math():
    """Distance + ETA + projected SOC all populated correctly."""
    # Place car 80 km south of the target (so haversine roughly 80 km).
    # Target stop: (31.23, 121.47). Car at (30.51, 121.47) → ~80 km
    # along latitude. Speed 80 km/h → ~1 h ETA. 50% SOC → drops by
    # ~22% on the 80-km × 1.15 road km → projected ≈ 28%.
    trip = _trip(
        last_position_lat=30.51, last_position_lng=121.47,
        last_speed_kmh=80.0,
        last_battery_level_pct=50,
    )
    d, eta, soc = trips_api._compute_derived(trip, json.loads(trip.stops_json))
    assert 88 < d < 100      # ~80 km × 1.15
    # 92 km @ 80 km/h ≈ 4140 seconds; tolerate +/- 600s for
    # rounding + haversine vs road-factor variance.
    assert eta is not None and 3500 < eta < 5000
    # 92 km × 0.18 / 75 × 100 ≈ 22% drop → ~28%.
    assert soc is not None and 24 < soc < 32


def test_compute_derived_no_target_when_segment_out_of_range():
    """current_segment = -1 (trip not yet started) or past end → None."""
    trip = _trip(current_segment=-1,
                 last_position_lat=31.20, last_position_lng=121.47)
    assert trips_api._compute_derived(trip, json.loads(trip.stops_json)) == (None, None, None)

    trip2 = _trip(current_segment=99,
                  last_position_lat=31.20, last_position_lng=121.47)
    assert trips_api._compute_derived(trip2, json.loads(trip2.stops_json)) == (None, None, None)


def test_row_to_response_surfaces_derived_in_payload():
    """Confirm the wire shape includes the new fields."""
    trip = _trip(
        last_position_lat=30.51, last_position_lng=121.47,
        last_speed_kmh=80.0,
        last_battery_level_pct=50,
    )
    resp = trips_api._row_to_response(trip)
    assert resp.next_stop_distance_km is not None
    assert resp.next_stop_eta_seconds is not None
    assert resp.next_stop_projected_soc_pct is not None
    assert resp.last_speed_kmh == 80.0
    assert resp.last_battery_level_pct == 50
