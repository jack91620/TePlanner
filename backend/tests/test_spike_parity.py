"""Phase 10.2 parity-gate spike test.

For each scenario in `test_automation_rules.py`, run the SAME inputs
through (a) the existing per-class rule and (b) the new generic
`evaluate_rule(spec, ctx)` interpreter using the matching preset spec.
Assert the produced Alert is byte-identical (kind / title / detail /
severity / primary_action_label).

Pass = parity gate cleared, Phase 10.1 unblocked, schema validated.
Fail = analyze drift, adjust schema before any production code.
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
from app.services.automation.rules import (
    CabinOverheatAutomation,
    CampModeAutomation,
    ChargeCompleteAutomation,
    SentryModeAutomation,
)
from app.services.automation.spike_interpreter import (
    PRESET_CABIN_OVERHEAT,
    PRESET_CAMP_MODE,
    PRESET_CHARGE_COMPLETE,
    PRESET_SENTRY_MODE,
    evaluate_rule,
)


def _ctx(state, *, now=None, memory=None, vehicle_id="abc"):
    return AutomationContext(
        vehicle_state=state,
        vehicle_id=vehicle_id,
        now=now or datetime(2026, 5, 7, 12, 0, 0, tzinfo=timezone.utc),
        settings=AutomationSettings(),
        memory=memory or InMemoryStateMemory(),
    )


def _alerts_equal(a, b):
    if a is None and b is None:
        return True
    if a is None or b is None:
        return False
    return (
        a.kind == b.kind
        and a.title == b.title
        and a.detail == b.detail
        and a.severity == b.severity
        and a.primary_action_label == b.primary_action_label
    )


# ---------- CampMode ----------

def test_parity_camp_mode_off():
    state = VehicleStateSnapshot(climate_keeper_mode=0)
    old = CampModeAutomation().evaluate(_ctx(state, memory=InMemoryStateMemory()))
    new = evaluate_rule(PRESET_CAMP_MODE, _ctx(state, memory=InMemoryStateMemory()))
    assert old is None and new is None
    assert _alerts_equal(old, new)


def test_parity_camp_mode_just_turned_on_is_info():
    state = VehicleStateSnapshot(climate_keeper_mode=3)
    m_old = InMemoryStateMemory()
    m_new = InMemoryStateMemory()
    old = CampModeAutomation().evaluate(_ctx(state, memory=m_old))
    new = evaluate_rule(PRESET_CAMP_MODE, _ctx(state, memory=m_new))
    assert _alerts_equal(old, new), f"old={old} new={new}"
    assert old.severity == AlertSeverity.INFO


def test_parity_camp_mode_past_threshold_is_critical():
    state = VehicleStateSnapshot(climate_keeper_mode=3)
    started = datetime(2026, 5, 7, 9, 0, 0, tzinfo=timezone.utc)
    later = started + timedelta(hours=3)

    m_old = InMemoryStateMemory()
    m_new = InMemoryStateMemory()
    CampModeAutomation().evaluate(_ctx(state, now=started, memory=m_old))
    evaluate_rule(PRESET_CAMP_MODE, _ctx(state, now=started, memory=m_new))

    old = CampModeAutomation().evaluate(_ctx(state, now=later, memory=m_old))
    new = evaluate_rule(PRESET_CAMP_MODE, _ctx(state, now=later, memory=m_new))

    assert _alerts_equal(old, new), f"old={old} new={new}"
    assert old.severity == AlertSeverity.CRITICAL
    assert old.primary_action_label == "关闭"


def test_parity_camp_mode_threshold_zero_disables():
    state = VehicleStateSnapshot(climate_keeper_mode=3)
    spec = copy.deepcopy(PRESET_CAMP_MODE)
    spec["trigger"]["for_minutes"] = 0

    # Old uses settings to disable (camp_mode_reminder_minutes=0).
    old_ctx = AutomationContext(
        vehicle_state=state,
        vehicle_id="abc",
        now=datetime(2026, 5, 7, 12, 0, 0, tzinfo=timezone.utc),
        settings=AutomationSettings(camp_mode_reminder_minutes=0),
        memory=InMemoryStateMemory(),
    )
    new_ctx = _ctx(state, memory=InMemoryStateMemory())
    old = CampModeAutomation().evaluate(old_ctx)
    new = evaluate_rule(spec, new_ctx)
    assert old is None and new is None


def test_parity_camp_mode_clears_memory_when_off():
    on = VehicleStateSnapshot(climate_keeper_mode=3)
    off = VehicleStateSnapshot(climate_keeper_mode=0)
    m_old = InMemoryStateMemory()
    m_new = InMemoryStateMemory()

    CampModeAutomation().evaluate(_ctx(on, memory=m_old))
    evaluate_rule(PRESET_CAMP_MODE, _ctx(on, memory=m_new))
    assert m_old.get("campMode:startedAt") is not None
    assert m_new.get("campMode:startedAt") is not None

    CampModeAutomation().evaluate(_ctx(off, memory=m_old))
    evaluate_rule(PRESET_CAMP_MODE, _ctx(off, memory=m_new))
    assert m_old.get("campMode:startedAt") is None
    assert m_new.get("campMode:startedAt") is None


# ---------- SentryMode ----------

def test_parity_sentry_off():
    state = VehicleStateSnapshot(sentry_mode_on=False)
    old = SentryModeAutomation().evaluate(_ctx(state, memory=InMemoryStateMemory()))
    new = evaluate_rule(PRESET_SENTRY_MODE, _ctx(state, memory=InMemoryStateMemory()))
    assert old is None and new is None


def test_parity_sentry_below_threshold_is_info():
    state = VehicleStateSnapshot(sentry_mode_on=True)
    m_old = InMemoryStateMemory()
    m_new = InMemoryStateMemory()
    old = SentryModeAutomation().evaluate(_ctx(state, memory=m_old))
    new = evaluate_rule(PRESET_SENTRY_MODE, _ctx(state, memory=m_new))
    assert _alerts_equal(old, new), f"old={old} new={new}"
    assert old.severity == AlertSeverity.INFO


def test_parity_sentry_past_24h_is_critical():
    state = VehicleStateSnapshot(sentry_mode_on=True)
    started = datetime(2026, 5, 5, 0, 0, 0, tzinfo=timezone.utc)
    later = started + timedelta(hours=25)

    m_old = InMemoryStateMemory()
    m_new = InMemoryStateMemory()
    SentryModeAutomation().evaluate(_ctx(state, now=started, memory=m_old))
    evaluate_rule(PRESET_SENTRY_MODE, _ctx(state, now=started, memory=m_new))

    old = SentryModeAutomation().evaluate(_ctx(state, now=later, memory=m_old))
    new = evaluate_rule(PRESET_SENTRY_MODE, _ctx(state, now=later, memory=m_new))

    assert _alerts_equal(old, new), f"old={old} new={new}"
    assert old.severity == AlertSeverity.CRITICAL
    assert old.primary_action_label == "关闭哨兵"


# ---------- CabinOverheat ----------

def test_parity_cabin_overheat_below_threshold_silent():
    state = VehicleStateSnapshot(cabin_overheat_protection_on=True)
    m_old = InMemoryStateMemory()
    m_new = InMemoryStateMemory()
    old = CabinOverheatAutomation().evaluate(_ctx(state, memory=m_old))
    new = evaluate_rule(PRESET_CABIN_OVERHEAT, _ctx(state, memory=m_new))
    assert old is None and new is None


def test_parity_cabin_overheat_after_threshold_emits_info():
    state = VehicleStateSnapshot(cabin_overheat_protection_on=True)
    started = datetime(2026, 5, 7, 12, 0, 0, tzinfo=timezone.utc)
    later = started + timedelta(minutes=90)

    m_old = InMemoryStateMemory()
    m_new = InMemoryStateMemory()
    CabinOverheatAutomation().evaluate(_ctx(state, now=started, memory=m_old))
    evaluate_rule(PRESET_CABIN_OVERHEAT, _ctx(state, now=started, memory=m_new))

    old = CabinOverheatAutomation().evaluate(_ctx(state, now=later, memory=m_old))
    new = evaluate_rule(PRESET_CABIN_OVERHEAT, _ctx(state, now=later, memory=m_new))

    assert _alerts_equal(old, new), f"old={old} new={new}"
    assert old.severity == AlertSeverity.INFO
    assert old.primary_action_label is None


# ---------- ChargeComplete ----------

def test_parity_charge_complete_only_fires_on_complete():
    state = VehicleStateSnapshot(charging_state="Charging", battery_level=70)
    old = ChargeCompleteAutomation().evaluate(_ctx(state, memory=InMemoryStateMemory()))
    new = evaluate_rule(PRESET_CHARGE_COMPLETE, _ctx(state, memory=InMemoryStateMemory()))
    assert old is None and new is None


def test_parity_charge_complete_fires_critical():
    state = VehicleStateSnapshot(charging_state="Complete", battery_level=80)
    m_old = InMemoryStateMemory()
    m_new = InMemoryStateMemory()
    old = ChargeCompleteAutomation().evaluate(_ctx(state, memory=m_old))
    new = evaluate_rule(PRESET_CHARGE_COMPLETE, _ctx(state, memory=m_new))
    assert _alerts_equal(old, new), f"old={old} new={new}"
    assert old.severity == AlertSeverity.CRITICAL


def test_parity_charge_complete_disabled_returns_none():
    state = VehicleStateSnapshot(charging_state="Complete", battery_level=80)
    spec = copy.deepcopy(PRESET_CHARGE_COMPLETE)
    spec["enabled"] = False

    old_ctx = AutomationContext(
        vehicle_state=state,
        vehicle_id="abc",
        now=datetime(2026, 5, 7, 12, 0, 0, tzinfo=timezone.utc),
        settings=AutomationSettings(charge_complete_reminder_enabled=False),
        memory=InMemoryStateMemory(),
    )
    new_ctx = _ctx(state, memory=InMemoryStateMemory())
    old = ChargeCompleteAutomation().evaluate(old_ctx)
    new = evaluate_rule(spec, new_ctx)
    assert old is None and new is None


def test_parity_charge_complete_dismissed_then_unplugged_rearms():
    state_complete = VehicleStateSnapshot(charging_state="Complete", battery_level=80)
    state_disconnected = VehicleStateSnapshot(charging_state="Disconnected", battery_level=80)

    m_old = InMemoryStateMemory()
    m_new = InMemoryStateMemory()

    # First complete fires.
    o1 = ChargeCompleteAutomation().evaluate(_ctx(state_complete, memory=m_old))
    n1 = evaluate_rule(PRESET_CHARGE_COMPLETE, _ctx(state_complete, memory=m_new))
    assert _alerts_equal(o1, n1) and o1 is not None

    # Simulate dismiss.
    now = datetime.now(timezone.utc)
    m_old.set("chargeComplete:dismissedAt", now)
    m_new.set("chargeComplete:dismissedAt", now)

    # Same complete state suppressed.
    o2 = ChargeCompleteAutomation().evaluate(_ctx(state_complete, memory=m_old))
    n2 = evaluate_rule(PRESET_CHARGE_COMPLETE, _ctx(state_complete, memory=m_new))
    assert o2 is None and n2 is None

    # Unplug clears both.
    ChargeCompleteAutomation().evaluate(_ctx(state_disconnected, memory=m_old))
    evaluate_rule(PRESET_CHARGE_COMPLETE, _ctx(state_disconnected, memory=m_new))
    assert m_old.get("chargeComplete:dismissedAt") is None
    assert m_new.get("chargeComplete:dismissedAt") is None
    assert m_old.get("chargeComplete:firstSeenAt") is None
    assert m_new.get("chargeComplete:firstSeenAt") is None

    # Plug back in re-arms.
    o3 = ChargeCompleteAutomation().evaluate(_ctx(state_complete, memory=m_old))
    n3 = evaluate_rule(PRESET_CHARGE_COMPLETE, _ctx(state_complete, memory=m_new))
    assert _alerts_equal(o3, n3) and o3 is not None
