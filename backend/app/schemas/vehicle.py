"""Vehicle schemas."""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class VehicleBase(BaseModel):
    """Base vehicle schema."""

    display_name: Optional[str] = None


class VehicleCreate(VehicleBase):
    """Vehicle creation schema (from Tesla API data)."""

    tesla_id: str
    tesla_vehicle_id: int
    vin: str
    car_type: Optional[str] = None


class VehicleResponse(VehicleBase):
    """Vehicle response schema."""

    id: int
    tesla_id: str
    vin: str
    car_type: Optional[str] = None
    battery_capacity_kwh: Optional[float] = None
    created_at: datetime

    model_config = {"from_attributes": True}


class VehicleStatus(BaseModel):
    """Vehicle current status."""

    id: int
    display_name: Optional[str]
    state: str  # online, asleep, offline
    battery_level: Optional[int] = None
    battery_range_km: Optional[float] = None
    charging_state: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
