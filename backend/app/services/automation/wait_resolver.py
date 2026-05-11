"""Phase 11 — state-gated wait actions.

Rules with a ``wait_for_state`` action don't fire all their actions
inline. Instead, we serialize the predicate + chained ``then`` action
into a ``PendingWait`` row when the rule first triggers. On every
subsequent engine eval (telemetry-driven or cron-tick), we walk the
unresolved rows for the (user, vehicle) and:

  * predicate match → evaluate ``then`` (notify) → emit the alert,
    stamp ``resolved_at``.
  * elapsed > deadline → stamp ``timed_out_at``, no alert.

V1 supports a single common shape::

    {"type": "wait_for_state",
     "predicate": {"entity": "vehicle.inside_temp_c",
                   "op": ">=", "value": 20},
     "then": {"type": "notify", "title": "预热完成",
              "body": "舱内已达 {entity_value}°C"},
     "timeout_minutes": 15}

``op`` ∈ ``==``, ``!=``, ``<``, ``<=``, ``>``, ``>=``. Numeric ops
coerce to float when both sides are numeric; equality also handles
strings/booleans.

Nested ``then`` invoke actions are intentionally out of scope for
v1 — keep the surface small until we have a real preset that wants
to chain VCP commands behind a wait gate.
"""

from __future__ import annotations

import json
import logging
from datetime import datetime, timedelta, timezone
from typing import Any, List, Optional

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import PendingWait
from app.services.automation.base import (
    Alert,
    AlertKind,
    AlertSeverity,
    VehicleStateSnapshot,
)

logger = logging.getLogger(__name__)


_ENTITY_TO_FIELD = {
    "vehicle.climate.keeper_mode": "climate_keeper_mode",
    "vehicle.sentry_mode_on": "sentry_mode_on",
    "vehicle.cabin_overheat_protection_on": "cabin_overheat_protection_on",
    "vehicle.charging.state": "charging_state",
    "vehicle.battery_level": "battery_level",
    "vehicle.locked": "locked",
    "vehicle.shift_state": "shift_state",
    "vehicle.connectivity": "connectivity",
    "vehicle.inside_temp_c": "inside_temp_c",
    "vehicle.outside_temp_c": "outside_temp_c",
    "vehicle.speed_kmh": "speed_kmh",
    "vehicle.charger_power_kw": "charger_power_kw",
    "vehicle.location.latitude": "latitude",
    "vehicle.location.longitude": "longitude",
}


def _read_entity(snap: VehicleStateSnapshot, entity: str) -> Any:
    field = _ENTITY_TO_FIELD.get(entity)
    if field is None:
        return None
    return getattr(snap, field, None)


def _check_predicate(snap: VehicleStateSnapshot, predicate: dict) -> bool:
    entity = predicate.get("entity")
    op = predicate.get("op", "==")
    target = predicate.get("value")
    if not isinstance(entity, str) or target is None:
        return False
    actual = _read_entity(snap, entity)
    if actual is None:
        return False
    if op == "==":
        return actual == target
    if op == "!=":
        return actual != target
    try:
        a = float(actual)
        t = float(target)
    except (TypeError, ValueError):
        return False
    if op == "<":  return a < t
    if op == ">":  return a > t
    if op == "<=": return a <= t
    if op == ">=": return a >= t
    return False


async def enqueue_wait(
    db: AsyncSession,
    *,
    user_id: int,
    vehicle_id: str,
    rule_id: Optional[str],
    predicate: dict,
    then_action: dict,
    timeout_minutes: int = 15,
    now: Optional[datetime] = None,
) -> PendingWait:
    """Write a new pending_wait row, superseding any prior unresolved
    row for the same (rule, user, vehicle) — only one wait per rule
    is in flight at a time."""
    if now is None:
        now = datetime.utcnow()
    elif now.tzinfo is not None:
        now = now.replace(tzinfo=None)

    if rule_id is not None:
        stmt = select(PendingWait).where(
            PendingWait.user_id == user_id,
            PendingWait.vehicle_id == vehicle_id,
            PendingWait.rule_id == rule_id,
            PendingWait.resolved_at.is_(None),
            PendingWait.timed_out_at.is_(None),
        )
        for stale in (await db.execute(stmt)).scalars().all():
            stale.timed_out_at = now

    row = PendingWait(
        user_id=user_id,
        vehicle_id=vehicle_id,
        rule_id=rule_id,
        predicate_json=json.dumps(predicate),
        then_action_json=json.dumps(then_action),
        deadline_at=now + timedelta(minutes=timeout_minutes),
        created_at=now,
    )
    db.add(row)
    await db.flush()
    logger.info(
        "pending_wait queued user=%s vin=%s rule=%s predicate=%s timeout=%sm",
        user_id, vehicle_id, rule_id, predicate, timeout_minutes,
    )
    return row


