"""Smart-cadence logic tests for polling.py.

The car has a vampire-drain problem if our 5-min poll keeps it from
sleeping. The pure logic that decides whether THIS tick should fetch
or reuse cached state lives in `_should_skip_fetch` + `_is_vehicle_idle`.
These tests pin the rule contract.
"""

from datetime import datetime, timedelta, timezone

from app.services.automation.base import VehicleStateSnapshot
from app.services.polling import (
    _PollState,
    _is_vehicle_idle,
    _should_skip_fetch,
)


NOW = datetime(2026, 5, 8, 12, 0, 0, tzinfo=timezone.utc)


def _state(prev_snap: VehicleStateSnapshot, asleep: bool, age_minutes: int) -> _PollState:
    return _PollState(
        fetched_at=NOW - timedelta(minutes=age_minutes),
        was_asleep=asleep,
        snapshot=prev_snap,
    )


# ---------- _is_vehicle_idle ----------

def test_idle_when_parked_and_nothing_running():
    snap = VehicleStateSnapshot(
        shift_state="P",
        charging_state="Disconnected",
        climate_keeper_mode=0,
        sentry_mode_on=False,
    )
    assert _is_vehicle_idle(snap) is True


def test_idle_when_shift_state_is_none():
    # Tesla returns None when car is asleep — treat as parked.
    snap = VehicleStateSnapshot(
        shift_state=None,
        sentry_mode_on=False,
    )
    assert _is_vehicle_idle(snap) is True


def test_not_idle_when_charging():
    snap = VehicleStateSnapshot(shift_state="P", charging_state="Charging")
    assert _is_vehicle_idle(snap) is False


def test_not_idle_when_camp_mode_running():
    snap = VehicleStateSnapshot(shift_state="P", climate_keeper_mode=3)
    assert _is_vehicle_idle(snap) is False


def test_not_idle_when_sentry_on():
    snap = VehicleStateSnapshot(shift_state="P", sentry_mode_on=True)
    assert _is_vehicle_idle(snap) is False


def test_not_idle_when_driving():
    snap = VehicleStateSnapshot(shift_state="D")
    assert _is_vehicle_idle(snap) is False


def test_not_idle_when_no_snapshot():
    assert _is_vehicle_idle(None) is False


# ---------- _should_skip_fetch ----------

def test_no_skip_first_ever_tick():
    assert _should_skip_fetch(None, NOW) is False


def test_skip_when_last_was_asleep_within_30min():
    snap = VehicleStateSnapshot()
    prev = _state(snap, asleep=True, age_minutes=15)
    assert _should_skip_fetch(prev, NOW) is True


def test_no_skip_when_asleep_window_elapsed():
    # 30 min elapsed since last asleep observation → check again.
    snap = VehicleStateSnapshot()
    prev = _state(snap, asleep=True, age_minutes=31)
    assert _should_skip_fetch(prev, NOW) is False


def test_skip_when_idle_within_30min():
    idle = VehicleStateSnapshot(
        shift_state="P",
        charging_state="Disconnected",
        climate_keeper_mode=0,
        sentry_mode_on=False,
    )
    prev = _state(idle, asleep=False, age_minutes=10)
    assert _should_skip_fetch(prev, NOW) is True


def test_no_skip_when_camping_even_in_window():
    # Camp mode = active state we want to track at 5-min cadence.
    camping = VehicleStateSnapshot(
        shift_state="P",
        climate_keeper_mode=3,
    )
    prev = _state(camping, asleep=False, age_minutes=4)
    assert _should_skip_fetch(prev, NOW) is False


def test_no_skip_when_sentry_on_within_window():
    sentry = VehicleStateSnapshot(shift_state="P", sentry_mode_on=True)
    prev = _state(sentry, asleep=False, age_minutes=4)
    assert _should_skip_fetch(prev, NOW) is False


def test_no_skip_when_charging_within_window():
    charging = VehicleStateSnapshot(
        shift_state="P", charging_state="Charging"
    )
    prev = _state(charging, asleep=False, age_minutes=4)
    assert _should_skip_fetch(prev, NOW) is False


def test_no_skip_when_driving_within_window():
    driving = VehicleStateSnapshot(shift_state="D")
    prev = _state(driving, asleep=False, age_minutes=4)
    assert _should_skip_fetch(prev, NOW) is False
