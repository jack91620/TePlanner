"""Charging station endpoints."""

from typing import Optional

from fastapi import APIRouter, Query

router = APIRouter()


@router.get("/stations")
async def search_stations(
    lat: float = Query(..., description="Latitude"),
    lng: float = Query(..., description="Longitude"),
    radius_km: float = Query(10, description="Search radius in km"),
    min_power_kw: Optional[int] = Query(None, description="Minimum charging power"),
):
    """Search charging stations near a location."""
    # TODO: Search from Tencent Map POI or operator APIs
    return {
        "stations": [
            {
                "id": "station_001",
                "name": "XX Service Area Charging Station",
                "operator": "State Grid",
                "latitude": lat + 0.01,
                "longitude": lng + 0.01,
                "power_kw": 120,
                "available_ports": 4,
                "total_ports": 8,
                "distance_km": 1.5,
            }
        ]
    }


@router.get("/stations/{station_id}")
async def get_station(station_id: str):
    """Get charging station details."""
    # TODO: Get station details
    return {
        "id": station_id,
        "name": "XX Service Area Charging Station",
        "operator": "State Grid",
        "address": "G4 Highway, XX Service Area",
        "latitude": 39.0,
        "longitude": 116.0,
        "power_kw": 120,
        "available_ports": 4,
        "total_ports": 8,
        "price_per_kwh": 1.5,
        "open_hours": "24/7",
    }


@router.get("/along-route")
async def search_along_route(
    polyline: str = Query(..., description="Route polyline"),
    min_power_kw: int = Query(60, description="Minimum charging power"),
):
    """Search charging stations along a route."""
    # TODO: Use Tencent Map along-route search API
    return {"stations": []}
