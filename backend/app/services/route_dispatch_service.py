"""Route → Tesla nav waypoints dispatch service.

Extracted from `app/api/v1/routes.py:navigate_saved_route` so the
loop that sends a saved RoutePlan's charging stops + final
destination to the car can be unit-tested without TestClient.

Public entry:
  - ``send_saved_route_to_vehicle(route_id, user, tesla_client, db)``
    finds the route, picks the user's primary vehicle (or first
    vehicle as fallback), builds the waypoint list, and dispatches
    each one through the Tesla SDK in order. Returns the per-
    waypoint result dicts the handler echos back.

Raises:
  - ``RouteNotFoundError`` if the route id isn't owned by user
  - ``NoVehicleError`` if the user has no Tesla linked
  - Tesla SDK exceptions propagate (handler maps to HTTP).
"""

from __future__ import annotations

import json
import logging
from typing import List, Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import RoutePlan, User, Vehicle
from app.integrations.tesla import TeslaClient

logger = logging.getLogger(__name__)


class RouteNotFoundError(Exception):
    """Route id not found OR not owned by the requesting user."""


class NoVehicleError(Exception):
    """User has no Tesla vehicle linked — can't send navigation."""


async def send_saved_route_to_vehicle(
    route_id: int,
    user: User,
    tesla_client: TeslaClient,
    db: AsyncSession,
) -> dict:
    """Dispatch a saved route's waypoints to the user's primary
    Tesla vehicle (falls back to first vehicle if no primary set).

    Side-effects:
      - Updates RoutePlan.status to 'sent_to_car' on success
    """
    route = await _load_route(db, route_id, user.id)
    vehicle = await _pick_primary_vehicle(db, user.id)

    waypoints = _build_waypoints(route)

    async with tesla_client:
        results: List[dict] = []
        for i, wp in enumerate(waypoints):
            await tesla_client.navigation_gps_request(
                vehicle_tag=vehicle.vehicle_id,
                latitude=wp["latitude"],
                longitude=wp["longitude"],
                order=i + 1,
            )
            results.append({
                "order": i + 1,
                "latitude": wp["latitude"],
                "longitude": wp["longitude"],
                "name": wp.get("name"),
                "status": "sent",
            })

        route.status = "sent_to_car"
        await db.commit()

    return {
        "success": True,
        "message": f"Sent route to vehicle {vehicle.display_name}",
        "vehicle_id": vehicle.vehicle_id,
        "waypoints": results,
    }


async def _load_route(
    db: AsyncSession, route_id: int, user_id: int,
) -> RoutePlan:
    result = await db.execute(
        select(RoutePlan).where(
            RoutePlan.id == route_id,
            RoutePlan.user_id == user_id,
        )
    )
    route = result.scalar_one_or_none()
    if route is None:
        raise RouteNotFoundError(f"Route {route_id} not found")
    return route


async def _pick_primary_vehicle(
    db: AsyncSession, user_id: int,
) -> Vehicle:
    """Pick user's primary vehicle. Falls back to first vehicle if
    no primary flag set, raises NoVehicleError if zero vehicles."""
    primary_q = select(Vehicle).where(
        Vehicle.user_id == user_id,
        Vehicle.is_primary == True,  # noqa: E712 — SQLAlchemy expr
    )
    primary = (await db.execute(primary_q)).scalar_one_or_none()
    if primary is not None:
        return primary

    first = (await db.execute(
        select(Vehicle).where(Vehicle.user_id == user_id).limit(1)
    )).scalar_one_or_none()
    if first is None:
        raise NoVehicleError(
            "No vehicle linked. Please connect a Tesla account first."
        )
    return first


def _build_waypoints(route: RoutePlan) -> List[dict]:
    """Build the ordered waypoint list: charging stops first (in
    declared order), then the final destination. Tolerant of a
    malformed charging_stops_json — drops the field rather than
    crashing the whole dispatch.
    """
    waypoints: List[dict] = []
    if route.charging_stops_json:
        try:
            stops = json.loads(route.charging_stops_json)
        except json.JSONDecodeError as exc:
            logger.warning(
                "route %s charging_stops_json invalid (%s) — skipping waypoints",
                route.id, exc,
            )
            stops = []
        for stop in stops:
            waypoints.append({
                "latitude": stop["latitude"],
                "longitude": stop["longitude"],
                "name": stop.get("name", "Charging Stop"),
            })
    waypoints.append({
        "latitude": route.dest_lat,
        "longitude": route.dest_lng,
        "name": route.dest_address or "Destination",
    })
    return waypoints
