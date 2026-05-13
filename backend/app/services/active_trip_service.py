"""Active-trip orchestration: sequentially push planned stops to a
Tesla so multi-stop charging routes survive the Fleet API's "one
destination per request" limit.

Concepts:
- A *trip* is an ordered list of `stops` (charging stops + one final
  destination). When the user taps "发到车" we persist the list and
  push stop[0] to the car. When the car arrives at stop[0] (cron
  monitor detects, or user manually advances), we push stop[1].
- *Replan* re-computes the remaining route from the car's current
  GPS, replacing stops[current..] with the new plan. Reason is
  surfaced both as an iOS push and (truncated) in the next stop's
  address string so the car screen shows it.
"""

from __future__ import annotations

import json
import logging
from datetime import datetime
from typing import Any, Dict, List, Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import ActiveTrip, Vehicle
from app.integrations.tesla import TeslaClient

logger = logging.getLogger(__name__)


# ---- helpers ------------------------------------------------------


def decode_stops(trip: ActiveTrip) -> List[Dict[str, Any]]:
    """JSON-decoded stops list. Trip rows are persisted with
    `stops_json` as a JSON-string for SQLite portability."""
    return json.loads(trip.stops_json) if trip.stops_json else []


def encode_stops(stops: List[Dict[str, Any]]) -> str:
    return json.dumps(stops, ensure_ascii=False)


def current_stop(trip: ActiveTrip) -> Optional[Dict[str, Any]]:
    stops = decode_stops(trip)
    if trip.current_segment < 0 or trip.current_segment >= len(stops):
        return None
    return stops[trip.current_segment]


def stop_display_address(stop: Dict[str, Any], reason: Optional[str]) -> str:
    """Build the address string we push to Tesla. Tesla's
    navigation_request shows whatever address it parses, so we encode
    the reroute reason as a parenthetical prefix when present. Tesla
    truncates at ~40 chars on the car screen — kept short.

    e.g. with reason:   "[原桩满] 上海超充站, 上海市浦东新区..."
         without:       "上海超充站, 上海市浦东新区..."
    """
    base = stop.get("address") or stop.get("name") or ""
    if reason:
        # 8-char Chinese cap on reason — Tesla truncates ~40 total,
        # leave most for the actual address.
        snippet = reason if len(reason) <= 8 else reason[:7] + "…"
        return f"[{snippet}] {base}"
    return base


# ---- core operations ---------------------------------------------


async def send_stop_to_vehicle(
    tesla_client: TeslaClient,
    trip: ActiveTrip,
    stop_index: int,
    reason: Optional[str] = None,
) -> None:
    """Push stops[stop_index] to the Tesla via navigation_request.
    Mutates trip.current_segment + last_replan_reason. Caller commits.
    """
    stops = decode_stops(trip)
    if stop_index < 0 or stop_index >= len(stops):
        raise ValueError(f"stop_index {stop_index} out of range (have {len(stops)} stops)")

    stop = stops[stop_index]
    address = stop_display_address(stop, reason)

    try:
        await tesla_client.navigation_request(
            vehicle_tag=trip.vehicle_id,
            address=address,
            locale="zh-CN",
        )
    except Exception as exc:
        logger.warning(
            "active_trip: nav send failed for trip=%s vehicle=%s stop_index=%s: %s",
            trip.id, trip.vehicle_id, stop_index, exc,
        )
        raise

    trip.current_segment = stop_index
    if reason is not None:
        trip.last_replan_reason = reason
    logger.info(
        "active_trip: sent trip=%s stop=%s (kind=%s) to vehicle=%s reason=%s",
        trip.id, stop_index, stop.get("kind"), trip.vehicle_id, reason or "(none)",
    )


async def cancel_existing_trips(db: AsyncSession, user_id: int) -> int:
    """Set status='cancelled' on any active trips for the user.
    Returns the number cancelled. Caller commits.
    """
    rows = (await db.execute(
        select(ActiveTrip).where(
            ActiveTrip.user_id == user_id,
            ActiveTrip.status == "active",
        )
    )).scalars().all()
    n = 0
    for row in rows:
        row.status = "cancelled"
        row.updated_at = datetime.utcnow()
        n += 1
    return n


async def get_active_trip(db: AsyncSession, user_id: int) -> Optional[ActiveTrip]:
    return (await db.execute(
        select(ActiveTrip).where(
            ActiveTrip.user_id == user_id,
            ActiveTrip.status == "active",
        )
        .order_by(ActiveTrip.created_at.desc())
        .limit(1)
    )).scalar_one_or_none()


def is_final_stop(trip: ActiveTrip) -> bool:
    """True iff current_segment is the last index in stops_json."""
    stops = decode_stops(trip)
    return trip.current_segment >= 0 and trip.current_segment == len(stops) - 1


def advance_index(trip: ActiveTrip) -> Optional[int]:
    """Index that `advance` would target; None if no further stop."""
    stops = decode_stops(trip)
    nxt = trip.current_segment + 1
    return nxt if nxt < len(stops) else None
