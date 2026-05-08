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

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import AutomationRule, AutomationState, DeviceToken, PushedAlert
from app.services.apns import apns_client
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
            self._cache[row.key] = (
                datetime.fromisoformat(row.value) if row.value else None
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
    """If `user_id` has zero automation_rules rows, seed all 4 presets.
    Returns the number of preset rows inserted (0 if user already had
    any rules — including disabled ones).
    """
    stmt = select(AutomationRule).where(AutomationRule.user_id == user_id).limit(1)
    existing = (await db.execute(stmt)).scalar_one_or_none()
    if existing is not None:
        return 0
    for preset in ALL_PRESETS:
        db.add(AutomationRule(
            id=str(uuid.uuid4()),
            user_id=user_id,
            preset_id=preset.preset_id,
            name=preset.name,
            enabled=True,
            spec_json=json.dumps(preset.spec, ensure_ascii=False),
            version=1,
        ))
    await db.flush()
    logger.info("seeded %s presets for user %s", len(ALL_PRESETS), user_id)
    return len(ALL_PRESETS)


async def load_user_rules(db: AsyncSession, user_id: int) -> list[dict]:
    """Return the list of rule spec dicts for a user (parsed from
    spec_json, only enabled rules). Caller should already have
    seeded presets for first-time users via `ensure_presets_seeded`.
    """
    stmt = (
        select(AutomationRule)
        .where(
            AutomationRule.user_id == user_id,
            AutomationRule.enabled == True,  # noqa: E712
        )
        .order_by(AutomationRule.id)
    )
    rows = (await db.execute(stmt)).scalars().all()
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

        for spec in rules:
            try:
                kind = AlertKind(spec["kind"])
            except (KeyError, ValueError):
                logger.warning("rule %s has invalid kind — skipping", spec.get("_rule_id"))
                continue
            alert = evaluate_rule(spec, ctx)
            if alert is not None:
                alerts.append(alert)
            transition = await self._resolve_transition(
                db, user_id, vehicle_id, kind, alert
            )
            if transition == "newly_critical" and push and alert is not None:
                ok = await self._push_alert(db, user_id, alert)
                if ok:
                    pushed_count += 1
            elif transition == "cleared":
                cleared_count += 1

        await memory.flush()
        return TickResult(
            alerts=alerts, pushed_count=pushed_count, cleared_count=cleared_count
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
            db.add(PushedAlert(
                user_id=user_id,
                vehicle_id=vehicle_id,
                kind=kind.value,
            ))
            return "newly_critical"
        if (not is_critical) and active is not None:
            active.cleared_at = utc_now().replace(tzinfo=None)
            return "cleared"
        return "noop"

    async def _push_alert(
        self, db: AsyncSession, user_id: int, alert: Alert
    ) -> bool:
        if not apns_client.configured:
            logger.info(
                "skip APNs push for user=%s kind=%s (APNs not configured)",
                user_id, alert.kind.value,
            )
            return False
        stmt = select(DeviceToken).where(DeviceToken.user_id == user_id)
        tokens = (await db.execute(stmt)).scalars().all()
        if not tokens:
            logger.info(
                "skip APNs push for user=%s kind=%s (no devices registered)",
                user_id, alert.kind.value,
            )
            return False
        any_ok = False
        for entry in tokens:
            ok = await apns_client.send(
                device_token=entry.token,
                title=alert.title,
                body=alert.detail,
                category=alert.kind.value,
                thread_id=alert.kind.value,
                custom_data={"alertKind": alert.kind.value},
            )
            any_ok = any_ok or ok
        return any_ok
