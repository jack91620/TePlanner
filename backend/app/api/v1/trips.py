"""Active trip endpoints — sequential nav for multi-stop routes.

POST /trips/start          — kick off a planned trip; sends stop 0
GET  /trips/active         — what's the user's current trip?
POST /trips/{id}/advance   — push next stop to car (user-initiated)
POST /trips/{id}/replan    — replace remaining stops with new ones
POST /trips/{id}/cancel    — abandon trip; no further sends

The auto-advance (cron-detected arrival) and auto-replan (off-route
or charger-occupied) live in a separate cron handler that calls into
`services.active_trip_service` directly without going through HTTP.
"""

from __future__ import annotations

import json
import logging
from datetime import datetime
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user, get_db, get_tesla_client
from app.db.models import ActiveTrip, User
from app.integrations.tesla import TeslaClient
from app.integrations.tesla.exceptions import TeslaAPIError, TeslaVehicleOfflineError
from app.services import active_trip_service as svc

router = APIRouter()
logger = logging.getLogger(__name__)


# ---- request / response shapes -----------------------------------


class TripStopInput(BaseModel):
    """One stop in a planned trip. `kind` distinguishes charging
    intermediates from the final destination."""

    latitude: float
    longitude: float
    address: Optional[str] = None
    name: Optional[str] = None
    kind: str = Field("charging", pattern="^(charging|final)$")
    station_id: Optional[str] = None
    soc_target: Optional[int] = None  # planned arrival SOC (charging stops)


class StartTripRequest(BaseModel):
    vehicle_id: str
    stops: List[TripStopInput]
    polyline: Optional[List[List[float]]] = None  # [[lat, lng], ...]


class StopResponse(BaseModel):
    latitude: float
    longitude: float
    address: Optional[str] = None
    name: Optional[str] = None
    kind: str
    station_id: Optional[str] = None
    soc_target: Optional[int] = None


class TripResponse(BaseModel):
    id: int
    vehicle_id: str
    status: str
    current_segment: int
    stops: List[StopResponse]
    replan_count: int
    last_replan_reason: Optional[str] = None
    last_position_lat: Optional[float] = None
    last_position_lng: Optional[float] = None
    last_position_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime


class ReplanRequest(BaseModel):
    """Replace stops[current_segment:] with `new_stops`. Reason is
    shown in the iOS push + truncated in the next stop's car-screen
    address."""

    new_stops: List[TripStopInput]
    reason: str
    polyline: Optional[List[List[float]]] = None


# ---- helpers ------------------------------------------------------


def _row_to_response(trip: ActiveTrip) -> TripResponse:
    stops_raw = svc.decode_stops(trip)
    return TripResponse(
        id=trip.id,
        vehicle_id=trip.vehicle_id,
        status=trip.status,
        current_segment=trip.current_segment,
        stops=[StopResponse(**s) for s in stops_raw],
        replan_count=trip.replan_count,
        last_replan_reason=trip.last_replan_reason,
        last_position_lat=trip.last_position_lat,
        last_position_lng=trip.last_position_lng,
        last_position_at=trip.last_position_at,
        created_at=trip.created_at,
        updated_at=trip.updated_at,
    )


def _stops_to_json(stops: List[TripStopInput]) -> str:
    return json.dumps([s.model_dump(exclude_none=False) for s in stops],
                      ensure_ascii=False)


# ---- endpoints ----------------------------------------------------


@router.post("/start", response_model=TripResponse, status_code=status.HTTP_201_CREATED)
async def start_trip(
    request: StartTripRequest,
    user: User = Depends(get_current_user),
    tesla_client: TeslaClient = Depends(get_tesla_client),
    db: AsyncSession = Depends(get_db),
):
    """Kick off a multi-stop trip. Replaces any prior active trip
    for this user. Pushes stops[0] to the car immediately and
    returns the new row.
    """
    if not request.stops:
        raise HTTPException(400, "stops cannot be empty")
    if request.stops[-1].kind != "final":
        raise HTTPException(400, "last stop must have kind='final'")

    # Cancel any existing active trip — only one in flight at a time.
    await svc.cancel_existing_trips(db, user.id)

    now = datetime.utcnow()
    trip = ActiveTrip(
        user_id=user.id,
        vehicle_id=request.vehicle_id,
        stops_json=_stops_to_json(request.stops),
        polyline_json=json.dumps(request.polyline) if request.polyline else None,
        current_segment=-1,
        status="active",
        replan_count=0,
        created_at=now,
        updated_at=now,
    )
    db.add(trip)
    await db.flush()  # populate trip.id

    try:
        async with tesla_client:
            await svc.send_stop_to_vehicle(tesla_client, trip, stop_index=0)
    except TeslaVehicleOfflineError:
        # Don't roll back the row — the trip exists, we just couldn't
        # send the first stop. User can retry via /advance or the cron
        # monitor will send when the car wakes.
        logger.warning(
            "start_trip: vehicle=%s offline; trip=%s created but stop 0 not sent",
            trip.vehicle_id, trip.id,
        )
    except TeslaAPIError as e:
        raise HTTPException(
            status_code=e.status_code or 500,
            detail=f"Tesla API error: {e}",
        )

    await db.commit()
    await db.refresh(trip)
    return _row_to_response(trip)


