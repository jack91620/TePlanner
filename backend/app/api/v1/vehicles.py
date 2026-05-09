"""Vehicle management endpoints."""

import json
import logging
from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user, get_db, get_tesla_client
from app.db.models import (
    ChargingSession,
    ScheduledDeparture,
    User,
    Vehicle,
)
from app.integrations.tesla import TeslaClient
from app.integrations.tesla.exceptions import TeslaAPIError, TeslaVehicleOfflineError
from app.services.charge_analysis.suggester import (
    UpcomingDeparture,
    suggest as suggest_charge_limit,
)
from app.services.vehicle_commands import (
    invoke_capability as _invoke_capability,
    resolve_vin as _resolve_vin,
)
from app.services.vehicle_sync_service import sync_vehicles as _sync_vehicles

logger = logging.getLogger(__name__)

router = APIRouter()


class VehicleResponse(BaseModel):
    """Vehicle response model."""

    id: str
    vin: Optional[str] = None
    display_name: str
    model: Optional[str] = None
    state: str
    is_primary: bool = False


class VehicleListResponse(BaseModel):
    """Vehicle list response."""

    count: int
    vehicles: List[VehicleResponse]


class VehicleStateResponse(BaseModel):
    """Vehicle state response."""

    vehicle_id: str
    display_name: str
    state: str  # online, asleep, offline
    battery_level: Optional[int] = None
    battery_range_km: Optional[float] = None
    usable_battery_level: Optional[int] = None
    charging_state: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    heading: Optional[int] = None
    speed: Optional[int] = None
    odometer_km: Optional[float] = None
    inside_temp: Optional[float] = None
    outside_temp: Optional[float] = None
    # Phase 5: state the iOS AlertsViewModel watches for "user
    # forgot to clean this up" reminders. climate_keeper_mode is
    # the int Tesla returns: 0=off / 1=keep / 2=dog / 3=camp.
    climate_keeper_mode: Optional[int] = None
    is_climate_on: Optional[bool] = None
    sentry_mode_on: Optional[bool] = None
    cabin_overheat_protection_on: Optional[bool] = None
    # Phase 5.6: charge_limit_soc lets the iOS "智能充电限额建议" card
    # decide whether to surface a recommendation (only when the
    # current limit differs from what the user wants for daily / pre-
    # trip use).
    charge_limit_soc: Optional[int] = None


class ClimateKeeperModeRequest(BaseModel):
    """Set climate keeper mode (0=off, 1=keep, 2=dog, 3=camp)."""

    mode: int  # 0..3


class SentryModeRequest(BaseModel):
    """Toggle sentry mode."""

    on: bool


class ChargeLimitRequest(BaseModel):
    """Set the charge limit SOC percent (50..100)."""

    percent: int


class NavigationRequest(BaseModel):
    """Navigation request model."""

    latitude: float
    longitude: float
    order: int = 1


class NavigationAddressRequest(BaseModel):
    """Navigation by address request model."""

    address: str
    locale: str = "zh-CN"


class WakeResponse(BaseModel):
    """Wake response model."""

    vehicle_id: str
    state: str
    message: str


@router.get("/", response_model=VehicleListResponse)
async def list_vehicles(
    user: User = Depends(get_current_user),
    tesla_client: TeslaClient = Depends(get_tesla_client),
    db: AsyncSession = Depends(get_db),
):
    """List user's Tesla vehicles, syncing the local Vehicle table.
    Logic in services/vehicle_sync_service.sync_vehicles."""
    try:
        rows = await _sync_vehicles(user=user, tesla_client=tesla_client, db=db)
    except TeslaAPIError as e:
        raise HTTPException(
            status_code=e.status_code or 500,
            detail=f"Tesla API error: {str(e)}",
        )
    return VehicleListResponse(
        count=len(rows),
        vehicles=[VehicleResponse(**r) for r in rows],
    )


