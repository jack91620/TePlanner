"""Route planning schemas."""

from typing import List, Optional

from pydantic import BaseModel, Field


class Location(BaseModel):
    """Geographic location."""

    name: str
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)


class ChargingStop(BaseModel):
    """Charging stop in route."""

    station_id: str
    station_name: str
    location: Location
    arrival_soc: int = Field(ge=0, le=100)
    departure_soc: int = Field(ge=0, le=100)
    charging_duration_minutes: int
    charger_type: str  # supercharger, destination, third_party
    distance_from_start_km: float


class RoutePlanRequest(BaseModel):
    """Route planning request."""

    origin: Location
    destination: Location
    vehicle_id: Optional[int] = None
    initial_soc: int = Field(ge=0, le=100, description="Current battery SOC %")
    target_arrival_soc: int = Field(
        default=20, ge=0, le=100, description="Minimum SOC at destination"
    )
    min_charging_soc: int = Field(
        default=10, ge=0, le=100, description="Minimum SOC before charging"
    )
    prefer_supercharger: bool = Field(
        default=True, description="Prefer Tesla Superchargers"
    )


class RoutePlanResponse(BaseModel):
    """Route planning response."""

    origin: Location
    destination: Location
    total_distance_km: float
    total_duration_minutes: int
    driving_duration_minutes: int
    charging_duration_minutes: int
    charging_stops: List[ChargingStop]
    arrival_soc: int
    route_polyline: Optional[str] = None  # Encoded polyline
    warnings: List[str] = []
