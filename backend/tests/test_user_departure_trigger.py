"""user_departure trigger — fires once per departure event when a
predicate evaluates true against the current sticky snapshot.
"""

from datetime import datetime, timezone

import pytest

from app.services.automation.base import (
    AlertKind,
    AlertSeverity,
    AutomationContext,
    AutomationSettings,
    InMemoryStateMemory,
    VehicleStateSnapshot,
)
from app.services.automation.interpreters import evaluate_rule
from app.services.automation.presets import (
    LEAVE_WITHOUT_SENTRY,
    LEFT_UNLOCKED,
    WINDOW_OR_BOX_LEFT_OPEN,
)


def _ctx(state, *, departure_at=None, last_eval=None, last_eval_key=None):
    memory = InMemoryStateMemory()
    if departure_at is not None:
        memory.set("event:user_departure:at", departure_at)
    if last_eval is not None and last_eval_key is not None:
        memory.set(last_eval_key, last_eval)
    return AutomationContext(
        vehicle_state=state,
        vehicle_id="abc",
        now=datetime(2026, 5, 11, 12, 0, 0, tzinfo=timezone.utc),
        settings=AutomationSettings(),
        memory=memory,
    )


# ---------- LEFT_UNLOCKED ----------

def test_left_unlocked_fires_on_first_departure_with_unlocked_state():
    state = VehicleStateSnapshot(locked=False, shift_state="P")
    ctx = _ctx(state, departure_at=datetime(2026, 5, 11, 11, 30))
    alert = evaluate_rule(LEFT_UNLOCKED.spec, ctx)
    assert alert is not None
    assert alert.kind == AlertKind.LEFT_UNLOCKED
    assert alert.severity == AlertSeverity.CRITICAL
    assert "锁车" in (alert.primary_action_label or "")


def test_left_unlocked_no_fire_when_locked():
    """If the user already locked, the predicate fails — no alert."""
    state = VehicleStateSnapshot(locked=True, shift_state="P")
    ctx = _ctx(state, departure_at=datetime(2026, 5, 11, 11, 30))
    assert evaluate_rule(LEFT_UNLOCKED.spec, ctx) is None


def test_left_unlocked_idempotent_within_same_departure():
    """Two cron ticks for the same departure event should fire once."""
    state = VehicleStateSnapshot(locked=False, shift_state="P")
    departure_at = datetime(2026, 5, 11, 11, 30)
    ctx = _ctx(state, departure_at=departure_at)
    first = evaluate_rule(LEFT_UNLOCKED.spec, ctx)
    assert first is not None
    # Second eval with the same memory state
    second = evaluate_rule(LEFT_UNLOCKED.spec, ctx)
    assert second is None  # last_eval was set on first eval


def test_left_unlocked_refires_on_new_departure():
    """User comes back, drives off, parks again, still unlocked → fire again."""
    state = VehicleStateSnapshot(locked=False, shift_state="P")
    ctx = _ctx(
        state,
        departure_at=datetime(2026, 5, 11, 12, 30),    # newer than last_eval
        last_eval=datetime(2026, 5, 11, 11, 30),
        last_eval_key="leftUnlocked:lastEval",
    )
    assert evaluate_rule(LEFT_UNLOCKED.spec, ctx) is not None


def test_left_unlocked_no_fire_when_no_departure_recorded():
    state = VehicleStateSnapshot(locked=False, shift_state="P")
    ctx = _ctx(state)  # no departure_at
    assert evaluate_rule(LEFT_UNLOCKED.spec, ctx) is None


# ---------- WINDOW_OR_BOX_LEFT_OPEN ----------

def test_window_open_fires_on_departure():
    state = VehicleStateSnapshot(window_open=True, shift_state="P")
    ctx = _ctx(state, departure_at=datetime(2026, 5, 11, 11, 30))
    alert = evaluate_rule(WINDOW_OR_BOX_LEFT_OPEN.spec, ctx)
    assert alert is not None
    assert "车窗" in alert.title


