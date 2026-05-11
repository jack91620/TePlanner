"""Detect the "user got out" event from streaming telemetry.

Pattern (matches what Tesla's own app uses for "you left X open"
alerts): the user puts the car in P, opens a door, gets out, then
closes the door. The door-close event WHILE shift_state is P is the
canonical signal that the user has departed.

We snapshot the vehicle's sticky state at this moment and write a
single ``event:user_departure:at`` row keyed by (user, vehicle).
Rules with a ``user_departure`` trigger consult this row on each
engine tick — fire once per departure event, then ignore until a
new one lands.

This avoids the broken "state_duration N min after parking" pattern
which depends on telemetry continuing to stream while the car
sleeps. Tesla streams for ~5-15 minutes after parking before the
car sleeps; we capture the departure within that window.
"""

from __future__ import annotations

import logging
from datetime import datetime
from typing import Dict, Optional

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import AutomationState

logger = logging.getLogger(__name__)


DEPARTURE_EVENT_KEY = "event:user_departure:at"


class DepartureDetector:
    """Holds per-vehicle prev-frame state needed to detect the
    door-open→door-close transition while parked.
    """

    def __init__(self) -> None:
        # vin → previous door_open value. None means no observation yet.
        self._prev_door_open: Dict[str, Optional[bool]] = {}

    async def observe(
        self,
        db: AsyncSession,
        *,
        user_id: int,
        vehicle_id: str,
        frame_entities: Dict[str, object],
        observed_at: datetime,
        prev_door_open_db: Optional[bool] = None,
    ) -> bool:
        """Inspect one telemetry frame's (entity → value) snapshot.

        Returns True if a departure event was detected and persisted.

        ``frame_entities`` is the dict from ``map_v_payload(data)``;
        only the entities Tesla emitted in this frame are present.
        Missing entities are treated as "no change" (we fall back to
        the in-memory cache for door_open).
        """
        # Door-close edge: door_open is False THIS frame, was True LAST frame.
        new_door_open = frame_entities.get("vehicle.door_open")
        if new_door_open is None:
            return False

        prev = self._prev_door_open.get(vehicle_id)
        if prev is None:
            # Cold start — fall back to caller-supplied DB value if any.
            prev = prev_door_open_db

        # Update cache regardless of departure outcome.
        self._prev_door_open[vehicle_id] = bool(new_door_open)

        if prev is not True or new_door_open is not False:
            return False

        # Door just closed. Confirm we are parked. Try this frame first;
        # fall back to whatever's in the DB (may have been written earlier).
        shift_state = frame_entities.get("vehicle.shift_state")
        if shift_state is None:
            from app.services.telemetry.snapshot import _read_value
            shift_state = await _read_value(
                db, user_id=user_id, vehicle_id=vehicle_id,
                entity="vehicle.shift_state",
            )

        if shift_state != "P":
            return False

        # Departure! Persist the event timestamp; rule engine consults
        # this on next tick.
        await self._write_event(
            db, user_id=user_id, vehicle_id=vehicle_id,
            observed_at=observed_at,
        )
        logger.info(
            "user_departure detected user=%s vin=%s at=%s",
            user_id, vehicle_id, observed_at.isoformat(),
        )
        return True

    async def _write_event(
        self,
        db: AsyncSession,
        *,
        user_id: int,
        vehicle_id: str,
        observed_at: datetime,
    ) -> None:
        """Upsert the departure event timestamp. One row per
        (user, vehicle); each new departure overwrites the previous.
        Rule eval keys on this timestamp to ensure once-per-event firing.
        """
        if observed_at.tzinfo is not None:
            observed_at = observed_at.replace(tzinfo=None)

        stmt = select(AutomationState).where(
            AutomationState.user_id == user_id,
            AutomationState.vehicle_id == vehicle_id,
            AutomationState.key == DEPARTURE_EVENT_KEY,
        )
        existing = (await db.execute(stmt)).scalar_one_or_none()
        # Raw ISO (no JSON quotes) so SqlStateMemory.preload's
        # datetime.fromisoformat parses it cleanly.
        encoded = observed_at.isoformat()
        if existing is None:
            try:
                async with db.begin_nested():
                    db.add(AutomationState(
                        user_id=user_id,
                        vehicle_id=vehicle_id,
                        key=DEPARTURE_EVENT_KEY,
                        value=encoded,
                        updated_at=datetime.utcnow(),
                    ))
            except IntegrityError:
                # Race with another writer — fall through to update.
                existing = (await db.execute(stmt)).scalar_one_or_none()
                if existing is not None:
                    existing.value = encoded
                    existing.updated_at = datetime.utcnow()
        else:
            existing.value = encoded
            existing.updated_at = datetime.utcnow()
