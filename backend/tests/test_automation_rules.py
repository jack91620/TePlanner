"""Unit tests for the four automation rules.

Pure logic — no DB / no async. Mirrors the iOS test coverage in
Tests/TePlannerTests/{CampMode,SentryMode,CabinOverheat,ChargeComplete}AutomationTests.swift
so any wording / threshold drift between client and server is caught
quickly.
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
from app.services.automation.rules import (
    CabinOverheatAutomation,
    CampModeAutomation,
    ChargeCompleteAutomation,
    SentryModeAutomation,
)


def _ctx(state, *, settings=None, now=None, memory=None, vehicle_id="abc"):
    return AutomationContext(
        vehicle_state=state,
        vehicle_id=vehicle_id,
        now=now or datetime(2026, 5, 7, 12, 0, 0, tzinfo=timezone.utc),
        settings=settings or AutomationSettings(),
        memory=memory or InMemoryStateMemory(),
    )


# ---------- CampMode ----------

def test_camp_mode_off_returns_none():
    rule = CampModeAutomation()
    state = VehicleStateSnapshot(climate_keeper_mode=0)
    assert rule.evaluate(_ctx(state)) is None


def test_camp_mode_just_turned_on_is_info():
    rule = CampModeAutomation()
    memory = InMemoryStateMemory()
    state = VehicleStateSnapshot(climate_keeper_mode=3)
    alert = rule.evaluate(_ctx(state, memory=memory))
    assert alert is not None
    assert alert.kind == AlertKind.CAMP_MODE
    assert alert.severity == AlertSeverity.INFO


def test_camp_mode_past_threshold_is_critical():
    rule = CampModeAutomation()
    memory = InMemoryStateMemory()
    state = VehicleStateSnapshot(climate_keeper_mode=3)
    started = datetime(2026, 5, 7, 9, 0, 0, tzinfo=timezone.utc)
    later = started + timedelta(hours=3)
    rule.evaluate(_ctx(state, now=started, memory=memory))
    alert = rule.evaluate(_ctx(state, now=later, memory=memory))
    assert alert.severity == AlertSeverity.CRITICAL
    assert alert.primary_action_label == "关闭"
    assert "电池" in alert.detail


def test_camp_mode_threshold_zero_disables_rule():
    rule = CampModeAutomation()
    settings = AutomationSettings(camp_mode_reminder_minutes=0)
    state = VehicleStateSnapshot(climate_keeper_mode=3)
    assert rule.evaluate(_ctx(state, settings=settings)) is None


def test_camp_mode_clears_memory_when_off():
    rule = CampModeAutomation()
    memory = InMemoryStateMemory()
    on = VehicleStateSnapshot(climate_keeper_mode=3)
    off = VehicleStateSnapshot(climate_keeper_mode=0)
    rule.evaluate(_ctx(on, memory=memory))
    assert memory.get(rule.state_key) is not None
    rule.evaluate(_ctx(off, memory=memory))
    assert memory.get(rule.state_key) is None


# ---------- SentryMode ----------

def test_sentry_off_returns_none():
    rule = SentryModeAutomation()
    state = VehicleStateSnapshot(sentry_mode_on=False)
    assert rule.evaluate(_ctx(state)) is None


def test_sentry_below_threshold_is_info():
    rule = SentryModeAutomation()
    memory = InMemoryStateMemory()
    state = VehicleStateSnapshot(sentry_mode_on=True)
    alert = rule.evaluate(_ctx(state, memory=memory))
    assert alert.severity == AlertSeverity.INFO


def test_sentry_past_24h_is_critical():
    rule = SentryModeAutomation()
    memory = InMemoryStateMemory()
    state = VehicleStateSnapshot(sentry_mode_on=True)
    started = datetime(2026, 5, 5, 0, 0, 0, tzinfo=timezone.utc)
    later = started + timedelta(hours=25)
    rule.evaluate(_ctx(state, now=started, memory=memory))
    alert = rule.evaluate(_ctx(state, now=later, memory=memory))
    assert alert.severity == AlertSeverity.CRITICAL
    assert alert.primary_action_label == "关闭哨兵"


# ---------- CabinOverheat ----------

def test_cabin_overheat_below_threshold_is_silent():
    rule = CabinOverheatAutomation()
    memory = InMemoryStateMemory()
    state = VehicleStateSnapshot(cabin_overheat_protection_on=True)
    # default threshold is 60min; first observation only records timer.
    assert rule.evaluate(_ctx(state, memory=memory)) is None


def test_cabin_overheat_after_threshold_emits_info():
    rule = CabinOverheatAutomation()
    memory = InMemoryStateMemory()
    state = VehicleStateSnapshot(cabin_overheat_protection_on=True)
    started = datetime(2026, 5, 7, 12, 0, 0, tzinfo=timezone.utc)
    later = started + timedelta(minutes=90)
    rule.evaluate(_ctx(state, now=started, memory=memory))
    alert = rule.evaluate(_ctx(state, now=later, memory=memory))
    assert alert is not None
    assert alert.severity == AlertSeverity.INFO
    assert alert.primary_action_label is None  # info-only, no action


# ---------- ChargeComplete ----------

def test_charge_complete_only_fires_on_complete_state():
    rule = ChargeCompleteAutomation()
    state = VehicleStateSnapshot(charging_state="Charging", battery_level=70)
    assert rule.evaluate(_ctx(state)) is None


def test_charge_complete_fires_critical():
    rule = ChargeCompleteAutomation()
    memory = InMemoryStateMemory()
    state = VehicleStateSnapshot(charging_state="Complete", battery_level=80)
    alert = rule.evaluate(_ctx(state, memory=memory))
    assert alert is not None
    assert alert.kind == AlertKind.CHARGE_COMPLETE
    assert alert.severity == AlertSeverity.CRITICAL
    assert "80%" in alert.detail


def test_charge_complete_disabled_returns_none():
    rule = ChargeCompleteAutomation()
    settings = AutomationSettings(charge_complete_reminder_enabled=False)
    state = VehicleStateSnapshot(charging_state="Complete", battery_level=80)
    assert rule.evaluate(_ctx(state, settings=settings)) is None


def test_charge_complete_dismissed_then_unplugged_rearms():
    rule = ChargeCompleteAutomation()
    memory = InMemoryStateMemory()
    state_complete = VehicleStateSnapshot(charging_state="Complete", battery_level=80)
    state_disconnected = VehicleStateSnapshot(charging_state="Disconnected", battery_level=80)

    # First Complete → fires
    alert1 = rule.evaluate(_ctx(state_complete, memory=memory))
    assert alert1 is not None
    # Simulate user dismiss: rule writes dismissedKey when action succeeds.
    # Engine layer normally does this; in the test, just set directly.
    memory.set(rule.dismissed_key, datetime.now(timezone.utc))
    # Same Complete state — no re-fire while dismissed.
    assert rule.evaluate(_ctx(state_complete, memory=memory)) is None
    # Unplug: state leaves Complete → dismissedKey cleared.
    rule.evaluate(_ctx(state_disconnected, memory=memory))
    assert memory.get(rule.dismissed_key) is None
    # Plug in again → fresh Complete fires again.
    alert2 = rule.evaluate(_ctx(state_complete, memory=memory))
    assert alert2 is not None
