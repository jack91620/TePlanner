"""Persist telemetry-sourced entity values into AutomationState.

The interpreter reads ``tel:<entity>:since`` and uses it as the true
"started at" time for the current value, in preference to the polling-
observation timestamp. We write that key only when the value
*transitions* — same value back-to-back is a no-op so ``since`` keeps
pointing at the original transition.

To detect a transition we need the previous value. SqlStateMemory only
stores datetimes (its ``value`` column is a 64-char string sized for
ISO 8601), so we keep a per-process in-memory cache of last-seen
values. On backend restart the cache is empty; the next telemetry
event for each entity is treated as a fresh transition and resets
``since`` once. That's bounded inaccuracy (one wrong reset per
restart, per entity) — acceptable for v1.
"""

from __future__ import annotations

import json
import logging
from dataclasses import dataclass
from datetime import datetime
from typing import Any, Dict, Optional, Tuple

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import AutomationState, Vehicle

logger = logging.getLogger(__name__)


def telemetry_since_key(entity: str) -> str:
    """The AutomationState row key under which we record `since`."""
    return f"tel:{entity}:since"


def telemetry_value_key(entity: str) -> str:
    """The AutomationState row key under which we record the current
    value (as JSON, so bool/int/str all round-trip).
    """
    return f"tel:{entity}:value"


@dataclass
class TelemetryStateWriter:
    """Stateful writer holding the per-(vehicle, entity) last-seen
    value cache. One instance per consumer process."""

    _last_value: Dict[Tuple[str, str], Any]

    def __init__(self) -> None:
        self._last_value = {}

    async def resolve_user_id(
        self, db: AsyncSession, vin: str
    ) -> Optional[int]:
        """Look up user_id for a VIN. Multiple Vehicle rows can share a
        VIN (one per OAuth login); pick the most recent one — that's
        the user actively running the app and registered for push.
        """
        stmt = (
            select(Vehicle.user_id)
            .where(Vehicle.vin == vin)
            .order_by(Vehicle.id.desc())
            .limit(1)
        )
        return (await db.execute(stmt)).scalar_one_or_none()

    async def record(
        self,
        db: AsyncSession,
        user_id: int,
        vehicle_id: str,
        entity: str,
        value: Any,
        observed_at: datetime,
    ) -> bool:
        """Upsert telemetry state for one (vehicle, entity).

        Returns True if this was a transition (value changed and
        ``since`` was updated), False if the value matched the cached
        previous and nothing was written.
        """
        cache_key = (vehicle_id, entity)
        prev = self._last_value.get(cache_key)

        if prev is None:
            # Cold start — pull last known value from DB so a backend
            # restart doesn't immediately reset every `since`.
            prev = await self._load_cached_value(db, user_id, vehicle_id, entity)
            if prev is not None:
                self._last_value[cache_key] = prev

        if prev == value:
            return False

        self._last_value[cache_key] = value
        await self._upsert_state(
            db, user_id, vehicle_id,
            telemetry_since_key(entity), observed_at.isoformat(),
        )
        await self._upsert_state(
            db, user_id, vehicle_id,
            telemetry_value_key(entity), json.dumps(value),
        )
        logger.info(
            "telemetry transition vehicle=%s entity=%s value=%s since=%s",
            vehicle_id, entity, value, observed_at.isoformat(),
        )
        return True

    async def _load_cached_value(
        self,
        db: AsyncSession,
        user_id: int,
        vehicle_id: str,
        entity: str,
    ) -> Any:
        stmt = select(AutomationState).where(
            AutomationState.user_id == user_id,
            AutomationState.vehicle_id == vehicle_id,
            AutomationState.key == telemetry_value_key(entity),
        )
        row = (await db.execute(stmt)).scalar_one_or_none()
        if row is None or row.value is None:
            return None
        try:
            return json.loads(row.value)
        except (json.JSONDecodeError, TypeError):
            return None

    async def _upsert_state(
        self,
        db: AsyncSession,
        user_id: int,
        vehicle_id: str,
        key: str,
        value: str,
    ) -> None:
        stmt = select(AutomationState).where(
            AutomationState.user_id == user_id,
            AutomationState.vehicle_id == vehicle_id,
            AutomationState.key == key,
        )
        row = (await db.execute(stmt)).scalar_one_or_none()
        if row is None:
            db.add(AutomationState(
                user_id=user_id,
                vehicle_id=vehicle_id,
                key=key,
                value=value,
            ))
        else:
            row.value = value
