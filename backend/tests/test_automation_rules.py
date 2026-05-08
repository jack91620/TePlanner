"""Tests for the 4 preset automation rules — declarative form.

After Phase 10.2 the per-class rules in rules.py are gone. The 4
preset specs live in `presets.py` and are evaluated by
`interpreters.evaluate_rule(spec, ctx)`. These tests assert the same
Alert title / detail / severity / primary_action_label that the old
class-based tests asserted.

Mirror coverage in iOS Tests/TePlannerTests/*AutomationTests.swift.
"""

import copy
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
from app.services.automation.interpreters import evaluate_rule
from app.services.automation.presets import (
    CABIN_OVERHEAT,
    CAMP_MODE,
    CHARGE_COMPLETE,
    LEFT_UNLOCKED,
    LOW_BATTERY,
    SENTRY_MODE,
    WINDOW_OR_BOX_LEFT_OPEN,
)


def _ctx(state, *, now=None, memory=None, vehicle_id="abc"):
    return AutomationContext(
        vehicle_state=state,
        vehicle_id=vehicle_id,
        now=now or datetime(2026, 5, 7, 12, 0, 0, tzinfo=timezone.utc),
        settings=AutomationSettings(),
        memory=memory or InMemoryStateMemory(),
    )


# ---------- CampMode ----------

def test_camp_mode_off_returns_none():
    state = VehicleStateSnapshot(climate_keeper_mode=0)
    assert evaluate_rule(CAMP_MODE.spec, _ctx(state)) is None


def test_camp_mode_just_turned_on_is_info():
    state = VehicleStateSnapshot(climate_keeper_mode=3)
    alert = evaluate_rule(CAMP_MODE.spec, _ctx(state, memory=InMemoryStateMemory()))
    assert alert is not None
    assert alert.kind == AlertKind.CAMP_MODE
    assert alert.severity == AlertSeverity.INFO
    assert alert.title == "露营模式开启中"
    assert alert.primary_action_label is None


def test_camp_mode_past_threshold_is_critical():
    state = VehicleStateSnapshot(climate_keeper_mode=3)
    started = datetime(2026, 5, 7, 9, 0, 0, tzinfo=timezone.utc)
    later = started + timedelta(hours=3)
    memory = InMemoryStateMemory()
    evaluate_rule(CAMP_MODE.spec, _ctx(state, now=started, memory=memory))
    alert = evaluate_rule(CAMP_MODE.spec, _ctx(state, now=later, memory=memory))
    assert alert.severity == AlertSeverity.CRITICAL
    assert alert.primary_action_label == "关闭"
    assert "电池" in alert.detail
    assert "3 小时" in alert.detail


def test_camp_mode_threshold_zero_disables_rule():
    state = VehicleStateSnapshot(climate_keeper_mode=3)
    spec = copy.deepcopy(CAMP_MODE.spec)
    spec["trigger"]["for_minutes"] = 0
    assert evaluate_rule(spec, _ctx(state, memory=InMemoryStateMemory())) is None


def test_camp_mode_clears_memory_when_off():
    on = VehicleStateSnapshot(climate_keeper_mode=3)
    off = VehicleStateSnapshot(climate_keeper_mode=0)
    memory = InMemoryStateMemory()
    evaluate_rule(CAMP_MODE.spec, _ctx(on, memory=memory))
    assert memory.get("campMode:startedAt") is not None
    evaluate_rule(CAMP_MODE.spec, _ctx(off, memory=memory))
    assert memory.get("campMode:startedAt") is None


# ---------- SentryMode ----------

def test_sentry_off_returns_none():
    state = VehicleStateSnapshot(sentry_mode_on=False)
    assert evaluate_rule(SENTRY_MODE.spec, _ctx(state)) is None


def test_sentry_below_threshold_is_info():
    state = VehicleStateSnapshot(sentry_mode_on=True)
    alert = evaluate_rule(SENTRY_MODE.spec, _ctx(state, memory=InMemoryStateMemory()))
    assert alert.severity == AlertSeverity.INFO
    assert alert.title == "哨兵模式开启中"


def test_sentry_past_24h_is_critical():
    state = VehicleStateSnapshot(sentry_mode_on=True)
    started = datetime(2026, 5, 5, 0, 0, 0, tzinfo=timezone.utc)
    later = started + timedelta(hours=25)
    memory = InMemoryStateMemory()
    evaluate_rule(SENTRY_MODE.spec, _ctx(state, now=started, memory=memory))
    alert = evaluate_rule(SENTRY_MODE.spec, _ctx(state, now=later, memory=memory))
    assert alert.severity == AlertSeverity.CRITICAL
    assert alert.primary_action_label == "关闭哨兵"


# ---------- CabinOverheat ----------

