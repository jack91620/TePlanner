"""Vehicle management endpoints."""

from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user, get_db, get_tesla_client
from app.db.models import User, Vehicle
from app.integrations.tesla import TeslaClient
from app.integrations.tesla.exceptions import TeslaAPIError, TeslaVehicleOfflineError

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
    """List user's Tesla vehicles.

    Fetches vehicles from Tesla API and syncs with local database.
    """
    try:
        async with tesla_client:
            response = await tesla_client.list_vehicles()
            vehicles_data = response.get("response", [])

            vehicles = []
            for v in vehicles_data:
                vehicle_id = str(v.get("id"))

                # Check if vehicle exists in DB
                result = await db.execute(
                    select(Vehicle).where(
                        Vehicle.user_id == user.id,
                        Vehicle.vehicle_id == vehicle_id,
                    )
                )
                db_vehicle = result.scalar_one_or_none()

                is_primary = db_vehicle.is_primary if db_vehicle else False

                # Create or update in DB
                if not db_vehicle:
                    db_vehicle = Vehicle(
                        user_id=user.id,
                        vehicle_id=vehicle_id,
                        vin=v.get("vin"),
                        display_name=v.get("display_name", "Tesla"),
                        model=_parse_model(v.get("vin")),
                    )
                    db.add(db_vehicle)
                else:
                    db_vehicle.display_name = v.get("display_name", db_vehicle.display_name)
                    db_vehicle.vin = v.get("vin", db_vehicle.vin)

                vehicles.append(
                    VehicleResponse(
                        id=vehicle_id,
                        vin=v.get("vin"),
                        display_name=v.get("display_name", "Tesla"),
                        model=_parse_model(v.get("vin")),
                        state=v.get("state", "unknown"),
                        is_primary=is_primary,
                    )
                )

            await db.commit()

            return VehicleListResponse(
                count=len(vehicles),
                vehicles=vehicles,
            )

    except TeslaAPIError as e:
        raise HTTPException(
            status_code=e.status_code or 500,
            detail=f"Tesla API error: {str(e)}",
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


@router.post("/{vehicle_id}/navigate")
async def navigate_vehicle(
    vehicle_id: str,
    request: NavigationRequest,
    user: User = Depends(get_current_user),
    tesla_client: TeslaClient = Depends(get_tesla_client),
):
    """Send navigation destination to vehicle.

    Sends GPS coordinates to the vehicle's navigation system.
    Vehicle must be online.
    """
    try:
        async with tesla_client:
            await tesla_client.navigation_gps_request(
                vehicle_tag=vehicle_id,
                lat=request.latitude,
                lon=request.longitude,
                order=request.order,
            )

            return {
                "success": True,
                "message": "Navigation destination sent to vehicle",
                "destination": {
                    "latitude": request.latitude,
                    "longitude": request.longitude,
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
