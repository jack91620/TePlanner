"""Open charging sessions server-side when iOS missed the start.

iOS `ChargingSessionTracker` only opens a session row when its
observe() loop catches the chargingState transition into
"Charging" *while the app is foregrounded*. Most charges happen
overnight or while the user is away — iOS is suspended → no row
is ever created. The closer half (closer.py) handles the symmetric
"app missed the end" case, but a session that never opened can't
be closed either; the result is that the user's 电池管理 → 充电历史
list is sparse (e.g. 2 rows in months of driving).

Mirror the closer's design:
- One cron tick per user, snap is the latest telemetry snapshot.
- If snap says we're charging AND no open session exists for this
  user, INSERT a new ChargingSession row using telemetry SOC as
  start_soc. ended_at stays NULL; the closer will fill it when
  charging stops.
- Idempotent: a second tick during the same charge finds the open
  row and no-ops.

Bug context: census of the live route_plans + charging_session
tables on 2026-05-12 found only 2 sessions for the primary test
user despite months of charging activity. Same write-side-missing
pattern as the route_plans bug fixed by /routes/save the same day.
"""

from __future__ import annotations

import logging
from datetime import datetime
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import ChargingSession
from app.services.automation.base import VehicleStateSnapshot

logger = logging.getLogger(__name__)


async def open_session_if_charging(
    db: AsyncSession,
    *,
    user_id: int,
    vehicle_id: str,
    snap: Optional[VehicleStateSnapshot],
    now: Optional[datetime] = None,
) -> Optional[int]:
    """Open a ChargingSession if telemetry says we're charging and
    no open row exists. Returns the inserted row id, or None if no
    insert happened.

    No-op when:
      - snap is None (no telemetry; we don't know anything)
      - snap.charging_state != "Charging" (closer handles this end)
      - an open row already exists for this user (idempotent)
    """
    if snap is None or snap.charging_state != "Charging":
        return None
    if now is None:
        now = datetime.utcnow()
    elif now.tzinfo is not None:
        now = now.replace(tzinfo=None)

    # Same per-user filtering rationale as closer.py: vehicle_id on
    # ChargingSession is whatever iOS submitted (numeric Tesla id),
    # while the cron tick passes the VIN. Match on user_id; the
    # multi-vehicle edge case can plumb the per-vehicle snapshot dict
    # later. Multi-car shouldn't cross-clash because only one car
    # charges at a time for a given user.
    existing = (await db.execute(
        select(ChargingSession).where(
            ChargingSession.user_id == user_id,
            ChargingSession.ended_at.is_(None),
        )
    )).scalars().first()
    if existing is not None:
        return None

    row = ChargingSession(
        user_id=user_id,
        vehicle_id=vehicle_id,
        client_session_id=f"server:{int(now.timestamp())}",
        started_at=now,
        start_soc=snap.battery_level,
        # Tesla Fleet Telemetry doesn't carry battery_range today;
        # iOS detail view tolerates None.
        source="server",
        created_at=now,
    )
    db.add(row)
    await db.flush()  # populate row.id

    logger.info(
        "opened charging session %s for user=%s vin=%s start_soc=%s",
        row.id, user_id, vehicle_id, snap.battery_level,
    )
    return row.id
