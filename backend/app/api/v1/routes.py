"""Route planning endpoints."""

from typing import Optional

from fastapi import APIRouter
from pydantic import BaseModel

router = APIRouter()


class RoutePlanRequest(BaseModel):
    """Route planning request."""

    origin_lat: float
    origin_lng: float
    destination_lat: float
    destination_lng: float
    current_soc: float  # State of charge (0-100)
    vehicle_model: str  # e.g., "model_y_long_range"
    battery_capacity: Optional[float] = None  # kWh


class ChargingStop(BaseModel):
    """Charging stop in route."""

    station_id: str
    name: str
    operator: str
    latitude: float
    longitude: float
    power_kw: int
    arrival_soc: float
    departure_soc: float
    charging_duration_minutes: int


class RoutePlanResponse(BaseModel):
    """Route planning response."""

    total_distance_km: float
    total_duration_minutes: int
    charging_stops: list[ChargingStop]
    final_soc: float


@router.post("/plan", response_model=RoutePlanResponse)
async def plan_route(request: RoutePlanRequest):
    """Plan a charging route."""
    # TODO: Implement route planning algorithm
    return RoutePlanResponse(
        total_distance_km=500,
        total_duration_minutes=360,
        charging_stops=[
            ChargingStop(
                station_id="station_001",
                name="XX Service Area Charging Station",
                operator="State Grid",
                latitude=38.5,
                longitude=116.0,
                power_kw=120,
                arrival_soc=20,
                departure_soc=80,
                charging_duration_minutes=30,
            )
        ],
        final_soc=35,
    )


@router.get("/{route_id}")
async def get_route(route_id: str):
    """Get a saved route plan."""
    # TODO: Retrieve route from database
    return {"route_id": route_id, "status": "not_found"}
