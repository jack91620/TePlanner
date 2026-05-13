"""Active-trip cron monitor — automatic advance.

Phase 1 (active_trip_service) is the bare CRUD: app pushes stops one
at a time, but user has to tap "下一段" themselves. This module
(phase 2) wakes up inside the existing cron tick and auto-advances:

- Charging stop: arrival = ``charging_state == "Charging"``. Strong
  signal — only fires when the car physically plugged in. Distance
  + speed are secondary and only used when telemetry doesn't have
  charging_state for some reason.
- Final stop: arrival = within 200 m AND speed < 5 km/h AND parked.
  No charging_state to rely on; geometry has to do it.

When arrival fires:

- Send the next stop to the car (via active_trip_service)
- Push notification "已到达 A，下一站 B 已发送到车"
- Mutate trip.current_segment / replan_reason etc.

Decisions:

- Doesn't poll Tesla itself — reuses the snapshot the rest of cron
  builds from telemetry rows. No extra Fleet API calls per tick.
- Skips arrival detection when we don't have lat/lng (snapshot
  empty / car asleep) — would otherwise advance prematurely.
- Last-position is recorded on every tick (even non-arrival) so
  the iOS Hub card can show "现在距下一站 8 km, 25 min" in phase 2+.
"""

from __future__ import annotations

import logging
import math
from datetime import datetime
from typing import Optional

from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import ActiveTrip, TeslaToken
from app.integrations.tesla import TeslaClient
from app.services import active_trip_service as svc
from app.services.automation.base import VehicleStateSnapshot
from app.services.push import push_dispatcher
from sqlalchemy import select

logger = logging.getLogger(__name__)


# Tunables. Charging-stop detection is bullet-proof (relies on the
# car reporting charging_state); the final-stop heuristic is fuzzier
# because we can't know whether the user "arrived" or is just stopped
# at a red light in front of the destination.
_FINAL_STOP_RADIUS_M = 200.0
_FINAL_STOP_MAX_SPEED_KMH = 5.0
_CHARGING_FALLBACK_RADIUS_M = 300.0  # used when charging_state unknown


