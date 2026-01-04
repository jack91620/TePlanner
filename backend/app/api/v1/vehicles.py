"""Vehicle management endpoints."""

from fastapi import APIRouter, Depends

router = APIRouter()


@router.get("/")
async def list_vehicles():
    """List user's Tesla vehicles."""
    # TODO: Get vehicles from Tesla API
    return {"vehicles": []}


@router.get("/{vehicle_id}")
async def get_vehicle(vehicle_id: str):
    """Get specific vehicle details."""
    # TODO: Get vehicle data from Tesla API
    return {
        "id": vehicle_id,
        "display_name": "My Tesla",
        "battery_level": 80,
        "battery_range": 350,
        "latitude": 39.9042,
        "longitude": 116.4074,
    }


@router.get("/{vehicle_id}/state")
async def get_vehicle_state(vehicle_id: str):
    """Get vehicle state (battery, location, etc.)."""
    # TODO: Get real-time state from Tesla API
    return {
        "vehicle_id": vehicle_id,
        "battery_level": 80,
        "usable_battery_level": 78,
        "battery_range": 350,
        "latitude": 39.9042,
        "longitude": 116.4074,
        "heading": 180,
        "speed": 0,
    }


@router.post("/{vehicle_id}/wake")
async def wake_vehicle(vehicle_id: str):
    """Wake up the vehicle."""
    # TODO: Call Tesla API to wake vehicle
    return {"vehicle_id": vehicle_id, "state": "online"}
