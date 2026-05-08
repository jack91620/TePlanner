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
}


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
    expected = trigger["equals"]
    threshold = int(trigger["for_minutes"])
    state_key = trigger["state_key"]

    actual = _read_entity(ctx.vehicle_state, entity)
    is_on = (actual == expected)
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

    minutes = max(0, int((ctx.now - on_since).total_seconds() / 60))
    facts = {"duration_human": _format_minutes(minutes), "duration_minutes": minutes}

    above = minutes >= threshold
    bucket = spec.get("actions_above" if above else "actions_below", [])
    if not bucket:
        return None
    # Take first action — multi-action sequences are Phase 10.3.
    return _emit_action(bucket[0], kind, facts)


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
    return None