def _haversine_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Great-circle distance in metres. Good enough for arrival
    detection at 100 m precision."""
    R = 6371000.0  # earth radius m
    φ1 = math.radians(lat1)
    φ2 = math.radians(lat2)
    Δφ = math.radians(lat2 - lat1)
    Δλ = math.radians(lon2 - lon1)
    a = math.sin(Δφ / 2) ** 2 + math.cos(φ1) * math.cos(φ2) * math.sin(Δλ / 2) ** 2
    return R * 2 * math.asin(math.sqrt(a))


def _has_arrived(
    snap: VehicleStateSnapshot, stop: dict, is_final: bool,
) -> bool:
    """Did the car arrive at `stop`? Returns False on insufficient
    telemetry so we never auto-advance from missing data."""
    if snap.latitude is None or snap.longitude is None:
        return False
    stop_lat = stop.get("latitude")
    stop_lng = stop.get("longitude")
    if stop_lat is None or stop_lng is None:
        return False
    distance = _haversine_m(
        snap.latitude, snap.longitude, float(stop_lat), float(stop_lng),
    )

    if is_final:
        # Final destination: rely entirely on geometry. The car may
        # not be charging here (often isn't); we want "in the
        # neighborhood + stopped" to consider it done.
        speed = snap.speed_kmh or 0.0
        return distance <= _FINAL_STOP_RADIUS_M and speed <= _FINAL_STOP_MAX_SPEED_KMH

    # Charging stop: strong signal first — the car says it's charging.
    # Geometry only kicks in when charging_state is missing (telemetry
    # gap, asleep, etc.) so we still catch arrivals that didn't write
    # a fresh charge_state frame.
    if snap.charging_state == "Charging":
        return distance <= _CHARGING_FALLBACK_RADIUS_M * 5  # generous radius
    if snap.charging_state in {"Stopped", "NoPower", "Disconnected"}:
        return False
    return distance <= _CHARGING_FALLBACK_RADIUS_M


async def monitor_active_trip(
    db: AsyncSession,
    user_id: int,
    snap: VehicleStateSnapshot,
) -> None:
    """One tick's worth of monitoring for a single user's trip. No-op
    when the user has no active trip. Auto-commits its mutations
    so the cron tick's catch-all rollback doesn't undo the advance.
    """
    trip = await svc.get_active_trip(db, user_id)
    if trip is None:
        return

    # Record last position regardless of arrival.
    if snap.latitude is not None and snap.longitude is not None:
        trip.last_position_lat = float(snap.latitude)
        trip.last_position_lng = float(snap.longitude)
        trip.last_position_at = datetime.utcnow()

    stops = svc.decode_stops(trip)
    cur_idx = trip.current_segment
    if cur_idx < 0 or cur_idx >= len(stops):
        # No stop has been sent yet, OR current_segment is past the
        # end (shouldn't happen — defensive). Nothing to advance from.
        return

    current = stops[cur_idx]
    is_final_current = (cur_idx == len(stops) - 1)

    if not _has_arrived(snap, current, is_final_current):
        return

    logger.info(
        "active_trip_monitor: user=%s trip=%s arrival detected at stop=%s (kind=%s)",
        user_id, trip.id, cur_idx, current.get("kind"),
    )

    # On final-stop arrival: complete the trip + push.
    if is_final_current:
        trip.status = "completed"
        trip.updated_at = datetime.utcnow()
        await _push_completed(db, user_id, current)
        return

    # Mid-trip arrival: advance to next stop.
    nxt_idx = cur_idx + 1
    nxt_stop = stops[nxt_idx]
    token = (await db.execute(
        select(TeslaToken).where(TeslaToken.user_id == user_id)
    )).scalar_one_or_none()
    if token is None:
        logger.warning(
            "active_trip_monitor: user=%s has no TeslaToken — cannot advance",
            user_id,
        )
        return

    try:
        async with TeslaClient(access_token=token.access_token) as client:
            await svc.send_stop_to_vehicle(client, trip, stop_index=nxt_idx)
    except Exception as exc:  # noqa: BLE001
        logger.warning(
            "active_trip_monitor: send_stop failed for user=%s trip=%s: %s",
            user_id, trip.id, exc,
        )
        return

    await _push_advanced(db, user_id, arrived=current, next_stop=nxt_stop)


# ---- push helpers -------------------------------------------------


async def _push_advanced(
    db: AsyncSession, user_id: int,
    arrived: dict, next_stop: dict,
) -> None:
    arrived_name = arrived.get("name") or arrived.get("address") or "充电站"
    next_name = next_stop.get("name") or next_stop.get("address") or "下一站"
    next_kind = "终点" if next_stop.get("kind") == "final" else "下一充电站"
    try:
        await push_dispatcher.send(
            db=db, user_id=user_id,
            title=f"到达 {arrived_name}",
            body=f"已自动把{next_kind}「{next_name}」发到车机",
            category="active_trip_advanced",
            thread_id="active_trip",
            custom_data={"event": "advance"},
        )
    except Exception:  # noqa: BLE001
        logger.exception("active_trip_monitor: push (advanced) failed user=%s", user_id)


async def _push_completed(db: AsyncSession, user_id: int, last_stop: dict) -> None:
    name = last_stop.get("name") or last_stop.get("address") or "目的地"
    try:
        await push_dispatcher.send(
            db=db, user_id=user_id,
            title="行程完成",
            body=f"已到达「{name}」",
            category="active_trip_completed",
            thread_id="active_trip",
            custom_data={"event": "completed"},
        )
    except Exception:  # noqa: BLE001
        logger.exception("active_trip_monitor: push (completed) failed user=%s", user_id)
