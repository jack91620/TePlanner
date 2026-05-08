"""Automation rule CRUD + capability introspection endpoints.

Phase 10.3.A. The visual builder (Phase 10.3.C) is the primary
consumer; the polling loop already loads rules directly from the DB
via app/services/automation/engine.load_user_rules.

Schema notes:
- `spec` is the JSON rule body — same shape iOS evaluates on the
  client (Sources/TePlannerKit/Automations/Interpreters/RuleSpec.swift).
- Presets are seeded lazily on first GET if the user has no rules.
- Preset rules can be enabled / disabled / threshold-tweaked but not
  deleted; the visual builder's delete button hides for them.
"""

from __future__ import annotations

import json
import logging
import uuid
from datetime import datetime
from typing import Any, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user, get_db
from app.db.models import AutomationRule, AutomationState, User, Vehicle
from app.services.automation.engine import ensure_presets_seeded
from app.services.capabilities import all_capabilities

logger = logging.getLogger(__name__)
router = APIRouter()


# ---------------------------------------------------------------------------
# Pydantic schemas

class RuleResponse(BaseModel):
    id: str
    preset_id: Optional[str]
    name: str
    enabled: bool
    spec: dict
    version: int
    updated_at: Optional[datetime] = None
    # Phase 11.x — last time this rule fired a push notification.
    # Read from the PushedAlert ledger keyed by `kind`. iOS shows
    # "上次触发: X 时间前" in the rule detail page. None if never
    # fired (or kind not yet pushed for this user / vehicle).
    last_fired_at: Optional[datetime] = None


class RuleListResponse(BaseModel):
    rules: list[RuleResponse]


class RuleCreateRequest(BaseModel):
    name: str = Field(..., max_length=128)
    enabled: bool = True
    spec: dict


class RuleUpdateRequest(BaseModel):
    name: Optional[str] = Field(None, max_length=128)
    enabled: Optional[bool] = None
    spec: Optional[dict] = None


def _row_to_response(
    row: AutomationRule,
    last_fired_at: Optional[datetime] = None,
) -> RuleResponse:
    return RuleResponse(
        id=row.id,
        preset_id=row.preset_id,
        name=row.name,
        enabled=row.enabled,
        spec=json.loads(row.spec_json),
        version=row.version,
        updated_at=row.updated_at,
        last_fired_at=last_fired_at,
    )


def _validate_spec(spec: dict) -> Optional[str]:
    """Return None if spec looks well-formed; otherwise an error string.
    Cheap structural check only — full validation happens at evaluate
    time. Visual builder does its own client-side validation.
    """
    if "kind" not in spec or not isinstance(spec["kind"], str):
        return "spec.kind must be a string"
    trigger = spec.get("trigger")
    if not isinstance(trigger, dict) or "type" not in trigger:
        return "spec.trigger must be an object with a 'type' field"
    t_type = trigger["type"]
    if t_type == "state_duration":
        for required in ("entity", "equals", "for_minutes", "state_key"):
            if required not in trigger:
                return f"state_duration trigger missing '{required}'"
    elif t_type == "state_transition":
        for required in ("entity", "to", "first_seen_key", "dismissed_key"):
            if required not in trigger:
                return f"state_transition trigger missing '{required}'"
    elif t_type == "cron":
        if "expr" not in trigger:
            return "cron trigger missing 'expr'"
    else:
        return f"unsupported trigger type: {t_type}"
    return None


# ---------------------------------------------------------------------------
# Endpoints

