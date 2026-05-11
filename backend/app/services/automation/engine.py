"""Automation engine: per-tick orchestration.

Lifecycle of one tick (one user, one vehicle):
  1. polling layer fetches /vehicles/{id}/state and builds VehicleStateSnapshot
  2. engine.run_for_vehicle(...) is called
  3. preset rules are seeded for first-time users (no automation_rules
     rows yet)
  4. rules are loaded from `automation_rules` table; each spec_json is
     parsed and run through `evaluate_rule(spec, ctx)` from interpreters.py
  5. engine compares each rule's resulting severity against PushedAlert ledger:
        new critical → fire APNs to all the user's device tokens, ledger row
        was-critical-now-resolved → mark cleared_at on ledger row
        no transition → no-op
  6. all DB writes commit at end of tick
"""

from __future__ import annotations

import json
import logging
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import List, Optional

from sqlalchemy import select, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import (
    AutomationRule,
    AutomationSnooze,
    AutomationState,
    DeviceToken,
    PushedAlert,
)
from app.services.automation.base import (
    Alert,
    AlertKind,
    AlertSeverity,
    AutomationContext,
    AutomationSettings,
    StateMemory,
    VehicleStateSnapshot,
    utc_now,
)
from app.services.automation.interpreters import evaluate_rule
from app.services.automation.presets import ALL_PRESETS, PresetDefinition

logger = logging.getLogger(__name__)


class SqlStateMemory:
    """Persists rule-state through AutomationState SQLite rows. One
    instance is built per tick (per user+vehicle); flush happens when
    the surrounding transaction commits.
    """

    def __init__(self, db: AsyncSession, user_id: int, vehicle_id: str):
        self.db = db
        self.user_id = user_id
        self.vehicle_id = vehicle_id
        self._cache: dict[str, Optional[datetime]] = {}
        self._dirty: set[str] = set()
        self._loaded = False

    async def _ensure_loaded(self) -> None:
        if self._loaded:
            return
        stmt = select(AutomationState).where(
            AutomationState.user_id == self.user_id,
            AutomationState.vehicle_id == self.vehicle_id,
        )
        rows = (await self.db.execute(stmt)).scalars().all()
        for row in rows:
            # Skip Phase 4's `tel:<entity>:value` rows — those store
            # JSON-encoded scalars (booleans/ints/strings), not ISO
            # datetimes, and would crash fromisoformat. The interpreter
            # reads them via build_snapshot_from_telemetry() instead.
            if row.key.startswith("tel:") and row.key.endswith(":value"):
                continue
            if row.value is None:
                self._cache[row.key] = None
                continue
            try:
                self._cache[row.key] = datetime.fromisoformat(row.value)
            except ValueError:
                # Defensive: any non-datetime value found here is a
                # write bug elsewhere. Skip rather than crash the whole
                # tick — log so we notice.
                logger.warning(
                    "automation_state row key=%s holds non-ISO value, skipping",
                    row.key,
                )
        self._loaded = True

    def get(self, key: str) -> Optional[datetime]:
        if not self._loaded:
            raise RuntimeError("SqlStateMemory.get called before preload()")
        return self._cache.get(key)

    def set(self, key: str, value: Optional[datetime]) -> None:
        if not self._loaded:
            raise RuntimeError("SqlStateMemory.set called before preload()")
        self._cache[key] = value
        self._dirty.add(key)

    async def preload(self) -> "SqlStateMemory":
        await self._ensure_loaded()
        return self

    async def flush(self) -> None:
        if not self._dirty:
            return
        for key in self._dirty:
            value = self._cache.get(key)
            iso = value.isoformat() if value else None
            stmt = (
                select(AutomationState)
                .where(
                    AutomationState.user_id == self.user_id,
                    AutomationState.vehicle_id == self.vehicle_id,
                    AutomationState.key == key,
                )
                .order_by(AutomationState.id.desc())
            )
            rows = (await self.db.execute(stmt)).scalars().all()
            if rows:
                # Self-heal: if duplicates exist (e.g. cross-loop race
                # between polling and telemetry consumer), keep the
                # latest and delete the rest so `scalar_one_or_none`
                # users elsewhere stop blowing up.
                rows[0].value = iso
                rows[0].updated_at = utc_now().replace(tzinfo=None)
                for stale in rows[1:]:
                    await self.db.delete(stale)
                if len(rows) > 1:
                    logger.warning(
                        "automation_state had %s dup rows for key=%s — healed",
                        len(rows), key,
                    )
            else:
                self.db.add(AutomationState(
                    user_id=self.user_id,
                    vehicle_id=self.vehicle_id,
                    key=key,
                    value=iso,
                ))
        self._dirty.clear()


