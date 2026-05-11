"""Auto-close charging sessions that the iOS tracker missed.

iOS `ChargingSessionTracker` only flips a session to "ended" when
its observe() loop sees the chargingState transition Charging→
Disconnected/Stopped/Complete *while the app is foregrounded and
polling*. If the user backgrounds or kills the app mid-charge,
the session row stays `ended_at IS NULL` forever — the user sees
"进行中" on a session from days ago.

This server-side closer fills the gap by inspecting the per-vehicle
telemetry snapshot on each cron tick. If telemetry says we are no
longer charging AND the session has been open longer than the
grace window, we close it using the latest telemetry SOC + range.

Grace window exists to avoid races: a Charging→Stopped flicker
during a real session shouldn't immediately close it. 5 minutes is
enough to ride out Tesla's brief reconnect/restart blips while
still closing within "user notices" latency.
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import ChargingSession
from app.services.automation.base import VehicleStateSnapshot

logger = logging.getLogger(__name__)


GRACE_MINUTES = 5


async def close_stale_sessions(
    db: AsyncSession,
    *,
    user_id: int,
    vehicle_id: str,
    snap: Optional[VehicleStateSnapshot],
    now: Optional[datetime] = None,
) -> int:
    """Close any open sessions for this (user, vehicle) when telemetry
    confirms we're not charging. Returns the number closed.

    No-op when:
      - snap is None (we don't have telemetry; can't conclude anything)
      - snap.charging_state == "Charging" (still charging, leave open)
      - the open session is younger than GRACE_MINUTES (avoid race)
    """
    if snap is None:
        return 0
    if snap.charging_state == "Charging":
        return 0
    if now is None:
        now = datetime.utcnow()
    elif now.tzinfo is not None:
        now = now.replace(tzinfo=None)

    cutoff = now - timedelta(minutes=GRACE_MINUTES)

    rows = (await db.execute(
        select(ChargingSession).where(
            ChargingSession.user_id == user_id,
            ChargingSession.vehicle_id == vehicle_id,
            ChargingSession.ended_at.is_(None),
            ChargingSession.started_at <= cutoff,
        )
    )).scalars().all()

    if not rows:
        return 0

    closed = 0
    for row in rows:
        row.ended_at = now
        if row.end_soc is None and snap.battery_level is not None:
            row.end_soc = snap.battery_level
        # battery_range isn't carried by Tesla Fleet Telemetry today,
        # so end_range_km stays NULL for closer-handled rows. iOS
        # detail view tolerates the gap (shows "—").
        if row.ended_as_complete is None:
            row.ended_as_complete = (snap.charging_state == "Complete")
        closed += 1

    logger.info(
        "auto-closed %s stale charging session(s) user=%s vin=%s charging_state=%s",
        closed, user_id, vehicle_id, snap.charging_state,
    )
    return closed
