"""Server-side port of the four iOS automation rules.

Wording matches Sources/TePlannerKit/Automations/*.swift verbatim where
possible — same titles / detail strings — so iOS local notifications
and server-driven APNs pushes feel identical.
"""

from __future__ import annotations

from typing import Optional

from app.services.automation.base import (
    Alert,
    AlertKind,
    AlertSeverity,
    Automation,
    AutomationContext,
)


def _format_minutes(minutes: int) -> str:
    if minutes < 60:
        return f"{minutes} 分钟"
    hours = minutes // 60
    rem = minutes % 60
    return f"{hours} 小时" if rem == 0 else f"{hours} 小时 {rem} 分钟"


class CampModeAutomation(Automation):
    """露营模式 — over threshold = critical with 关闭 button."""

    kind = AlertKind.CAMP_MODE
    state_key = "campMode:startedAt"

    def evaluate(self, ctx: AutomationContext) -> Optional[Alert]:
        is_on = bool(ctx.vehicle_state and ctx.vehicle_state.is_camp_mode_on)
        recorded = ctx.memory.get(self.state_key)

        if is_on and recorded is None:
            ctx.memory.set(self.state_key, ctx.now)
        elif not is_on and recorded is not None:
            ctx.memory.set(self.state_key, None)

        if not is_on:
            return None
        on_since = ctx.memory.get(self.state_key)
        if on_since is None:
            return None
        threshold = ctx.settings.camp_mode_reminder_minutes
        if threshold <= 0:
            return None

        minutes = max(0, int((ctx.now - on_since).total_seconds() / 60))
        critical = minutes >= threshold
        detail = (
            f"已开启 {_format_minutes(minutes)}，电池正在缓慢消耗"
            if critical
            else f"已开启 {_format_minutes(minutes)}"
        )
        return Alert(
            kind=self.kind,
            title="露营模式开启中",
            detail=detail,
            severity=AlertSeverity.CRITICAL if critical else AlertSeverity.INFO,
            primary_action_label="关闭" if critical else None,
        )


class SentryModeAutomation(Automation):
    """哨兵模式 — long-tail multi-day forgets."""

    kind = AlertKind.SENTRY_MODE
    state_key = "sentryMode:startedAt"

    def evaluate(self, ctx: AutomationContext) -> Optional[Alert]:
        is_on = bool(ctx.vehicle_state and ctx.vehicle_state.sentry_mode_on)
        recorded = ctx.memory.get(self.state_key)

        if is_on and recorded is None:
            ctx.memory.set(self.state_key, ctx.now)
        elif not is_on and recorded is not None:
            ctx.memory.set(self.state_key, None)

        if not is_on:
            return None
        on_since = ctx.memory.get(self.state_key)
        if on_since is None:
            return None
        threshold = ctx.settings.sentry_reminder_minutes
        if threshold <= 0:
            return None

        minutes = max(0, int((ctx.now - on_since).total_seconds() / 60))
        critical = minutes >= threshold
        detail = (
            f"已开启 {_format_minutes(minutes)}，正在持续耗电"
            if critical
            else f"已开启 {_format_minutes(minutes)}"
        )
        return Alert(
            kind=self.kind,
            title="哨兵模式开启中",
            detail=detail,
            severity=AlertSeverity.CRITICAL if critical else AlertSeverity.INFO,
            primary_action_label="关闭哨兵" if critical else None,
        )


class CabinOverheatAutomation(Automation):
    """座舱过热保护 — info-only; the car is already mitigating."""

    kind = AlertKind.CABIN_OVERHEAT
    state_key = "cabinOverheat:startedAt"

    def evaluate(self, ctx: AutomationContext) -> Optional[Alert]:
        is_on = bool(
            ctx.vehicle_state and ctx.vehicle_state.cabin_overheat_protection_on
        )
        recorded = ctx.memory.get(self.state_key)

        if is_on and recorded is None:
            ctx.memory.set(self.state_key, ctx.now)
        elif not is_on and recorded is not None:
            ctx.memory.set(self.state_key, None)

        if not is_on:
            return None
        on_since = ctx.memory.get(self.state_key)
        if on_since is None:
            return None
        threshold = ctx.settings.cabin_overheat_reminder_minutes
        if threshold <= 0:
            return None

        minutes = max(0, int((ctx.now - on_since).total_seconds() / 60))
        if minutes < threshold:
            return None

        return Alert(
            kind=self.kind,
            title="座舱过热保护已启动",
            detail=f"已运行 {_format_minutes(minutes)}，车辆正在自动通风/降温",
            severity=AlertSeverity.INFO,
            primary_action_label=None,
        )


class ChargeCompleteAutomation(Automation):
    """Event-triggered: fires on Charging → Complete transition.

    Two memory keys:
      - firstSeenAt: when we first saw Complete (cleared on session end)
      - dismissedAt: set after user taps "我知道了" — suppresses re-fire
        until the chargingState leaves Complete (then both are wiped
        and a fresh plug-in re-arms the alert).
    """

    kind = AlertKind.CHARGE_COMPLETE
    first_seen_key = "chargeComplete:firstSeenAt"
    dismissed_key = "chargeComplete:dismissedAt"

    def evaluate(self, ctx: AutomationContext) -> Optional[Alert]:
        if not ctx.settings.charge_complete_reminder_enabled:
            return None

        is_complete = bool(
            ctx.vehicle_state and ctx.vehicle_state.charging_state == "Complete"
        )

        if not is_complete:
            if ctx.memory.get(self.first_seen_key) is not None:
                ctx.memory.set(self.first_seen_key, None)
            ctx.memory.set(self.dismissed_key, None)
            return None

        if ctx.memory.get(self.dismissed_key) is not None:
            return None

        if ctx.memory.get(self.first_seen_key) is None:
            ctx.memory.set(self.first_seen_key, ctx.now)

        soc = ctx.vehicle_state.battery_level if ctx.vehicle_state else 0
        return Alert(
            kind=self.kind,
            title="充电已完成",
            detail=f"电量 {soc or 0}%，可拔枪了",
            severity=AlertSeverity.CRITICAL,
            primary_action_label="我知道了",
        )


def all_rules() -> list[Automation]:
    """The default registry. The polling loop instantiates these once
    and reuses them across ticks (rules are stateless; their per-tick
    state lives in StateMemory)."""
    return [
        CampModeAutomation(),
        SentryModeAutomation(),
        CabinOverheatAutomation(),
        ChargeCompleteAutomation(),
    ]