async def ensure_presets_seeded(db: AsyncSession, user_id: int) -> int:
    """Idempotent preset seeding + backfill.

    Behaviour:
    - First call (user has 0 rules): inserts all ALL_PRESETS rows.
    - Subsequent calls: inserts ONLY presets whose preset_id isn't
      already in the user's rules. So adding a new preset_id to the
      ALL_PRESETS list reaches existing users on their next list
      fetch — no schema migration needed.

    All seeded presets default to ``enabled=False`` — both first-time
    and backfill paths. User feedback (2026-05-10): the auto-enabled
    behaviour surprised people with notifications they never opted
    into. The list view's prominent green toggle makes opting in a
    single tap so the cost of the change is low.

    Returns the number of preset rows inserted on this call.
    """
    stmt = select(AutomationRule.preset_id).where(
        AutomationRule.user_id == user_id,
        AutomationRule.preset_id.is_not(None),
    )
    existing_preset_ids = {row[0] for row in (await db.execute(stmt)).all()}
    is_first_seed = not existing_preset_ids

    inserted = 0
    for preset in ALL_PRESETS:
        if preset.preset_id in existing_preset_ids:
            continue
        db.add(AutomationRule(
            id=str(uuid.uuid4()),
            user_id=user_id,
            preset_id=preset.preset_id,
            name=preset.name,
            enabled=False,
            spec_json=json.dumps(preset.spec, ensure_ascii=False),
            version=1,
        ))
        inserted += 1
    if inserted:
        await db.flush()
        if is_first_seed:
            logger.info("seeded %s presets for user %s (first time)", inserted, user_id)
        else:
            logger.info("backfilled %s new presets for user %s", inserted, user_id)
    return inserted


async def load_user_rules(db: AsyncSession, user_id: int) -> list[dict]:
    """Return the list of rule spec dicts for a user (parsed from
    spec_json, only enabled rules). Caller should already have
    seeded presets for first-time users via `ensure_presets_seeded`.

    Ordering is deterministic: presets first, in their canonical
    ALL_PRESETS order; user-authored rules afterwards in
    created_at order. Sorting by ``id`` (UUID string) would scramble
    the list alphabetically and surface differently between sessions.
    """
    stmt = select(AutomationRule).where(
        AutomationRule.user_id == user_id,
        AutomationRule.enabled == True,  # noqa: E712
    )
    rows = (await db.execute(stmt)).scalars().all()
    rows = _sort_rules_canonically(rows)

    parsed: list[dict] = []
    for row in rows:
        try:
            spec = json.loads(row.spec_json)
        except json.JSONDecodeError:
            logger.exception("rule %s has invalid spec_json — skipping", row.id)
            continue
        # Carry the row's enabled / id along for transitions / debugging.
        spec["_rule_id"] = row.id
        spec.setdefault("enabled", True)
        parsed.append(spec)
    return parsed


async def _active_snoozes(
    db: AsyncSession, user_id: int, now: datetime,
) -> set[str]:
    """Return rule_ids whose snoozed_until_utc is still in the future.
    Engine consults this once per tick and skips evaluation for any
    rule in the set — no alert, no side-effect, no transition writes.
    """
    naive_now = now.replace(tzinfo=None) if now.tzinfo is not None else now
    stmt = select(AutomationSnooze.rule_id).where(
        AutomationSnooze.user_id == user_id,
        AutomationSnooze.snoozed_until_utc > naive_now,
    )
    return {r for (r,) in (await db.execute(stmt)).all()}


def _sort_rules_canonically(rows: list[AutomationRule]) -> list[AutomationRule]:
    """Sort order:
      1. Rules with non-NULL ``display_order`` first, ascending. The
         user explicitly placed these via PUT /automations/order.
      2. Then unranked rows in legacy order: presets in ALL_PRESETS
         declaration order; user-authored rules (preset_id NULL) by
         created_at.

    Stable on ties so re-renders don't shuffle.
    """
    preset_order = {p.preset_id: i for i, p in enumerate(ALL_PRESETS)}
    preset_fallback = len(preset_order)

    def key(r: AutomationRule) -> tuple:
        if r.display_order is not None:
            return (0, r.display_order, r.id)
        legacy_bucket = (
            preset_order.get(r.preset_id or "", preset_fallback)
            if r.preset_id is not None else preset_fallback + 1
        )
        return (1, legacy_bucket, r.created_at or datetime.min, r.id)

    return sorted(rows, key=key)


@dataclass
class TickResult:
    alerts: List[Alert]
    pushed_count: int
    cleared_count: int


