"""Phase 8 geofence trigger tests.

The trigger fires on edge transitions (enter / exit) of a circular
region around (lat, lng) with `radius_m`. Tests pin:
  * Inside / outside detection via haversine.
  * Edge-only firing (no fire when continuously inside).
  * 60s debounce against position jitter near the boundary.
  * Missing location data → silent skip.
"""

from datetime import datetime, timedelta, timezone

import pytest

from app.services.automation.base import (
    AlertKind,
    AlertSeverity,
    AutomationContext,
    AutomationSettings,
    InMemoryStateMemory,
    VehicleStateSnapshot,
)
from app.services.automation.interpreters import (
    _haversine_meters,
    evaluate_rule,
)


HOME = (39.9000, 116.4000)  # somewhere in Beijing — exact value irrelevant
NEAR_HOME = (39.9001, 116.4001)  # ~14m away
FAR_FROM_HOME = (39.9100, 116.4100)  # ~1.4 km away


def _ctx(state, *, now=None, memory=None):
    return AutomationContext(
        vehicle_state=state,
        vehicle_id="abc",
        now=now or datetime(2026, 5, 8, 12, 0, 0, tzinfo=timezone.utc),
        settings=AutomationSettings(),
        memory=memory or InMemoryStateMemory(),
    )


def _enter_home_spec():
    return {
        "kind": AlertKind.GEOFENCE_ENTER.value,
        "trigger": {
            "type": "geofence",
            "lat": HOME[0], "lng": HOME[1],
            "radius_m": 200,
            "event": "enter",
            "state_key": "geo:home",
        },
        "actions": [{
            "type": "notify",
            "title": "已抵家",
            "body": "距离 {distance_m} 米",
            "severity": "info",
        }],
    }


def _at(lat, lng):
    return VehicleStateSnapshot(latitude=lat, longitude=lng)


def test_haversine_meters_zero_for_same_point():
    assert _haversine_meters(*HOME, *HOME) == pytest.approx(0, abs=0.1)


def test_haversine_meters_known_distance():
    # ~14m, accept ±2m tolerance.
    d = _haversine_meters(*HOME, *NEAR_HOME)
    assert 10 < d < 20


def test_geofence_does_not_fire_when_far_from_center():
    state = _at(*FAR_FROM_HOME)
    assert evaluate_rule(_enter_home_spec(), _ctx(state)) is None


def test_geofence_fires_on_first_entry():
    state = _at(*HOME)
    alert = evaluate_rule(_enter_home_spec(), _ctx(state))
    assert alert is not None
    assert alert.kind == AlertKind.GEOFENCE_ENTER
    assert alert.severity == AlertSeverity.INFO
    assert alert.title == "已抵家"
    assert "距离 0 米" in alert.detail


def test_geofence_does_not_double_fire_while_inside():
    """Continuous evaluation while inside the fence must produce only
    one alert. Otherwise we'd spam push notifications every tick."""
    memory = InMemoryStateMemory()
    state = _at(*HOME)
    t0 = datetime(2026, 5, 8, 12, 0, 0, tzinfo=timezone.utc)
    a1 = evaluate_rule(_enter_home_spec(), _ctx(state, now=t0, memory=memory))
    assert a1 is not None
    a2 = evaluate_rule(_enter_home_spec(), _ctx(state, now=t0 + timedelta(seconds=1), memory=memory))
    assert a2 is None  # same memory + still inside → no re-fire


def test_geofence_re_fires_after_exit_and_re_entry():
    memory = InMemoryStateMemory()
    spec = _enter_home_spec()
    t0 = datetime(2026, 5, 8, 12, 0, 0, tzinfo=timezone.utc)

    # Enter
    a1 = evaluate_rule(spec, _ctx(_at(*HOME), now=t0, memory=memory))
    assert a1 is not None

    # Drive far away — no fire (this is enter-event only).
    t1 = t0 + timedelta(minutes=10)
    a2 = evaluate_rule(spec, _ctx(_at(*FAR_FROM_HOME), now=t1, memory=memory))
    assert a2 is None

    # Re-enter — fires again (debounce window has elapsed).
    t2 = t1 + timedelta(minutes=5)
    a3 = evaluate_rule(spec, _ctx(_at(*HOME), now=t2, memory=memory))
    assert a3 is not None


def test_geofence_60s_debounce_squashes_jitter():
    """Position jitter near the boundary can flip inside/outside
    repeatedly. The 60s debounce must squash the second fire so we
    don't spam pushes."""
    memory = InMemoryStateMemory()
    spec = _enter_home_spec()
    t0 = datetime(2026, 5, 8, 12, 0, 0, tzinfo=timezone.utc)

    # Enter (fires)
    assert evaluate_rule(spec, _ctx(_at(*HOME), now=t0, memory=memory)) is not None
    # Brief flap outside
    t1 = t0 + timedelta(seconds=10)
    evaluate_rule(spec, _ctx(_at(*FAR_FROM_HOME), now=t1, memory=memory))
    # Re-enter 20s later — within debounce window, should NOT fire.
    t2 = t0 + timedelta(seconds=30)
    assert evaluate_rule(spec, _ctx(_at(*HOME), now=t2, memory=memory)) is None


def test_geofence_exit_event():
    memory = InMemoryStateMemory()
    spec = {
        "kind": AlertKind.GEOFENCE_EXIT.value,
        "trigger": {
            "type": "geofence",
            "lat": HOME[0], "lng": HOME[1],
            "radius_m": 200,
            "event": "exit",
            "state_key": "geo:home",
        },
        "actions": [{
            "type": "notify",
            "title": "离家",
            "body": "Drive safely",
            "severity": "info",
        }],
    }
    t0 = datetime(2026, 5, 8, 12, 0, 0, tzinfo=timezone.utc)

    # First eval inside → no fire (exit event), but baseline recorded.
    assert evaluate_rule(spec, _ctx(_at(*HOME), now=t0, memory=memory)) is None
    # Move outside → fires.
    t1 = t0 + timedelta(minutes=5)
    a = evaluate_rule(spec, _ctx(_at(*FAR_FROM_HOME), now=t1, memory=memory))
    assert a is not None
    assert a.kind == AlertKind.GEOFENCE_EXIT


def test_geofence_skipped_when_location_missing():
    """No telemetry fix yet → no fire (and no crash)."""
    state = VehicleStateSnapshot()  # no lat/lng
    assert evaluate_rule(_enter_home_spec(), _ctx(state)) is None
