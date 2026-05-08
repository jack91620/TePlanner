"""Telemetry-since fallback in `_eval_state_duration`.

Phase 4 contract: when the rule is on AND `tel:<entity>:since` exists
AND it's earlier than the polling-observed `state_key`, the
interpreter uses the telemetry timestamp. That's how the user gets
"已开启 1 小时" in the push instead of "已开启 0 分钟" — polling
might have just observed the state, but telemetry knew it 30 min ago.
"""

from datetime import datetime, timedelta, timezone

from app.services.automation.base import (
    AlertSeverity,
    AutomationContext,
    AutomationSettings,
    InMemoryStateMemory,
    VehicleStateSnapshot,
)
from app.services.automation.interpreters import evaluate_rule
from app.services.automation.presets import CAMP_MODE


def _ctx(state, now, memory):
    return AutomationContext(
        vehicle_state=state,
        vehicle_id="abc",
        now=now,
        settings=AutomationSettings(),
        memory=memory,
    )


def test_telemetry_since_supersedes_polling_observation():
    """Polling observed at T0; telemetry knew at T0 - 3h. The
    interpreter must pick T0 - 3h so duration crosses the 2h camp-mode
    threshold and we fire critical instead of info.
    """
    state = VehicleStateSnapshot(climate_keeper_mode=3)
    now = datetime(2026, 5, 8, 12, 0, 0, tzinfo=timezone.utc)
    memory = InMemoryStateMemory()
    # First eval seeds polling memory with `now` as the start.
    alert = evaluate_rule(CAMP_MODE.spec, _ctx(state, now, memory))
    assert alert is not None
    assert alert.severity == AlertSeverity.INFO  # 0 min elapsed

    # Now drop in a telemetry-recorded since from 3h before.
    memory.set(
        "tel:vehicle.climate.keeper_mode:since",
        now - timedelta(hours=3),
    )
    alert2 = evaluate_rule(CAMP_MODE.spec, _ctx(state, now, memory))
    assert alert2 is not None
    assert alert2.severity == AlertSeverity.CRITICAL
    assert "3 小时" in alert2.detail


def test_telemetry_since_ignored_when_later_than_polling():
    """Belt-and-suspenders: if telemetry's since is newer than
    polling's startedAt, polling's stays authoritative.
    """
    state = VehicleStateSnapshot(climate_keeper_mode=3)
    now = datetime(2026, 5, 8, 12, 0, 0, tzinfo=timezone.utc)
    memory = InMemoryStateMemory()
    # Polling observed 4h ago.
    memory.set("campMode:startedAt", now - timedelta(hours=4))
    # Telemetry only saw it 1h ago (e.g. consumer just restarted).
    memory.set(
        "tel:vehicle.climate.keeper_mode:since",
        now - timedelta(hours=1),
    )

    alert = evaluate_rule(CAMP_MODE.spec, _ctx(state, now, memory))
    assert alert.severity == AlertSeverity.CRITICAL
    assert "4 小时" in alert.detail


def test_no_telemetry_since_keeps_polling_behaviour():
    state = VehicleStateSnapshot(climate_keeper_mode=3)
    now = datetime(2026, 5, 8, 12, 0, 0, tzinfo=timezone.utc)
    memory = InMemoryStateMemory()
    memory.set("campMode:startedAt", now - timedelta(minutes=30))

    alert = evaluate_rule(CAMP_MODE.spec, _ctx(state, now, memory))
    assert alert.severity == AlertSeverity.INFO
    assert "30 分钟" in alert.detail


def test_telemetry_since_does_not_fire_when_state_is_off():
    """Rule is off → no alert regardless of telemetry since."""
    state = VehicleStateSnapshot(climate_keeper_mode=0)  # off
    now = datetime(2026, 5, 8, 12, 0, 0, tzinfo=timezone.utc)
    memory = InMemoryStateMemory()
    memory.set(
        "tel:vehicle.climate.keeper_mode:since",
        now - timedelta(hours=10),
    )
    assert evaluate_rule(CAMP_MODE.spec, _ctx(state, now, memory)) is None