@router.get("/{vehicle_id}", response_model=VehicleResponse)
async def get_vehicle(
    vehicle_id: str,
    user: User = Depends(get_current_user),
    tesla_client: TeslaClient = Depends(get_tesla_client),
    db: AsyncSession = Depends(get_db),
):
    """Get specific vehicle details."""
    try:
        async with tesla_client:
            response = await tesla_client.get_vehicle(vehicle_id)
            v = response.get("response", {})

            # Check if primary
            result = await db.execute(
                select(Vehicle).where(
                    Vehicle.user_id == user.id,
                    Vehicle.vehicle_id == vehicle_id,
                )
            )
            db_vehicle = result.scalar_one_or_none()

            return VehicleResponse(
                id=str(v.get("id")),
                vin=v.get("vin"),
                display_name=v.get("display_name", "Tesla"),
                model=_parse_model(v.get("vin")),
                state=v.get("state", "unknown"),
                is_primary=db_vehicle.is_primary if db_vehicle else False,
            )

    except TeslaAPIError as e:
        raise HTTPException(
            status_code=e.status_code or 500,
            detail=f"Tesla API error: {str(e)}",
        )


@router.get("/{vehicle_id}/state", response_model=VehicleStateResponse)
async def get_vehicle_state(
    vehicle_id: str,
    user: User = Depends(get_current_user),
    tesla_client: TeslaClient = Depends(get_tesla_client),
):
    """Get vehicle state (battery, location, etc.).

    Returns real-time vehicle data including:
    - Battery level and range
    - Current location (GPS)
    - Charging state
    - Climate status
    """
    try:
        async with tesla_client:
            # Get comprehensive vehicle data
            response = await tesla_client.get_vehicle_data(
                vehicle_id,
                endpoints=[
                    "charge_state",
                    "drive_state",
                    "location_data",
                    "climate_state",
                    "vehicle_state",
                ],
            )

            v = response.get("response", {})
            charge_state = v.get("charge_state", {})
            drive_state = v.get("drive_state", {})
            climate_state = v.get("climate_state", {})
            vehicle_state = v.get("vehicle_state", {})

            return VehicleStateResponse(
                vehicle_id=vehicle_id,
                display_name=v.get("display_name", "Tesla"),
                state=v.get("state", "unknown"),
                battery_level=charge_state.get("battery_level"),
                battery_range_km=_miles_to_km(charge_state.get("battery_range")),
                usable_battery_level=charge_state.get("usable_battery_level"),
                charging_state=charge_state.get("charging_state"),
                latitude=drive_state.get("latitude"),
                longitude=drive_state.get("longitude"),
                heading=drive_state.get("heading"),
                speed=_mph_to_kmh(drive_state.get("speed")),
                odometer_km=_miles_to_km(vehicle_state.get("odometer")),
                inside_temp=climate_state.get("inside_temp"),
                outside_temp=climate_state.get("outside_temp"),
                climate_keeper_mode=_normalize_climate_keeper_mode(
                    climate_state.get("climate_keeper_mode")
                ),
                is_climate_on=climate_state.get("is_climate_on"),
                sentry_mode_on=vehicle_state.get("sentry_mode"),
                cabin_overheat_protection_on=climate_state.get(
                    "cabin_overheat_protection"
                ) == "On" or climate_state.get(
                    "cabin_overheat_protection_on"
                ),
                charge_limit_soc=charge_state.get("charge_limit_soc"),
            )

    except TeslaVehicleOfflineError:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Vehicle is offline. Please wake up the vehicle first.",
        )
    except TeslaAPIError as e:
        raise HTTPException(
            status_code=e.status_code or 500,
            detail=f"Tesla API error: {str(e)}",
        )


@router.post("/{vehicle_id}/wake", response_model=WakeResponse)
async def wake_vehicle(
    vehicle_id: str,
    user: User = Depends(get_current_user),
    tesla_client: TeslaClient = Depends(get_tesla_client),
):
    """Wake up the vehicle.

    Sends wake-up command and waits for vehicle to come online.
    May take 10-30 seconds.
    """
    try:
        async with tesla_client:
            response = await tesla_client.wake_up(vehicle_id)
            v = response.get("response", {})

            state = v.get("state", "unknown")

            return WakeResponse(
                vehicle_id=vehicle_id,
                state=state,
                message="Wake command sent" if state != "online" else "Vehicle is online",
            )

    except TeslaAPIError as e:
        raise HTTPException(
            status_code=e.status_code or 500,
            detail=f"Tesla API error: {str(e)}",
        )


