"""Tesla data models."""

from typing import Optional

from pydantic import BaseModel


class TeslaVehicle(BaseModel):
    """Tesla vehicle model."""

    id: str
    vehicle_id: int
    vin: str
    display_name: str
    state: str  # online, asleep, offline


class ChargeState(BaseModel):
    """Vehicle charge state."""

    battery_level: int  # 0-100
    usable_battery_level: int  # 0-100
    battery_range: float  # miles
    est_battery_range: float  # miles
    ideal_battery_range: float  # miles
    charge_rate: float  # miles/hour when charging
    charger_power: int  # kW
    charging_state: str  # Charging, Complete, Disconnected, etc.
    time_to_full_charge: float  # hours


class DriveState(BaseModel):
    """Vehicle drive state."""

    latitude: float
    longitude: float
    heading: int  # 0-360 degrees
    speed: Optional[float] = None  # mph, None when parked
    power: Optional[int] = None  # kW power consumption
    timestamp: int  # Unix timestamp


class VehicleConfig(BaseModel):
    """Vehicle configuration."""

    car_type: str  # model3, modely, models, modelx
    car_special_type: str  # base, signature, etc.
    trim_badging: str  # 74d, 100d, p100d, etc.
    exterior_color: str
    wheel_type: str


class VehicleData(BaseModel):
    """Complete vehicle data."""

    id: str
    vehicle_id: int
    vin: str
    display_name: str
    state: str
    charge_state: Optional[ChargeState] = None
    drive_state: Optional[DriveState] = None
    vehicle_config: Optional[VehicleConfig] = None
