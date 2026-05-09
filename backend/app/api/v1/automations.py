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
from app.db.models import (
    AutomationRule,
    AutomationSnooze,
    AutomationState,
    User,
    Vehicle,
)
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
    # Phase A.2 — user-overrideable display order. NULL means "use the
    # canonical preset/created-at ordering". iOS reads this on each
    # refresh and renders rules in server order.
    display_order: Optional[int] = None


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
        display_order=row.display_order,
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
    elif t_type == "geofence":
        for required in ("lat", "lng", "radius_m", "event", "state_key"):
            if required not in trigger:
                return f"geofence trigger missing '{required}'"
        if trigger.get("event") not in ("enter", "exit"):
            return "geofence trigger 'event' must be 'enter' or 'exit'"
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


# ---------------------------------------------------------------------------
# Phase A.2 — explicit rule ordering.
#
# Sets ``automation_rules.display_order`` for the rule_ids supplied in
# the request. Rules not mentioned keep their current display_order
# (NULL or otherwise) and fall back to the canonical preset/created-at
# order. PUT replaces — pass an empty list with `clear=true` to reset
# all overrides.
#
# ATTENTION ROUTE ORDER: this MUST be registered before PUT /{rule_id}
# below — FastAPI matches by registration order and the parameterized
# route would otherwise swallow `/order` as `rule_id="order"` → 404.

class RuleOrderRequest(BaseModel):
    rule_ids: list[str] = Field(
        ...,
        description=(
            "Ordered list of rule ids. Position in the list becomes "
            "display_order (0 = first). Rules NOT in the list keep "
            "their existing display_order; pass an empty list combined "
            "with `clear=true` to reset all overrides."
        ),
    )
    clear: bool = False