def _format_then_alert(
    then_action: dict, snap: VehicleStateSnapshot, predicate: dict,
) -> Optional[Alert]:
    if then_action.get("type") != "notify":
        # v1: only notify is supported as the chained action
        return None
    title = then_action.get("title", "")
    body = then_action.get("body", "")
    severity_raw = then_action.get("severity", "info")

    # Substitute {entity_value} from the predicate's resolved entity.
    entity = predicate.get("entity")
    if isinstance(entity, str):
        actual = _read_entity(snap, entity)
        if actual is not None:
            substitution = (
                f"{actual:.1f}" if isinstance(actual, float) else str(actual)
            )
            title = title.replace("{entity_value}", substitution)
            body = body.replace("{entity_value}", substitution)

    try:
        severity = AlertSeverity(severity_raw)
    except ValueError:
        severity = AlertSeverity.INFO

    kind_raw = then_action.get("kind")
    try:
        kind = AlertKind(kind_raw) if kind_raw else AlertKind.WAIT_RESOLVED
    except ValueError:
        logger.warning("wait_resolver: unknown then.kind=%r, using WAIT_RESOLVED", kind_raw)
        kind = AlertKind.WAIT_RESOLVED

    return Alert(
        kind=kind,
        title=title,
        detail=body,
        severity=severity,
        primary_action_label=None,
    )


async def check_and_resolve(
    db: AsyncSession,
    *,
    user_id: int,
    vehicle_id: str,
    snap: Optional[VehicleStateSnapshot],
    now: Optional[datetime] = None,
) -> List[Alert]:
    """Walk every unresolved pending_wait for one (user, vehicle).
    Resolve any whose predicate matches; mark timed-out any past
    deadline. Returns the alerts the resolver fires (caller appends
    to TickResult.alerts).
    """
    if now is None:
        now = datetime.utcnow()
    elif now.tzinfo is not None:
        now = now.replace(tzinfo=None)

    stmt = select(PendingWait).where(
        PendingWait.user_id == user_id,
        PendingWait.vehicle_id == vehicle_id,
        PendingWait.resolved_at.is_(None),
        PendingWait.timed_out_at.is_(None),
    )
    rows = (await db.execute(stmt)).scalars().all()
    if not rows:
        return []

    fired: List[Alert] = []
    for row in rows:
        try:
            predicate = json.loads(row.predicate_json or "{}")
            then_action = json.loads(row.then_action_json or "{}")
        except (json.JSONDecodeError, TypeError):
            # Bad serialization — single-session attribute set is fine
            # since this is a permanent fail-state, not a race-prone
            # transition. (Idempotent: any session converges to the
            # same timed-out marker.)
            row.timed_out_at = now
            continue

        if snap is not None and _check_predicate(snap, predicate):
            # 2026-05-11 race fix: SELECT-then-set-attribute let two
            # concurrent sessions (cron tick + telemetry consumer)
            # both find this row unresolved AND both emit the alert
            # → 2 pushes. Atomic claim instead: UPDATE returns
            # rowcount=0 if another session already resolved this row.
            # SQLite WAL serializes writes; the loser sees the new
            # resolved_at and skips.
            claim = await db.execute(
                update(PendingWait)
                .where(PendingWait.id == row.id)
                .where(PendingWait.resolved_at.is_(None))
                .values(resolved_at=now)
            )
            if claim.rowcount == 0:
                logger.info(
                    "pending_wait race-lost (another session resolved): "
                    "id=%s user=%s vin=%s",
                    row.id, user_id, vehicle_id,
                )
                continue
            alert = _format_then_alert(then_action, snap, predicate)
            if alert is not None:
                fired.append(alert)
            logger.info(
                "pending_wait resolved user=%s vin=%s rule=%s",
                user_id, vehicle_id, row.rule_id,
            )
            continue

        if now >= row.deadline_at:
            # Same atomic-claim pattern for the timeout transition;
            # cheaper since no alert is emitted on timeout, but still
            # avoids racing the resolved-by-another-session path above.
            await db.execute(
                update(PendingWait)
                .where(PendingWait.id == row.id)
                .where(PendingWait.resolved_at.is_(None))
                .where(PendingWait.timed_out_at.is_(None))
                .values(timed_out_at=now)
            )
            logger.info(
                "pending_wait timed out user=%s vin=%s rule=%s",
                user_id, vehicle_id, row.rule_id,
            )

    return fired