def test_cabin_overheat_below_threshold_is_silent():
    state = VehicleStateSnapshot(cabin_overheat_protection_on=True)
    # Default 60min threshold; first observation only records timer,
    # actions_below=[] so no alert fires.
    assert evaluate_rule(CABIN_OVERHEAT.spec, _ctx(state, memory=InMemoryStateMemory())) is None


def test_cabin_overheat_after_threshold_emits_info():
    state = VehicleStateSnapshot(cabin_overheat_protection_on=True)
    started = datetime(2026, 5, 7, 12, 0, 0, tzinfo=timezone.utc)
    later = started + timedelta(minutes=90)
    memory = InMemoryStateMemory()
    evaluate_rule(CABIN_OVERHEAT.spec, _ctx(state, now=started, memory=memory))
    alert = evaluate_rule(CABIN_OVERHEAT.spec, _ctx(state, now=later, memory=memory))
    assert alert is not None
    assert alert.severity == AlertSeverity.INFO
    assert alert.title == "座舱过热保护已启动"
    assert alert.primary_action_label is None  # info-only, no action


# ---------- ChargeComplete ----------

def test_charge_complete_only_fires_on_complete_state():
    state = VehicleStateSnapshot(charging_state="Charging", battery_level=70)
    assert evaluate_rule(CHARGE_COMPLETE.spec, _ctx(state)) is None


def test_charge_complete_fires_critical():
    state = VehicleStateSnapshot(charging_state="Complete", battery_level=80)
    alert = evaluate_rule(CHARGE_COMPLETE.spec, _ctx(state, memory=InMemoryStateMemory()))
    assert alert is not None
    assert alert.kind == AlertKind.CHARGE_COMPLETE
    assert alert.severity == AlertSeverity.CRITICAL
    assert alert.title == "充电已完成"
    assert "80%" in alert.detail
    assert alert.primary_action_label == "我知道了"


def test_charge_complete_disabled_returns_none():
    state = VehicleStateSnapshot(charging_state="Complete", battery_level=80)
    spec = copy.deepcopy(CHARGE_COMPLETE.spec)
    spec["enabled"] = False
    assert evaluate_rule(spec, _ctx(state, memory=InMemoryStateMemory())) is None


# ---------- LeftUnlocked (Slice A) ----------

def test_left_unlocked_silent_when_locked():
    state = VehicleStateSnapshot(locked=True, shift_state="P")
    assert evaluate_rule(LEFT_UNLOCKED.spec, _ctx(state)) is None


def test_left_unlocked_silent_while_driving_even_if_unlocked():
    # While driving (shift != P) the parked_unlocked virtual entity
    # is False, so the rule shouldn't fire.
    state = VehicleStateSnapshot(locked=False, shift_state="D")
    assert evaluate_rule(LEFT_UNLOCKED.spec, _ctx(state)) is None


def test_left_unlocked_below_threshold_no_actions_below():
    state = VehicleStateSnapshot(locked=False, shift_state="P")
    # actions_below is empty for this preset — we don't want to nag
    # while user might still be packing up. First few minutes are silent.
    assert evaluate_rule(LEFT_UNLOCKED.spec, _ctx(state, memory=InMemoryStateMemory())) is None


def test_left_unlocked_after_threshold_fires_critical():
    state = VehicleStateSnapshot(locked=False, shift_state="P")
    started = datetime(2026, 5, 7, 12, 0, 0, tzinfo=timezone.utc)
    later = started + timedelta(minutes=6)
    memory = InMemoryStateMemory()
    evaluate_rule(LEFT_UNLOCKED.spec, _ctx(state, now=started, memory=memory))
    alert = evaluate_rule(LEFT_UNLOCKED.spec, _ctx(state, now=later, memory=memory))
    assert alert is not None
    assert alert.kind == AlertKind.LEFT_UNLOCKED
    assert alert.severity == AlertSeverity.CRITICAL
    assert alert.title == "车辆未锁"


def test_left_unlocked_clears_when_locked():
    started = datetime(2026, 5, 7, 12, 0, 0, tzinfo=timezone.utc)
    later = started + timedelta(minutes=6)
    memory = InMemoryStateMemory()
    state_open = VehicleStateSnapshot(locked=False, shift_state="P")
    state_locked = VehicleStateSnapshot(locked=True, shift_state="P")
    evaluate_rule(LEFT_UNLOCKED.spec, _ctx(state_open, now=started, memory=memory))
    assert evaluate_rule(LEFT_UNLOCKED.spec, _ctx(state_open, now=later, memory=memory)) is not None
    # Lock the car → memory clears, no further alert
    evaluate_rule(LEFT_UNLOCKED.spec, _ctx(state_locked, now=later, memory=memory))
    assert memory.get("leftUnlocked:startedAt") is None