@router.get("/active", response_model=Optional[TripResponse])
async def get_active_trip(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Return the user's currently-active trip, or null."""
    trip = await svc.get_active_trip(db, user.id)
    return _row_to_response(trip) if trip else None


@router.post("/{trip_id}/advance", response_model=TripResponse)
async def advance_trip(
    trip_id: int,
    user: User = Depends(get_current_user),
    tesla_client: TeslaClient = Depends(get_tesla_client),
    db: AsyncSession = Depends(get_db),
):
    """Push the next stop to the car. Idempotent within reason — if
    the user double-taps, they'd send the same stop twice; harmless."""
    trip = await _get_own_trip(db, user.id, trip_id)
    nxt = svc.advance_index(trip)
    if nxt is None:
        # Last stop already; mark complete.
        trip.status = "completed"
        trip.updated_at = datetime.utcnow()
        await db.commit()
        await db.refresh(trip)
        return _row_to_response(trip)

    try:
        async with tesla_client:
            await svc.send_stop_to_vehicle(tesla_client, trip, stop_index=nxt)
    except TeslaVehicleOfflineError:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Vehicle offline; please wake it and retry.",
        )
    except TeslaAPIError as e:
        raise HTTPException(
            status_code=e.status_code or 500,
            detail=f"Tesla API error: {e}",
        )

    trip.updated_at = datetime.utcnow()
    await db.commit()
    await db.refresh(trip)
    return _row_to_response(trip)


@router.post("/{trip_id}/replan", response_model=TripResponse)
async def replan_trip(
    trip_id: int,
    body: ReplanRequest,
    user: User = Depends(get_current_user),
    tesla_client: TeslaClient = Depends(get_tesla_client),
    db: AsyncSession = Depends(get_db),
):
    """Replace stops[current..] with `new_stops`. Bumps replan_count
    and surfaces `reason` via the next stop's car-screen address
    + last_replan_reason (which the cron push handler reads)."""
    trip = await _get_own_trip(db, user.id, trip_id)

    if not body.new_stops:
        raise HTTPException(400, "new_stops cannot be empty")
    if body.new_stops[-1].kind != "final":
        raise HTTPException(400, "last stop must have kind='final'")

    # Keep history of already-visited stops; replace from current onward.
    stops_existing = svc.decode_stops(trip)
    head = stops_existing[: max(trip.current_segment, 0)]
    new_dicts = [s.model_dump(exclude_none=False) for s in body.new_stops]
    merged = head + new_dicts
    trip.stops_json = svc.encode_stops(merged)
    if body.polyline is not None:
        trip.polyline_json = json.dumps(body.polyline)
    trip.replan_count += 1

    # Send the FIRST stop of the new tail (== index `len(head)`).
    new_first_index = len(head)
    try:
        async with tesla_client:
            await svc.send_stop_to_vehicle(
                tesla_client, trip,
                stop_index=new_first_index,
                reason=body.reason,
            )
    except TeslaVehicleOfflineError:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Vehicle offline; replan saved but next stop not sent.",
        )
    except TeslaAPIError as e:
        raise HTTPException(
            status_code=e.status_code or 500,
            detail=f"Tesla API error: {e}",
        )

    trip.updated_at = datetime.utcnow()
    await db.commit()
    await db.refresh(trip)
    return _row_to_response(trip)


@router.post("/{trip_id}/cancel", response_model=TripResponse)
async def cancel_trip(
    trip_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Mark trip cancelled. No further auto-advance / replan fires.
    Does NOT clear the car's nav (Tesla would need a manual cancel
    on the car screen)."""
    trip = await _get_own_trip(db, user.id, trip_id, allow_inactive=True)
    if trip.status == "active":
        trip.status = "cancelled"
        trip.updated_at = datetime.utcnow()
        await db.commit()
        await db.refresh(trip)
    return _row_to_response(trip)


# ---- internal -----------------------------------------------------


async def _get_own_trip(
    db: AsyncSession, user_id: int, trip_id: int,
    allow_inactive: bool = False,
) -> ActiveTrip:
    trip = (await db.execute(
        select(ActiveTrip).where(ActiveTrip.id == trip_id)
    )).scalar_one_or_none()
    if trip is None or trip.user_id != user_id:
        raise HTTPException(404, "trip not found")
    if not allow_inactive and trip.status != "active":
        raise HTTPException(409, f"trip status is {trip.status!r}, not active")
    return trip