# _resolve_vin moved to app/services/vehicle_commands.resolve_vin (re-exported above as _resolve_vin for back-compat).


@router.post("/{vehicle_id}/climate-keeper-mode")
async def set_climate_keeper_mode(
    vehicle_id: str,
    request: ClimateKeeperModeRequest,
    user: User = Depends(get_current_user),
    tesla_client: TeslaClient = Depends(get_tesla_client),
    db: AsyncSession = Depends(get_db),
):
    """Set climate keeper mode. 0=off / 1=keep / 2=dog / 3=camp.
    Dispatches through capability registry."""
    return await _invoke_capability(
        "tesla.climate.set_keeper_mode",
        vehicle_id,
        {"mode": request.mode},
        user, tesla_client, db,
    )


@router.post("/{vehicle_id}/sentry-mode")
async def set_sentry_mode(
    vehicle_id: str,
    request: SentryModeRequest,
    user: User = Depends(get_current_user),
    tesla_client: TeslaClient = Depends(get_tesla_client),
    db: AsyncSession = Depends(get_db),
):
    """Toggle sentry mode. Dispatches through capability registry."""
    return await _invoke_capability(
        "tesla.security.set_sentry",
        vehicle_id,
        {"on": request.on},
        user, tesla_client, db,
    )


@router.post("/{vehicle_id}/charge-limit")
async def set_charge_limit(
    vehicle_id: str,
    request: ChargeLimitRequest,
    user: User = Depends(get_current_user),
    tesla_client: TeslaClient = Depends(get_tesla_client),
    db: AsyncSession = Depends(get_db),
):
    """Set the vehicle's charge limit SOC percent (50..100).
    Dispatches through capability registry."""
    return await _invoke_capability(
        "tesla.charging.set_limit",
        vehicle_id,
        {"percent": request.percent},
        user, tesla_client, db,
    )


@router.post("/{vehicle_id}/preheat")
async def preheat_vehicle(
    vehicle_id: str,
    user: User = Depends(get_current_user),
    tesla_client: TeslaClient = Depends(get_tesla_client),
    db: AsyncSession = Depends(get_db),
):
    """Start HVAC (auto_conditioning_start) so the cabin is at
    temperature on arrival. Used by 出发前预热. Dispatches through
    capability registry."""
    result = await _invoke_capability(
        "tesla.climate.preheat",
        vehicle_id,
        {},
        user, tesla_client, db,
    )
    return {**result, "message": "Preheat started"}


@router.post("/{vehicle_id}/navigate")
async def navigate_vehicle(
    vehicle_id: str,
    request: NavigationRequest,
    user: User = Depends(get_current_user),
    tesla_client: TeslaClient = Depends(get_tesla_client),
    db: AsyncSession = Depends(get_db),
):
    """Send GPS coordinates to vehicle nav. Dispatches through
    capability registry. Uses numeric vehicle_id (not VIN) since
    navigation_gps_request is one of the few endpoints not on the
    VCP-signed path."""
    result = await _invoke_capability(
        "tesla.navigation.send",
        vehicle_id,
        {
            "latitude": request.latitude,
            "longitude": request.longitude,
            "order": request.order,
        },
        user, tesla_client, db,
        require_vin=False,
    )
    return {**result, "message": "Navigation destination sent to vehicle"}