# ---------- LowBattery (Slice B — comparator) ----------

def test_low_battery_silent_above_threshold():
    state = VehicleStateSnapshot(battery_level=80)
    assert evaluate_rule(LOW_BATTERY.spec, _ctx(state, memory=InMemoryStateMemory())) is None


def test_low_battery_fires_below_threshold_after_minute():
    state = VehicleStateSnapshot(battery_level=29)
    started = datetime(2026, 5, 7, 12, 0, 0, tzinfo=timezone.utc)
    later = started + timedelta(minutes=2)
    memory = InMemoryStateMemory()
    evaluate_rule(LOW_BATTERY.spec, _ctx(state, now=started, memory=memory))
    alert = evaluate_rule(LOW_BATTERY.spec, _ctx(state, now=later, memory=memory))
    assert alert is not None
    assert alert.kind == AlertKind.LOW_BATTERY
    assert alert.severity == AlertSeverity.CRITICAL


def test_low_battery_at_exact_threshold_is_silent():
    # op is "<" not "<=" — 30% should NOT trigger.
    state = VehicleStateSnapshot(battery_level=30)
    started = datetime(2026, 5, 7, 12, 0, 0, tzinfo=timezone.utc)
    later = started + timedelta(minutes=2)
    memory = InMemoryStateMemory()
    evaluate_rule(LOW_BATTERY.spec, _ctx(state, now=started, memory=memory))
    assert evaluate_rule(LOW_BATTERY.spec, _ctx(state, now=later, memory=memory)) is None


def test_low_battery_clears_when_recharged_above_threshold():
    started = datetime(2026, 5, 7, 12, 0, 0, tzinfo=timezone.utc)
    later = started + timedelta(minutes=2)
    memory = InMemoryStateMemory()
    state_low = VehicleStateSnapshot(battery_level=20)
    state_recharged = VehicleStateSnapshot(battery_level=70)
    evaluate_rule(LOW_BATTERY.spec, _ctx(state_low, now=started, memory=memory))
    assert evaluate_rule(LOW_BATTERY.spec, _ctx(state_low, now=later, memory=memory)) is not None
    # Recharged → memory clears, no further alert
    evaluate_rule(LOW_BATTERY.spec, _ctx(state_recharged, now=later, memory=memory))
    assert memory.get("lowBattery:startedAt") is None


# ---------- WindowOrBoxLeftOpen (Slice A) ----------

def test_window_left_open_only_when_parked():
    # Window open while driving — rule should not fire.
    state_drive = VehicleStateSnapshot(window_open=True, shift_state="D")
    assert evaluate_rule(WINDOW_OR_BOX_LEFT_OPEN.spec, _ctx(state_drive)) is None


def test_window_left_open_fires_after_threshold_when_parked():
    state = VehicleStateSnapshot(window_open=True, shift_state="P")
    started = datetime(2026, 5, 7, 12, 0, 0, tzinfo=timezone.utc)
    later = started + timedelta(minutes=6)
    memory = InMemoryStateMemory()
    evaluate_rule(WINDOW_OR_BOX_LEFT_OPEN.spec, _ctx(state, now=started, memory=memory))
    alert = evaluate_rule(WINDOW_OR_BOX_LEFT_OPEN.spec, _ctx(state, now=later, memory=memory))
    assert alert is not None
    assert alert.kind == AlertKind.CLOSURE_LEFT_OPEN
    assert alert.severity == AlertSeverity.CRITICAL


def test_charge_complete_dismissed_then_unplugged_rearms():
    state_complete = VehicleStateSnapshot(charging_state="Complete", battery_level=80)
    state_disconnected = VehicleStateSnapshot(charging_state="Disconnected", battery_level=80)
    memory = InMemoryStateMemory()

    # First Complete → fires
    alert1 = evaluate_rule(CHARGE_COMPLETE.spec, _ctx(state_complete, memory=memory))
    assert alert1 is not None
    # Simulate engine setting dismissedAt after the user taps "我知道了"
    memory.set("chargeComplete:dismissedAt", datetime.now(timezone.utc))
    # Same Complete state — no re-fire while dismissed.
    assert evaluate_rule(CHARGE_COMPLETE.spec, _ctx(state_complete, memory=memory)) is None
    # Unplug clears both keys.
    evaluate_rule(CHARGE_COMPLETE.spec, _ctx(state_disconnected, memory=memory))
    assert memory.get("chargeComplete:dismissedAt") is None
    assert memory.get("chargeComplete:firstSeenAt") is None
    # Plug in again → fresh Complete fires again.
    alert2 = evaluate_rule(CHARGE_COMPLETE.spec, _ctx(state_complete, memory=memory))
    assert alert2 is not None