@router.put("/order", response_model=RuleListResponse)
async def reorder_rules(
    body: RuleOrderRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> RuleListResponse:
    """Persist a user-defined display order. Returns the full rule list
    in the new canonical order so iOS can replace its in-memory cache
    in one round-trip.

    All rule_ids must belong to the requesting user; we 404 on the
    first mismatch (defensive — silent skipping would leak existence).
    Duplicates within rule_ids are rejected (400) so position is
    well-defined.
    """
    if len(body.rule_ids) != len(set(body.rule_ids)):
        raise HTTPException(400, "rule_ids contains duplicates")

    if body.rule_ids:
        stmt = select(AutomationRule).where(
            AutomationRule.id.in_(body.rule_ids),
            AutomationRule.user_id == user.id,
        )
        owned = {r.id: r for r in (await db.execute(stmt)).scalars().all()}
        missing = [rid for rid in body.rule_ids if rid not in owned]
        if missing:
            raise HTTPException(404, f"unknown rule(s): {missing}")
        for position, rid in enumerate(body.rule_ids):
            owned[rid].display_order = position

    if body.clear:
        clear_stmt = select(AutomationRule).where(
            AutomationRule.user_id == user.id,
            AutomationRule.id.notin_(body.rule_ids) if body.rule_ids
            else AutomationRule.user_id == user.id,
        )
        for r in (await db.execute(clear_stmt)).scalars().all():
            r.display_order = None

    await db.flush()
    logger.info(
        "user %s reordered %d rule(s) (clear=%s)",
        user.id, len(body.rule_ids), body.clear,
    )

    list_stmt = select(AutomationRule).where(AutomationRule.user_id == user.id)
    rows = (await db.execute(list_stmt)).scalars().all()
    from app.services.automation.engine import _sort_rules_canonically
    rows = _sort_rules_canonically(rows)
    last_fired = await _last_fired_per_kind(db, user.id)
    return RuleListResponse(rules=[
        _row_to_response(r, last_fired_at=last_fired.get(_kind_of(r)))
        for r in rows
    ])


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


class RecentFireEntry(BaseModel):
    kind: str
    pushed_at: datetime
    cleared_at: Optional[datetime] = None


class RecentFiresResponse(BaseModel):
    fires: list[RecentFireEntry]


@router.get("/recent-fires", response_model=RecentFiresResponse)
async def list_recent_fires(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    limit: int = 50,
) -> RecentFiresResponse:
    """Recent rule-fire timeline for the user. Drives the iOS '活动'
    page — answers 'did my露营 rule fire today?' without the user
    having to scrub through notification center.
    """
    from sqlalchemy import desc
    from app.db.models import PushedAlert

    stmt = (
        select(PushedAlert)
        .where(PushedAlert.user_id == user.id)
        .order_by(desc(PushedAlert.pushed_at))
        .limit(limit)
    )
    rows = (await db.execute(stmt)).scalars().all()
    return RecentFiresResponse(fires=[
        RecentFireEntry(kind=r.kind, pushed_at=r.pushed_at, cleared_at=r.cleared_at)
        for r in rows
    ])


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


# ---------------------------------------------------------------------------
# Phase A.1 — snooze API.
#
# A snooze pauses one rule from firing for a window. Engine consults
# automation_snooze on every tick and skips evaluation while the row's
# snoozed_until_utc is in the future. Re-snoozing replaces (UNIQUE on
# rule_id). DELETE clears immediately.

class SnoozeRequest(BaseModel):
    until: Optional[datetime] = None
    hours: Optional[float] = Field(None, gt=0, le=720)
    reason: Optional[str] = Field(None, max_length=128)


class SnoozeResponse(BaseModel):
    rule_id: str
    snoozed_until_utc: datetime
    reason: Optional[str] = None
    created_at: datetime


class SnoozeListResponse(BaseModel):
    snoozes: list[SnoozeResponse]


def _snooze_to_response(row: AutomationSnooze) -> SnoozeResponse:
    return SnoozeResponse(
        rule_id=row.rule_id,
        snoozed_until_utc=row.snoozed_until_utc,
        reason=row.reason,
        created_at=row.created_at,
    )


@router.post("/{rule_id}/snooze", response_model=SnoozeResponse)
async def snooze_rule(
    rule_id: str,
    body: SnoozeRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SnoozeResponse:
    """Snooze ``rule_id`` until ``until`` (absolute UTC) or for ``hours``
    from now. Exactly one of the two must be provided. Replaces any
    existing snooze on that rule (UNIQUE on rule_id).
    """
    if (body.until is None) == (body.hours is None):
        raise HTTPException(400, "provide exactly one of 'until' or 'hours'")

    rule_stmt = select(AutomationRule).where(
        AutomationRule.id == rule_id,
        AutomationRule.user_id == user.id,
    )
    if (await db.execute(rule_stmt)).scalar_one_or_none() is None:
        raise HTTPException(404, "rule not found")

    if body.until is not None:
        until_utc = body.until.replace(tzinfo=None)
    else:
        from datetime import timedelta
        until_utc = datetime.utcnow() + timedelta(hours=float(body.hours))

    if until_utc <= datetime.utcnow():
        raise HTTPException(400, "snooze window must end in the future")

    existing = (await db.execute(
        select(AutomationSnooze).where(AutomationSnooze.rule_id == rule_id)
    )).scalar_one_or_none()

    if existing is not None:
        existing.snoozed_until_utc = until_utc
        existing.reason = body.reason
        existing.user_id = user.id
        row = existing
    else:
        row = AutomationSnooze(
            user_id=user.id,
            rule_id=rule_id,
            snoozed_until_utc=until_utc,
            reason=body.reason,
            created_at=datetime.utcnow(),
        )
        db.add(row)
    await db.flush()
    logger.info(
        "user %s snoozed rule %s until %s (reason=%s)",
        user.id, rule_id, until_utc.isoformat(), body.reason,
    )
    return _snooze_to_response(row)


@router.delete("/{rule_id}/snooze")
async def unsnooze_rule(
    rule_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Clear any active snooze on ``rule_id``. 404 if the rule itself
    doesn't exist; idempotent on a rule with no active snooze."""
    rule_stmt = select(AutomationRule).where(
        AutomationRule.id == rule_id,
        AutomationRule.user_id == user.id,
    )
    if (await db.execute(rule_stmt)).scalar_one_or_none() is None:
        raise HTTPException(404, "rule not found")

    row = (await db.execute(
        select(AutomationSnooze).where(AutomationSnooze.rule_id == rule_id)
    )).scalar_one_or_none()
    if row is not None:
        await db.delete(row)
        await db.flush()
        logger.info("user %s unsnoozed rule %s", user.id, rule_id)
    return {"success": True, "rule_id": rule_id}


@router.get("/snoozes", response_model=SnoozeListResponse)
async def list_snoozes(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SnoozeListResponse:
    """List all active (snoozed_until_utc > now) snoozes for the user.
    Stale rows (past their window) are filtered server-side; the client
    never sees them, so iOS doesn't need to time-check.
    """
    now = datetime.utcnow()
    stmt = (
        select(AutomationSnooze)
        .where(
            AutomationSnooze.user_id == user.id,
            AutomationSnooze.snoozed_until_utc > now,
        )
        .order_by(AutomationSnooze.snoozed_until_utc.asc())
    )
    rows = (await db.execute(stmt)).scalars().all()
    return SnoozeListResponse(snoozes=[_snooze_to_response(r) for r in rows])