@router.post("/{vehicle_id}/navigate/address")
async def navigate_vehicle_address(
    vehicle_id: str,
    request: NavigationAddressRequest,
    user: User = Depends(get_current_user),
    tesla_client: TeslaClient = Depends(get_tesla_client),
):
    """Send navigation destination by address to vehicle.

    Sends address string to the vehicle's navigation system.
    Vehicle must be online.
    """
    try:
        async with tesla_client:
            await tesla_client.navigation_request(
                vehicle_tag=vehicle_id,
                address=request.address,
                locale=request.locale,
            )

            return {
                "success": True,
                "message": "Navigation address sent to vehicle",
                "destination": {
                    "address": request.address,
                },
            }

    except TeslaVehicleOfflineError:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Vehicle is offline. Please wake up the vehicle first.",
        )
    except TeslaAPIError as e:
        raise HTTPException(
            status_code=e.status_code or 500,
            detail=f"Tesla API error: {str(e)}",
        )


# ---------------------------------------------------------------------------
# Phase 9 — closed-loop VCP confirmation: GET /vehicles/commands/pending

class PendingCommandResponse(BaseModel):
    id: int
    capability: str
    expected_state: dict
    dispatched_at: datetime
    confirmed_at: Optional[datetime] = None
    timed_out_at: Optional[datetime] = None
    status: str  # "pending" | "confirmed" | "timed_out"


class PendingCommandListResponse(BaseModel):
    pending: list[PendingCommandResponse]


@router.get("/commands/pending", response_model=PendingCommandListResponse)
async def list_pending_commands(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    limit: int = 20,
) -> PendingCommandListResponse:
    """Phase 9 — what VCP commands sent in the last few minutes are
    still awaiting telemetry confirmation, plus the most recently
    resolved ones for the iOS UI to flip to "已关闭" / "超时".

    The resolver runs server-side on every Telemetry frame, so a
    well-timed poll right after dispatch will see the row transition
    pending → confirmed within ~1-2 s of the actual state change.
    """
    from datetime import timedelta
    from sqlalchemy import desc
    from app.db.models import CommandPending

    # Window: anything dispatched within the last 5 minutes. Both
    # still-pending (no confirmed_at / timed_out_at) and recently-
    # resolved rows go in the response so a slow iOS poll doesn't
    # miss the resolution.
    cutoff = datetime.utcnow() - timedelta(minutes=5)
    stmt = (
        select(CommandPending)
        .where(
            CommandPending.user_id == user.id,
            CommandPending.dispatched_at >= cutoff,
        )
        .order_by(desc(CommandPending.dispatched_at))
        .limit(limit)
    )
    rows = (await db.execute(stmt)).scalars().all()

    out: list[PendingCommandResponse] = []
    for row in rows:
        try:
            expected = json.loads(row.expected_state_json)
        except (json.JSONDecodeError, TypeError):
            expected = {}
        if row.confirmed_at is not None:
            status_str = "confirmed"
        elif row.timed_out_at is not None:
            status_str = "timed_out"
        else:
            status_str = "pending"
        out.append(PendingCommandResponse(
            id=row.id,
            capability=row.capability,
            expected_state=expected,
            dispatched_at=row.dispatched_at,
            confirmed_at=row.confirmed_at,
            timed_out_at=row.timed_out_at,
            status=status_str,
        ))
    return PendingCommandListResponse(pending=out)


# ---------------------------------------------------------------------------
# Phase 10 — sleep-aware command queue: list / cancel queued commands.

class QueuedCommandResponse(BaseModel):
    id: int
    capability: str
    params: dict
    dispatch_policy: str
    queued_at: datetime
    sent_at: Optional[datetime] = None
    dropped_at: Optional[datetime] = None
    ttl_seconds: int
    error: Optional[str] = None
    status: str  # "queued" | "sent" | "dropped"


class QueuedCommandListResponse(BaseModel):
    queued: list[QueuedCommandResponse]