class AutomationEngine:
    """Stateless engine that fans rule evaluation across one user+vehicle
    tick. State lives in DB rows the engine reads/writes through
    SqlStateMemory + the AutomationRule / PushedAlert tables.
    """

    async def run_for_vehicle(
        self,
        db: AsyncSession,
        user_id: int,
        vehicle_id: str,
        state: Optional[VehicleStateSnapshot],
        settings: AutomationSettings,
        push: bool = True,
    ) -> TickResult:
        await ensure_presets_seeded(db, user_id)
        rules = await load_user_rules(db, user_id)

        memory = await SqlStateMemory(db, user_id, vehicle_id).preload()
        ctx = AutomationContext(
            vehicle_state=state,
            vehicle_id=vehicle_id,
            now=utc_now(),
            settings=settings,
            memory=memory,
        )

        alerts: List[Alert] = []
        pushed_count = 0
        cleared_count = 0

        snoozed_rule_ids = await _active_snoozes(db, user_id, ctx.now)

        for spec in rules:
            try:
                kind = AlertKind(spec["kind"])
            except (KeyError, ValueError):
                logger.warning("rule %s has invalid kind — skipping", spec.get("_rule_id"))
                continue
            rule_id = spec.get("_rule_id")
            if rule_id and rule_id in snoozed_rule_ids:
                continue
            alert = evaluate_rule(spec, ctx)
            if alert is not None:
                alerts.append(alert)
                # Phase 11 — if the rule's primary action is
                # wait_for_state, we record a pending_wait row instead
                # of (or in addition to) firing the alert immediately.
                # The actual notification happens once the predicate
                # matches, via the resolver below.
                await self._maybe_enqueue_wait(
                    db, user_id, vehicle_id, spec, alert,
                )
            transition = await self._resolve_transition(
                db, user_id, vehicle_id, kind, alert
            )
            if transition == "newly_critical" and push and alert is not None:
                ok = await self._push_alert(db, user_id, alert)
                if ok:
                    pushed_count += 1
            elif transition == "cleared":
                cleared_count += 1

        # Phase 11 — resolve any pending_wait rows whose predicate
        # the current snapshot now satisfies (or whose deadline has
        # passed). Resolved rows emit additional alerts which we
        # append to the tick result so push notifications fire.
        from app.services.automation.wait_resolver import (
            check_and_resolve as resolve_waits,
        )
        if state is not None:
            wait_alerts = await resolve_waits(
                db, user_id=user_id, vehicle_id=vehicle_id, snap=state, now=ctx.now,
            )
            for w_alert in wait_alerts:
                alerts.append(w_alert)
                if push:
                    ok = await self._push_alert(db, user_id, w_alert)
                    if ok:
                        pushed_count += 1

        await memory.flush()
        return TickResult(
            alerts=alerts, pushed_count=pushed_count, cleared_count=cleared_count
        )

    async def _maybe_enqueue_wait(
        self,
        db: AsyncSession,
        user_id: int,
        vehicle_id: str,
        spec: dict,
        primary_alert: Alert,
    ) -> None:
        """If the rule's first action (the one that produced the alert)
        is ``wait_for_state``, persist a pending_wait row so the next
        engine tick can fire the chained ``then`` action when the
        predicate matches."""
        # Pull the action the interpreter would have emitted.
        bucket_keys = ("actions_above", "actions_below", "actions")
        action: Optional[dict] = None
        for k in bucket_keys:
            arr = spec.get(k)
            if isinstance(arr, list) and arr:
                if isinstance(arr[0], dict) and arr[0].get("type") == "wait_for_state":
                    action = arr[0]
                    break
        if action is None:
            return
        predicate = action.get("predicate")
        then_action = action.get("then")
        if not isinstance(predicate, dict) or not isinstance(then_action, dict):
            return
        timeout_minutes = int(action.get("timeout_minutes", 15))
        from app.services.automation.wait_resolver import enqueue_wait
        await enqueue_wait(
            db,
            user_id=user_id,
            vehicle_id=vehicle_id,
            rule_id=spec.get("_rule_id"),
            predicate=predicate,
            then_action=then_action,
            timeout_minutes=timeout_minutes,
        )

    async def _resolve_transition(
        self,
        db: AsyncSession,
        user_id: int,
        vehicle_id: str,
        kind: AlertKind,
        alert: Optional[Alert],
    ) -> str:
        # Order by pushed_at desc + use .all() (not scalar_one_or_none)
        # so we self-heal multi-row corruption. Two un-cleared rows
        # for the same (user, vehicle, kind) shouldn't exist, but a
        # crashed mid-tick can leave them. Keep the latest, clear
        # the rest so the ledger collapses back to single-active.
        stmt = (
            select(PushedAlert)
            .where(
                PushedAlert.user_id == user_id,
                PushedAlert.vehicle_id == vehicle_id,
                PushedAlert.kind == kind.value,
                PushedAlert.cleared_at.is_(None),
            )
            .order_by(PushedAlert.pushed_at.desc())
        )
        active_rows = (await db.execute(stmt)).scalars().all()
        active: Optional[PushedAlert] = active_rows[0] if active_rows else None
        if len(active_rows) > 1:
            now_naive = utc_now().replace(tzinfo=None)
            for stale in active_rows[1:]:
                stale.cleared_at = now_naive
            logger.warning(
                "PushedAlert multi-row healed: kept %s, cleared %s duplicates "
                "(user=%s vehicle=%s kind=%s)",
                active.id if active else None,
                len(active_rows) - 1,
                user_id, vehicle_id, kind.value,
            )
        is_critical = alert is not None and alert.severity == AlertSeverity.CRITICAL

        if is_critical and active is None:
            # 2026-05-11: race condition observed — cron tick + telemetry
            # consumer evaluated the same rule concurrently, each in
            # its own session, both SELECTed before the other committed,
            # both INSERTed (136ms apart) → 2 identical 车辆未锁 pushes.
            #
            # Defense layered now:
            #   1. Migration 0008 added a partial UNIQUE index on
            #      (user_id, vehicle_id, kind) WHERE cleared_at IS NULL.
            #      DB enforces "at most 1 active alert per kind" so the
            #      second concurrent INSERT raises IntegrityError.
            #   2. App-level 15-min REPUSH_GUARD: if any (cleared or
            #      not) row is within the window, skip the new INSERT
            #      and re-open the existing one.
            #   3. IntegrityError catch below: if (1) fires anyway
            #      (e.g. the index races against a not-yet-committed
            #      INSERT in the other session), treat as "race lost,
            #      no push, but condition is active".
            from datetime import timedelta
            REPUSH_GUARD = timedelta(minutes=15)
            now_naive = utc_now().replace(tzinfo=None)
            cutoff = now_naive - REPUSH_GUARD
            recent = (await db.execute(
                select(PushedAlert)
                .where(PushedAlert.user_id == user_id)
                .where(PushedAlert.vehicle_id == vehicle_id)
                .where(PushedAlert.kind == kind.value)
                .where(PushedAlert.pushed_at >= cutoff)
                .order_by(PushedAlert.pushed_at.desc())
                .limit(1)
            )).scalar_one_or_none()
            if recent is not None:
                # In-window row exists; re-open instead of pushing.
                recent.cleared_at = None
                logger.info(
                    "PushedAlert re-push suppressed (within %s window): "
                    "user=%s vehicle=%s kind=%s",
                    REPUSH_GUARD, user_id, vehicle_id, kind.value,
                )
                return "noop"
            # No in-window row — try to insert. The partial unique
            # index will reject if a concurrent session beat us.
            # Wrap in a savepoint so an IntegrityError rolls back ONLY
            # the failed insert, not any other writes in the parent
            # transaction (e.g. memory.flush, AutomationState updates).
            try:
                async with db.begin_nested():
                    db.add(PushedAlert(
                        user_id=user_id,
                        vehicle_id=vehicle_id,
                        kind=kind.value,
                    ))
            except IntegrityError:
                logger.info(
                    "PushedAlert insert raced (IntegrityError on partial unique): "
                    "user=%s vehicle=%s kind=%s — winning session pushed, we skip",
                    user_id, vehicle_id, kind.value,
                )
                return "noop"
            return "newly_critical"
        if (not is_critical) and active is not None:
            active.cleared_at = utc_now().replace(tzinfo=None)
            return "cleared"
        return "noop"

    async def _push_alert(
        self, db: AsyncSession, user_id: int, alert: Alert
    ) -> bool:
        # Phase E — route through the multi-platform dispatcher.
        # Per-platform configuration / outage tolerance lives inside
        # each per-platform client; the engine just hands off the alert.
        from app.services.push import push_dispatcher

        summary = await push_dispatcher.send(
            db=db,
            user_id=user_id,
            title=alert.title,
            body=alert.detail,
            category=alert.kind.value,
            thread_id=alert.kind.value,
            custom_data={"alertKind": alert.kind.value},
        )
        if summary.devices == 0:
            logger.info(
                "skip push for user=%s kind=%s (no devices registered)",
                user_id, alert.kind.value,
            )
            return False
        return summary.sent > 0
