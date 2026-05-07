"""Automation engine: per-tick orchestration.

Lifecycle of one tick (one user, one vehicle):
  1. polling layer fetches /vehicles/{id}/state and builds VehicleStateSnapshot
  2. engine.run_for_vehicle(...) is called
  3. each rule evaluates; rules write to a SqlStateMemory backed by AutomationState
  4. engine compares each rule's resulting severity against PushedAlert ledger:
        new critical → fire APNs to all the user's device tokens, ledger row
        was-critical-now-resolved → mark cleared_at on ledger row
        no transition → no-op
  5. all DB writes commit at end of tick
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import List, Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import AutomationState, DeviceToken, PushedAlert
from app.services.apns import apns_client
from app.services.automation.base import (
    Alert,
    AlertKind,
    AlertSeverity,
    Automation,
    AutomationContext,
    AutomationSettings,
    StateMemory,
    VehicleStateSnapshot,
    utc_now,
)
from app.services.automation.rules import all_rules

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
        # Sync interface (matches Protocol). Loading is async, so callers
        # must `await preload()` first; we assert here to surface bugs.
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
            stmt = select(AutomationState).where(
                AutomationState.user_id == self.user_id,
                AutomationState.vehicle_id == self.vehicle_id,
                AutomationState.key == key,
            )
            existing = (await self.db.execute(stmt)).scalar_one_or_none()
            if existing:
                existing.value = iso
                existing.updated_at = utc_now().replace(tzinfo=None)
            else:
                self.db.add(AutomationState(
                    user_id=self.user_id,
                    vehicle_id=self.vehicle_id,
                    key=key,
                    value=iso,
                ))
        self._dirty.clear()


@dataclass
class TickResult:
    alerts: List[Alert]
    pushed_count: int
    cleared_count: int


class AutomationEngine:
    def __init__(self, rules: Optional[List[Automation]] = None):
        self.rules = rules if rules is not None else all_rules()

    async def run_for_vehicle(
        self,
        db: AsyncSession,
        user_id: int,
        vehicle_id: str,
        state: Optional[VehicleStateSnapshot],
        settings: AutomationSettings,
        push: bool = True,
    ) -> TickResult:
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

        for rule in self.rules:
            alert = rule.evaluate(ctx)
            if alert is not None:
                alerts.append(alert)
            transition = await self._resolve_transition(
                db, user_id, vehicle_id, rule.kind, alert
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
        """Compare current rule output against the PushedAlert ledger
        for this (user, vehicle, kind). Returns one of:
          - "newly_critical": now critical, no active ledger row → push + add row
          - "cleared":         had active ledger row, now resolved → mark cleared
          - "noop":             no transition needed
        """
        stmt = select(PushedAlert).where(
            PushedAlert.user_id == user_id,
            PushedAlert.vehicle_id == vehicle_id,
            PushedAlert.kind == kind.value,
            PushedAlert.cleared_at.is_(None),
        )
        active = (await db.execute(stmt)).scalar_one_or_none()
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
