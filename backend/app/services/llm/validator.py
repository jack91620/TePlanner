"""Sanity-check LLM output against the real capability registry.

Why: the LLM might hallucinate a capability id ("tesla.climate.set_heat")
that doesn't exist, or hand us params outside the schema bounds. Either
case would silently fail at runtime — the engine would try to dispatch,
get None from CapabilityRegistry, and never fire. We catch it here so
the user sees "🤖 试了一下，但是接口不认识 'tesla.climate.set_heat'"
instead of a config that just doesn't work.

Approach is conservative: we check what we CAN check cheaply
(capability existence, presence of required-named params for the
ones we know). Full params_schema validation (types, ranges) is
delegated to the create endpoints we already have — they validate
on rule create / hub_action save. So a hallucination that survives
this layer dies one step later with a clear error.
"""

from __future__ import annotations

from typing import Any, Dict, List, Tuple

from app.services.capabilities import all_capabilities, get


def validate_quick_action(payload: Dict[str, Any]) -> List[str]:
    """Returns a list of human-readable error strings; empty when OK."""
    errors: List[str] = []
    name = payload.get("name")
    if not isinstance(name, str) or not name.strip():
        errors.append("快捷操作缺少 name")
    if len((name or "").strip()) > 12:
        errors.append("快捷操作名称过长（≤12 字）")

    cap_id = payload.get("capability")
    if not isinstance(cap_id, str) or not cap_id.strip():
        errors.append("缺少 capability id")
    elif get(cap_id) is None:
        errors.append(f"未知 capability: `{cap_id}`")

    if not isinstance(payload.get("params", {}), dict):
        errors.append("params 必须是 object")
    return errors


def validate_automation_spec(spec: Dict[str, Any]) -> List[str]:
    """Sanity-check the rule spec. Returns a list of issues."""
    errors: List[str] = []
    trigger = spec.get("trigger")
    if not isinstance(trigger, dict):
        errors.append("缺少 trigger")
        return errors

    ttype = trigger.get("type")
    if ttype not in {
        "state_duration", "state_transition", "cron", "geofence",
        "user_departure",
    }:
        errors.append(f"未知 trigger.type: `{ttype}`")

    actions = spec.get("actions")
    if not isinstance(actions, list) or not actions:
        errors.append("actions 必须是非空 list")
        return errors

    for i, act in enumerate(actions):
        if not isinstance(act, dict):
            errors.append(f"action[{i}] 必须是 object")
            continue
        cap_id = act.get("capability")
        if not isinstance(cap_id, str):
            errors.append(f"action[{i}] 缺少 capability id")
        elif get(cap_id) is None:
            errors.append(f"action[{i}] 未知 capability: `{cap_id}`")
    return errors


def known_capability_ids() -> List[str]:
    """For tests + admin endpoints."""
    return sorted(c.id for c in all_capabilities())