@router.get("/commands/queued", response_model=QueuedCommandListResponse)
async def list_queued_commands(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    limit: int = 20,
) -> QueuedCommandListResponse:
    """Return commands waiting on the car's next CONNECTED telemetry
    event, plus recently-resolved ones for the iOS UI to flip badges.
    """
    from datetime import timedelta
    from sqlalchemy import desc
    from app.db.models import CommandQueue

    cutoff = datetime.utcnow() - timedelta(hours=2)
    stmt = (
        select(CommandQueue)
        .where(
            CommandQueue.user_id == user.id,
            CommandQueue.queued_at >= cutoff,
        )
        .order_by(desc(CommandQueue.queued_at))
        .limit(limit)
    )
    rows = (await db.execute(stmt)).scalars().all()

    out: list[QueuedCommandResponse] = []
    for row in rows:
        try:
            params = json.loads(row.params_json)
        except (json.JSONDecodeError, TypeError):
            params = {}
        if row.sent_at is not None:
            status_str = "sent"
        elif row.dropped_at is not None:
            status_str = "dropped"
        else:
            status_str = "queued"
        out.append(QueuedCommandResponse(
            id=row.id,
            capability=row.capability,
            params=params,
            dispatch_policy=row.dispatch_policy,
            queued_at=row.queued_at,
            sent_at=row.sent_at,
            dropped_at=row.dropped_at,
            ttl_seconds=row.ttl_seconds,
            error=row.error,
            status=status_str,
        ))
    return QueuedCommandListResponse(queued=out)


