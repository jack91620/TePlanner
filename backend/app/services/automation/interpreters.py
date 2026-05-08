"""Generic declarative-rule interpreter (Phase 10.2).

Promoted from `spike_interpreter.py` after the parity gate cleared
14/14 in commit 80b5757. The engine now consumes user-authored rule
docs through this module; the old per-class rules in `rules.py` are
gone.

Schema (drives the iOS Swift port too — matching templates and
trigger semantics is what keeps APNs and live UI saying the same
thing):

  STATE_DURATION trigger
    - entity: dotted path into VehicleStateSnapshot
    - equals: value the entity must hold
    - for_minutes: threshold (>0); 0 disables the rule entirely
    - state_key: scratchpad key; rule writes startedAt here
    - actions_below: list of actions to emit while elapsed < threshold
                     (Camp/Sentry: info-only "已开启 X"; Cabin: empty)
    - actions_above: list of actions emitted once elapsed >= threshold
                     (Camp: critical with 关闭; Cabin: info still)

  STATE_TRANSITION trigger
    - entity: dotted path
    - to: value the entity must hold to fire (e.g. "Complete")
    - first_seen_key / dismissed_key: scratchpad keys
    - reset_when_not_to: clear both keys when entity != to
    - actions: emitted on first sighting until dismissed

  Actions: notify | notify_and_offer | dismiss-on-action (synthetic)
  Templates use {duration_human}, {battery_level} substitutions.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import timedelta, timezone
from typing import Any, Optional

from app.services.automation.base import (
    Alert,
    AlertKind,
    AlertSeverity,
    AutomationContext,
)


# ---------------------------------------------------------------------------
# Entity resolution — JSONPath-ish for VehicleStateSnapshot.

_ENTITY_MAP = {
    "vehicle.climate.keeper_mode": "climate_keeper_mode",
    "vehicle.sentry_mode_on": "sentry_mode_on",
    "vehicle.cabin_overheat_protection_on": "cabin_overheat_protection_on",
    "vehicle.charging.state": "charging_state",
    "vehicle.battery_level": "battery_level",
    # Slice A — security / closure derived states.
    # Use the parked_* virtual entities so rules naturally filter
    # out the "I'm sitting in the car with door open" false positives.
    "vehicle.locked": "locked",
    "vehicle.parked_unlocked": "parked_unlocked",
    "vehicle.parked_with_door_open": "parked_with_door_open",
    "vehicle.parked_with_window_open": "parked_with_window_open",
    "vehicle.parked_with_frunk_open": "parked_with_frunk_open",
    "vehicle.parked_with_trunk_open": "parked_with_trunk_open",
}


def _matches(actual: Any, op: str, trigger: dict) -> bool:
    """Slice B: state_duration may compare with a numeric operator
    (``<``, ``>``, ``<=``, ``>=``) instead of the default equality.
    For backward compat, ``==`` reads the trigger's `equals` field
    while numeric ops read `value` (falling back to `equals` if a
    rule still uses the old shape).
    """
    if op == "==":
        return actual == trigger.get("equals")
    if op == "!=":
        return actual is not None and actual != trigger.get("equals")
    threshold = trigger.get("value", trigger.get("equals"))
    if actual is None or threshold is None:
        return False
    try:
        a = float(actual)
        t = float(threshold)
    except (TypeError, ValueError):
        return False
    if op == "<":  return a < t
    if op == ">":  return a > t
    if op == "<=": return a <= t
    if op == ">=": return a >= t
    return False


def _read_entity(state, entity: str) -> Any:
    """Read a dotted entity path off a VehicleStateSnapshot.

    Spike-grade: hardcoded mapping. Production version moves this to
    a registry that brand-integrations register into.
    """
    if state is None:
        return None
    attr = _ENTITY_MAP.get(entity)
    if attr is None:
        return None
    return getattr(state, attr, None)


# ---------------------------------------------------------------------------
# Template rendering.

def _format_minutes(minutes: int) -> str:
    # Mirror Swift formatMinutes — show "不到 1 分钟" instead of "0 分钟"
    # because the rule may evaluate the instant we first observe the
    # condition (delta = 0).
    if minutes < 1:
        return "不到 1 分钟"
    if minutes < 60:
        return f"{minutes} 分钟"
    hours = minutes // 60
    rem = minutes % 60
    return f"{hours} 小时" if rem == 0 else f"{hours} 小时 {rem} 分钟"


def _render(template: str, facts: dict) -> str:
    out = template
    for k, v in facts.items():
        out = out.replace("{" + k + "}", str(v))
    return out


# ---------------------------------------------------------------------------
# Action emission. Returns Alert | None.

def _emit_action(action: dict, kind: AlertKind, facts: dict) -> Optional[Alert]:
    a_type = action["type"]
    title = _render(action.get("title", ""), facts)
    body = _render(action.get("body", ""), facts)

    if a_type == "notify":
        return Alert(
            kind=kind,
            title=title,
            detail=body,
            severity=AlertSeverity(action.get("severity", "info")),
            primary_action_label=None,
        )
    if a_type == "notify_and_offer":
        return Alert(
            kind=kind,
            title=title,
            detail=body,
            severity=AlertSeverity(action.get("severity", "critical")),
            primary_action_label=action.get("primary_action_label"),
        )
    return None


# ---------------------------------------------------------------------------
# Trigger evaluators.

def _eval_state_duration(spec: dict, ctx: AutomationContext, kind: AlertKind) -> Optional[Alert]:
    trigger = spec["trigger"]
    entity = trigger["entity"]
    op = trigger.get("op", "==")
    threshold = int(trigger["for_minutes"])
    state_key = trigger["state_key"]

    actual = _read_entity(ctx.vehicle_state, entity)
    is_on = _matches(actual, op, trigger)
    recorded = ctx.memory.get(state_key)

    # Memory bookkeeping: open / close the on-window.
    if is_on and recorded is None:
        ctx.memory.set(state_key, ctx.now)
    elif not is_on and recorded is not None:
        ctx.memory.set(state_key, None)

    if not is_on:
        return None
    if threshold <= 0:
        return None
    on_since = ctx.memory.get(state_key)
    if on_since is None:
        return None

    # Phase 4: prefer fleet-telemetry's transition timestamp when it's
    # earlier than what polling observed. Telemetry pushes within
    # seconds of the actual change; polling can be up to 5 min late
    # (or much later if smart-cadence skipped the tick), so the
    # telemetry-recorded `since` is the truer "started at".
    tel_since = ctx.memory.get(f"tel:{entity}:since")
    if tel_since is not None and tel_since < on_since:
        on_since = tel_since

    minutes = max(0, int((ctx.now - on_since).total_seconds() / 60))
    facts = {"duration_human": _format_minutes(minutes), "duration_minutes": minutes}

    above = minutes >= threshold
    bucket = spec.get("actions_above" if above else "actions_below", [])
    if not bucket:
        return None
    # Take first action — multi-action sequences are Phase 10.3.
    return _emit_action(bucket[0], kind, facts)


def _eval_cron(spec: dict, ctx: AutomationContext, kind: AlertKind) -> Optional[Alert]:
    """Slice C: time-driven trigger. Fires once per matching cron
    minute. Polling tick runs every 5min, so we look back over the
    window since `last_fired_at` (or the last 6min on first run) and
    fire if any cron occurrence falls inside it.
    """
    trigger = spec["trigger"]
    expr = trigger.get("expr")
    if not expr:
        return None
    last_fired_key = trigger.get("last_fired_key", f"cron:{expr}:lastFiredAt")
    tz_name = trigger.get("tz", "Asia/Shanghai")

    try:
        from zoneinfo import ZoneInfo
        from croniter import croniter
    except ImportError:
        # croniter not installed — silently skip cron rules so the
        # rest of the engine keeps working.
        return None

    try:
        local_tz = ZoneInfo(tz_name)
    except Exception:
        local_tz = timezone.utc

    now_local = ctx.now.astimezone(local_tz)
    last_fired = ctx.memory.get(last_fired_key)
    # First run: only look back 6 min (one polling tick + 1min fudge).
    # Otherwise look back since last fire.
    window_start_local = (
        last_fired.astimezone(local_tz) if last_fired
        else now_local - timedelta(minutes=6)
    )
    if window_start_local >= now_local:
        return None

    try:
        cron = croniter(expr, window_start_local)
        next_match = cron.get_next(ret_type=type(now_local))
    except Exception:
        return None
    if next_match > now_local:
        return None

    # We have a match in (window_start, now]. Fire and update last_fired.
    ctx.memory.set(last_fired_key, ctx.now)
    actions = spec.get("actions", [])
    if not actions:
        return None
    facts = {
        "expr": expr,
        "battery_level": _read_entity(ctx.vehicle_state, "vehicle.battery_level") or 0,
    }
    return _emit_action(actions[0], kind, facts)


def _eval_state_transition(spec: dict, ctx: AutomationContext, kind: AlertKind) -> Optional[Alert]:
    trigger = spec["trigger"]
    entity = trigger["entity"]
    target = trigger["to"]
    first_seen_key = trigger["first_seen_key"]
    dismissed_key = trigger["dismissed_key"]
    reset_when_not_to = trigger.get("reset_when_not_to", True)

    actual = _read_entity(ctx.vehicle_state, entity)
    is_target = (actual == target)

    if not is_target:
        if reset_when_not_to:
            if ctx.memory.get(first_seen_key) is not None:
                ctx.memory.set(first_seen_key, None)
            ctx.memory.set(dismissed_key, None)
        return None

    if ctx.memory.get(dismissed_key) is not None:
        return None

    if ctx.memory.get(first_seen_key) is None:
        ctx.memory.set(first_seen_key, ctx.now)

    facts = {
        "battery_level": _read_entity(ctx.vehicle_state, "vehicle.battery_level") or 0,
    }
    actions = spec.get("actions", [])
    if not actions:
        return None
    return _emit_action(actions[0], kind, facts)


# ---------------------------------------------------------------------------
# Top-level: evaluate one declarative rule.

def evaluate_rule(spec: dict, ctx: AutomationContext) -> Optional[Alert]:
    """Evaluate one declarative rule body. `spec` is the JSON rule
    shape — Trigger / actions_above|below for state_duration; Trigger
    / actions for state_transition. Returns Alert or None.
    """
    if not spec.get("enabled", True):
        return None
    kind = AlertKind(spec["kind"])
    trigger_type = spec["trigger"]["type"]
    if trigger_type == "state_duration":
        return _eval_state_duration(spec, ctx, kind)
    if trigger_type == "state_transition":
        return _eval_state_transition(spec, ctx, kind)
    if trigger_type == "cron":
        return _eval_cron(spec, ctx, kind)
    return None