def test_window_closed_no_fire():
    state = VehicleStateSnapshot(window_open=False, shift_state="P")
    ctx = _ctx(state, departure_at=datetime(2026, 5, 11, 11, 30))
    assert evaluate_rule(WINDOW_OR_BOX_LEFT_OPEN.spec, ctx) is None


# ---------- LEAVE_WITHOUT_SENTRY ----------

def test_leave_without_sentry_fires_when_off():
    state = VehicleStateSnapshot(sentry_mode_on=False, shift_state="P")
    ctx = _ctx(state, departure_at=datetime(2026, 5, 11, 11, 30))
    alert = evaluate_rule(LEAVE_WITHOUT_SENTRY.spec, ctx)
    assert alert is not None
    assert "哨兵" in alert.title
    assert alert.primary_action_label == "打开哨兵"


def test_leave_without_sentry_no_fire_when_on():
    state = VehicleStateSnapshot(sentry_mode_on=True, shift_state="P")
    ctx = _ctx(state, departure_at=datetime(2026, 5, 11, 11, 30))
    assert evaluate_rule(LEAVE_WITHOUT_SENTRY.spec, ctx) is None


# ---------- Geofence-gated user_departure ----------

def _gated_spec(geofence_lat: float, geofence_lng: float, radius: int = 200) -> dict:
    """Reuses LEAVE_WITHOUT_SENTRY's shape but adds an at_geofence gate."""
    import copy
    spec = copy.deepcopy(LEAVE_WITHOUT_SENTRY.spec)
    spec["trigger"]["at_geofence"] = {
        "lat": geofence_lat, "lng": geofence_lng, "radius_m": radius,
    }
    return spec


def test_geofence_gate_fires_when_inside():
    """Vehicle parked AT home, sentry off → fire."""
    state = VehicleStateSnapshot(
        sentry_mode_on=False, shift_state="P",
        latitude=39.9087, longitude=116.3974,   # 天安门 example
    )
    spec = _gated_spec(geofence_lat=39.9087, geofence_lng=116.3974, radius=200)
    ctx = _ctx(state, departure_at=datetime(2026, 5, 11, 11, 30))
    assert evaluate_rule(spec, ctx) is not None


def test_geofence_gate_no_fire_when_outside():
    """Vehicle parked far from home, sentry off → no fire (gate filters
    out "at the office")."""
    state = VehicleStateSnapshot(
        sentry_mode_on=False, shift_state="P",
        latitude=31.2304, longitude=121.4737,   # Shanghai — far from BJ
    )
    spec = _gated_spec(geofence_lat=39.9087, geofence_lng=116.3974, radius=200)
    ctx = _ctx(state, departure_at=datetime(2026, 5, 11, 11, 30))
    assert evaluate_rule(spec, ctx) is None


def test_geofence_gate_no_fire_when_location_missing():
    """No vehicle.location → conservative, don't fire."""
    state = VehicleStateSnapshot(
        sentry_mode_on=False, shift_state="P",
        # latitude / longitude are None
    )
    spec = _gated_spec(geofence_lat=39.9087, geofence_lng=116.3974, radius=200)
    ctx = _ctx(state, departure_at=datetime(2026, 5, 11, 11, 30))
    assert evaluate_rule(spec, ctx) is None


def test_geofence_gate_no_fire_with_placeholder_lat_lng():
    """Placeholder 0,0 means user hasn't picked a location yet —
    don't fire until they configure."""
    state = VehicleStateSnapshot(
        sentry_mode_on=False, shift_state="P",
        latitude=39.9087, longitude=116.3974,
    )
    spec = _gated_spec(geofence_lat=0.0, geofence_lng=0.0, radius=200)
    ctx = _ctx(state, departure_at=datetime(2026, 5, 11, 11, 30))
    # With placeholder, vehicle is 10000+ km from (0,0) → outside →
    # no fire. (Strictly: not strictly "gate filters out" but the
    # result aligns with what we want.)
    assert evaluate_rule(spec, ctx) is None