@router.delete("/commands/queued/{queued_id}")
async def cancel_queued_command(
    queued_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Cancel a still-queued command before it drains. 404 if the
    user doesn't own it; 409 if it's already been sent/dropped."""
    from app.db.models import CommandQueue

    stmt = select(CommandQueue).where(
        CommandQueue.id == queued_id,
        CommandQueue.user_id == user.id,
    )
    row = (await db.execute(stmt)).scalar_one_or_none()
    if row is None:
        raise HTTPException(status_code=404, detail="Queued command not found")
    if row.sent_at is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Already dispatched",
        )
    if row.dropped_at is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Already dropped",
        )
    row.dropped_at = datetime.utcnow()
    row.error = "cancelled by user"
    await db.commit()
    return {"success": True, "cancelled": queued_id}


@router.post("/{vehicle_id}/set-primary")
async def set_primary_vehicle(
    vehicle_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Set vehicle as primary for the user.

    Only one vehicle can be primary at a time.
    """
    # Clear all primary flags for this user
    result = await db.execute(
        select(Vehicle).where(Vehicle.user_id == user.id)
    )
    vehicles = result.scalars().all()

    for v in vehicles:
        v.is_primary = v.vehicle_id == vehicle_id

    await db.commit()

    return {
        "success": True,
        "message": f"Vehicle {vehicle_id} set as primary",
    }


def _parse_model(vin: Optional[str]) -> Optional[str]:
    """Parse Tesla model from VIN."""
    if not vin or len(vin) < 4:
        return None

    model_code = vin[3]
    model_map = {
        "S": "Model S",
        "3": "Model 3",
        "X": "Model X",
        "Y": "Model Y",
    }
    return model_map.get(model_code, f"Model {model_code}")


def _miles_to_km(miles: Optional[float]) -> Optional[float]:
    """Convert miles to kilometers."""
    if miles is None:
        return None
    return round(miles * 1.60934, 1)


def _mph_to_kmh(mph: Optional[float]) -> Optional[int]:
    """Convert mph to km/h."""
    if mph is None:
        return None
    return int(mph * 1.60934)


# Tesla returns climate_keeper_mode as either an int 0..3 or one of
# the strings "off"/"keep"/"dog"/"camp". Normalize to int so the
# iOS client doesn't need to handle both shapes.
_CLIMATE_KEEPER_STR_TO_INT = {
    "off": 0, "no": 0, "false": 0,
    "keep": 1, "on": 1,
    "dog": 2,
    "camp": 3,
}


def _normalize_climate_keeper_mode(raw) -> Optional[int]:
    if raw is None:
        return None
    if isinstance(raw, bool):
        return 1 if raw else 0
    if isinstance(raw, int):
        return raw if 0 <= raw <= 3 else None
    if isinstance(raw, str):
        return _CLIMATE_KEEPER_STR_TO_INT.get(raw.strip().lower())
    return None


# ---------------------------------------------------------------------------
# Phase A.4 — charging sessions + charge-limit suggester.
#
# These don't need a separate /sessions router prefix; iOS already
# scopes by /vehicles/{vehicle_id}/. Tracking lives client-side until
# Phase D, which wires iOS ChargingSessionTracker → these endpoints.

class ChargingSessionRequest(BaseModel):
    client_session_id: Optional[str] = Field(None, max_length=64)
    started_at: datetime
    ended_at: Optional[datetime] = None
    start_soc: Optional[int] = Field(None, ge=0, le=100)
    end_soc: Optional[int] = Field(None, ge=0, le=100)
    start_range_km: Optional[float] = Field(None, ge=0)
    end_range_km: Optional[float] = Field(None, ge=0)
    energy_added_kwh: Optional[float] = Field(None, ge=0)
    location_name: Optional[str] = Field(None, max_length=128)
    lat: Optional[float] = None
    lng: Optional[float] = None
    ended_as_complete: Optional[bool] = None


class ChargingSessionResponse(BaseModel):
    id: int
    vehicle_id: Optional[str]
    client_session_id: Optional[str]
    started_at: datetime
    ended_at: Optional[datetime]
    start_soc: Optional[int]
    end_soc: Optional[int]
    start_range_km: Optional[float]
    end_range_km: Optional[float]
    energy_added_kwh: Optional[float]
    location_name: Optional[str]
    lat: Optional[float]
    lng: Optional[float]
    ended_as_complete: Optional[bool]
    source: str
    duration_minutes: Optional[int]
    range_added_km: Optional[float]
    soc_delta: Optional[int]


class ChargingSessionListResponse(BaseModel):
    sessions: List[ChargingSessionResponse]


def _session_to_response(row: ChargingSession) -> ChargingSessionResponse:
    duration: Optional[int] = None
    if row.ended_at is not None:
        duration = max(0, int((row.ended_at - row.started_at).total_seconds() // 60))
    range_added: Optional[float] = None
    if row.start_range_km is not None and row.end_range_km is not None:
        range_added = max(0.0, round(row.end_range_km - row.start_range_km, 1))
    soc_delta: Optional[int] = None
    if row.start_soc is not None and row.end_soc is not None:
        soc_delta = max(0, row.end_soc - row.start_soc)
    return ChargingSessionResponse(
        id=row.id,
        vehicle_id=row.vehicle_id,
        client_session_id=row.client_session_id,
        started_at=row.started_at,
        ended_at=row.ended_at,
        start_soc=row.start_soc,
        end_soc=row.end_soc,
        start_range_km=row.start_range_km,
        end_range_km=row.end_range_km,
        energy_added_kwh=row.energy_added_kwh,
        location_name=row.location_name,
        lat=row.lat,
        lng=row.lng,
        ended_as_complete=row.ended_as_complete,
        source=row.source,
        duration_minutes=duration,
        range_added_km=range_added,
        soc_delta=soc_delta,
    )


@router.post("/{vehicle_id}/sessions", response_model=ChargingSessionResponse)
async def upsert_charging_session(
    vehicle_id: str,
    body: ChargingSessionRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ChargingSessionResponse:
    """Create or update a charging session.

    iOS POSTs once on plug-in (ended_at NULL) and again on plug-out
    (ended_at set). Server upserts on ``client_session_id`` so retries
    are safe; if absent (legacy iOS builds), every POST creates a new
    row — acceptable trade-off but fix client-side first.
    """
    existing: Optional[ChargingSession] = None
    if body.client_session_id:
        existing = (await db.execute(
            select(ChargingSession).where(
                ChargingSession.user_id == user.id,
                ChargingSession.client_session_id == body.client_session_id,
            )
        )).scalar_one_or_none()

    started_naive = body.started_at.replace(tzinfo=None)
    ended_naive = body.ended_at.replace(tzinfo=None) if body.ended_at else None

    if existing is None:
        row = ChargingSession(
            user_id=user.id,
            vehicle_id=vehicle_id,
            client_session_id=body.client_session_id,
            started_at=started_naive,
            ended_at=ended_naive,
            start_soc=body.start_soc,
            end_soc=body.end_soc,
            start_range_km=body.start_range_km,
            end_range_km=body.end_range_km,
            energy_added_kwh=body.energy_added_kwh,
            location_name=body.location_name,
            lat=body.lat,
            lng=body.lng,
            ended_as_complete=body.ended_as_complete,
            source="ios",
            created_at=datetime.utcnow(),
        )
        db.add(row)
    else:
        if ended_naive is not None:
            existing.ended_at = ended_naive
        if body.end_soc is not None:
            existing.end_soc = body.end_soc
        if body.end_range_km is not None:
            existing.end_range_km = body.end_range_km
        if body.energy_added_kwh is not None:
            existing.energy_added_kwh = body.energy_added_kwh
        if body.ended_as_complete is not None:
            existing.ended_as_complete = body.ended_as_complete
        if body.location_name is not None:
            existing.location_name = body.location_name
        if body.lat is not None:
            existing.lat = body.lat
        if body.lng is not None:
            existing.lng = body.lng
        row = existing
    await db.flush()
    logger.info(
        "user %s upserted session for vehicle %s (client_id=%s, ended=%s)",
        user.id, vehicle_id, body.client_session_id,
        ended_naive is not None,
    )
    return _session_to_response(row)


@router.get(
    "/{vehicle_id}/sessions",
    response_model=ChargingSessionListResponse,
)
async def list_charging_sessions(
    vehicle_id: str,
    limit: int = 50,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ChargingSessionListResponse:
    """Most-recent-first session list. Default limit 50 covers ~6 weeks
    of typical daily-charging owners; clients pass `?limit=N` to dig
    further. Strict per-user filter so a vehicle_id collision (Tesla
    sometimes recycles ids across accounts) can't leak rows."""
    stmt = (
        select(ChargingSession)
        .where(
            ChargingSession.user_id == user.id,
            ChargingSession.vehicle_id == vehicle_id,
        )
        .order_by(desc(ChargingSession.started_at))
        .limit(max(1, min(500, limit)))
    )
    rows = (await db.execute(stmt)).scalars().all()
    return ChargingSessionListResponse(sessions=[_session_to_response(r) for r in rows])


class SuggestChargeLimitRequest(BaseModel):
    current_limit: Optional[int] = Field(None, ge=20, le=100)
    daily_limit_soc: int = Field(80, ge=20, le=100)
    trip_limit_soc: int = Field(100, ge=20, le=100)
    trip_window_hours: int = Field(12, ge=1, le=72)


class SuggestChargeLimitResponse(BaseModel):
    recommended_percent: int
    current_percent: Optional[int]
    reason: str
    hours_away: Optional[int]
    already_matches: bool


@router.post(
    "/{vehicle_id}/suggest-charge-limit",
    response_model=SuggestChargeLimitResponse,
)
async def suggest_charge_limit_endpoint(
    vehicle_id: str,
    body: SuggestChargeLimitRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SuggestChargeLimitResponse:
    """Server-side mirror of iOS ChargeLimitSuggester. Reads the
    user's currently-stored ScheduledDeparture (A.3) to find any
    upcoming trip; daily/trip preferences come from the request body
    (Phase D will read them from /user/settings instead).
    """
    departure_row = (await db.execute(
        select(ScheduledDeparture).where(ScheduledDeparture.user_id == user.id)
    )).scalar_one_or_none()
    upcoming = (
        UpcomingDeparture(departure_at_utc=departure_row.departure_at_utc)
        if departure_row is not None and departure_row.enabled
        else None
    )
    suggestion = suggest_charge_limit(
        current_limit=body.current_limit,
        daily_limit_soc=body.daily_limit_soc,
        trip_limit_soc=body.trip_limit_soc,
        upcoming_departure=upcoming,
        now=datetime.utcnow(),
        trip_window_hours=body.trip_window_hours,
    )
    return SuggestChargeLimitResponse(
        recommended_percent=suggestion.recommended_percent,
        current_percent=suggestion.current_percent,
        reason=suggestion.reason.value,
        hours_away=suggestion.hours_away,
        already_matches=suggestion.already_matches,
    )