@router.get("/", response_model=RuleListResponse)
async def list_rules(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> RuleListResponse:
    """List all of the user's rules. Lazy-seeds the presets on
    first call (when user has zero rules). Order is canonical: each
    preset in its ALL_PRESETS-declared position, user-authored rules
    after, by creation time. Each rule includes ``last_fired_at`` —
    the most recent PushedAlert.pushed_at for that rule's kind."""
    await ensure_presets_seeded(db, user.id)
    stmt = select(AutomationRule).where(AutomationRule.user_id == user.id)
    rows = (await db.execute(stmt)).scalars().all()
    from app.services.automation.engine import _sort_rules_canonically
    rows = _sort_rules_canonically(rows)
    last_fired = await _last_fired_per_kind(db, user.id)
    return RuleListResponse(rules=[
        _row_to_response(r, last_fired_at=last_fired.get(_kind_of(r)))
        for r in rows
    ])


def _kind_of(rule: AutomationRule) -> str:
    """Pull `kind` out of the rule's spec JSON. Stored at the top
    level of the spec dict; mirrors how the engine consumes it."""
    try:
        spec = json.loads(rule.spec_json)
    except (json.JSONDecodeError, TypeError):
        return ""
    val = spec.get("kind")
    return val if isinstance(val, str) else ""


async def _last_fired_per_kind(
    db: AsyncSession, user_id: int,
) -> dict[str, datetime]:
    """Bulk-load the most recent ``PushedAlert.pushed_at`` per
    AlertKind for one user. iOS surfaces this as "上次触发: X 时间前"
    on each rule. Cheaper than a per-rule join — this is one indexed
    scan with GROUP BY MAX.
    """
    from sqlalchemy import func
    from app.db.models import PushedAlert

    stmt = (
        select(
            PushedAlert.kind,
            func.max(PushedAlert.pushed_at).label("most_recent"),
        )
        .where(PushedAlert.user_id == user_id)
        .group_by(PushedAlert.kind)
    )
    result = (await db.execute(stmt)).all()
    return {row.kind: row.most_recent for row in result if row.most_recent is not None}


@router.post("/", response_model=RuleResponse, status_code=status.HTTP_201_CREATED)
async def create_rule(
    request: RuleCreateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> RuleResponse:
    err = _validate_spec(request.spec)
    if err:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=err
        )
    row = AutomationRule(
        id=str(uuid.uuid4()),
        user_id=user.id,
        preset_id=None,  # user-authored rules have no preset_id
        name=request.name,
        enabled=request.enabled,
        spec_json=json.dumps(request.spec, ensure_ascii=False),
        version=1,
    )
    db.add(row)
    await db.flush()
    logger.info("user %s created rule %s", user.id, row.id)
    return _row_to_response(row)


@router.put("/{rule_id}", response_model=RuleResponse)
async def update_rule(
    rule_id: str,
    request: RuleUpdateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> RuleResponse:
    stmt = select(AutomationRule).where(
        AutomationRule.id == rule_id,
        AutomationRule.user_id == user.id,
    )
    row = (await db.execute(stmt)).scalar_one_or_none()
    if row is None:
        raise HTTPException(404, "rule not found")

    if request.spec is not None:
        err = _validate_spec(request.spec)
        if err:
            raise HTTPException(400, err)
        row.spec_json = json.dumps(request.spec, ensure_ascii=False)
        row.version += 1
    if request.name is not None:
        row.name = request.name
    if request.enabled is not None:
        row.enabled = request.enabled
    await db.flush()
    logger.info("user %s updated rule %s (version=%s)", user.id, row.id, row.version)
    return _row_to_response(row)


@router.delete("/{rule_id}")
async def delete_rule(
    rule_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    stmt = select(AutomationRule).where(
        AutomationRule.id == rule_id,
        AutomationRule.user_id == user.id,
    )
    row = (await db.execute(stmt)).scalar_one_or_none()
    if row is None:
        raise HTTPException(404, "rule not found")
    if row.preset_id is not None:
        raise HTTPException(
            400,
            "preset rules cannot be deleted; disable them instead",
        )
    await db.delete(row)
    await db.flush()
    logger.info("user %s deleted rule %s", user.id, rule_id)
    return {"success": True, "deleted": rule_id}


@router.get("/capabilities")
async def list_capabilities() -> dict[str, list[dict]]:
    """Registry introspection. iOS visual builder calls this once at
    boot to populate the action-block picker.
    """
    return {"capabilities": [c.describe() for c in all_capabilities()]}


# ---------------------------------------------------------------------------
# Phase 5 — telemetry-derived state for iOS

class TelemetryStateEntry(BaseModel):
    """One ``tel:<entity>:since`` + value pair from automation_state."""
    entity: str
    value: Optional[Any]
    since: datetime


class TelemetryStateResponse(BaseModel):
    vehicle_id: Optional[str]
    entries: list[TelemetryStateEntry]


@router.get("/state", response_model=TelemetryStateResponse)
async def get_telemetry_state(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> TelemetryStateResponse:
    """Return the user's telemetry-recorded entity state — the ``tel:*``
    rows the Fleet Telemetry consumer writes into automation_state.

    iOS calls this on each polling tick, before evaluating rules, and
    seeds the local engine memory with the server's ``since`` timestamps.
    The interpreter then prefers the earlier of (locally observed,
    server telemetry) when computing duration. That's what closes the
    "已开启 0 分钟" gap: the iOS HubView pill now reports the same
    elapsed time the server reports in push notifications.
    """
    veh_stmt = (
        select(Vehicle)
        .where(Vehicle.user_id == user.id)
        .order_by(Vehicle.id.desc())
        .limit(1)
    )
    vehicle = (await db.execute(veh_stmt)).scalars().first()
    if vehicle is None:
        return TelemetryStateResponse(vehicle_id=None, entries=[])

    state_stmt = select(AutomationState).where(
        AutomationState.user_id == user.id,
        AutomationState.vehicle_id == vehicle.vin,
        AutomationState.key.like("tel:%:since"),
    )
    since_rows = (await db.execute(state_stmt)).scalars().all()

    entries: list[TelemetryStateEntry] = []
    for row in since_rows:
        # Key shape: tel:<entity>:since  →  entity is everything between.
        if not row.value:
            continue
        try:
            since = datetime.fromisoformat(row.value)
        except ValueError:
            continue
        if not (row.key.startswith("tel:") and row.key.endswith(":since")):
            continue
        entity = row.key[4:-6]  # strip prefix/suffix

        # Pair with the value row if present.
        value_stmt = select(AutomationState).where(
            AutomationState.user_id == user.id,
            AutomationState.vehicle_id == vehicle.vin,
            AutomationState.key == f"tel:{entity}:value",
        )
        value_row = (await db.execute(value_stmt)).scalars().first()
        decoded_value: Optional[Any] = None
        if value_row and value_row.value:
            try:
                decoded_value = json.loads(value_row.value)
            except (json.JSONDecodeError, TypeError):
                decoded_value = value_row.value

        entries.append(TelemetryStateEntry(
            entity=entity, value=decoded_value, since=since,
        ))

    return TelemetryStateResponse(
        vehicle_id=vehicle.vin, entries=entries,
    )
