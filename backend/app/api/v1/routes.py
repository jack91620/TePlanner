"""Route planning endpoints."""

import json
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user, get_current_user_optional, get_db, get_tesla_client
from app.db.models import RoutePlan, User, Vehicle
from app.integrations.tesla import TeslaClient
from app.integrations.tesla.exceptions import TeslaAPIError, TeslaVehicleOfflineError
from app.integrations.tencent_map.client import TencentMapClient
from app.services.route_planner import RoutePlanner

router = APIRouter()


class LocationInput(BaseModel):
    """Location input model."""

    latitude: float = Field(..., description="Latitude")
    longitude: float = Field(..., description="Longitude")
    address: Optional[str] = Field(None, description="Address (optional)")


class RoutePlanRequest(BaseModel):
    """Route planning request."""

    origin: Optional[LocationInput] = Field(None, description="Origin location. If not provided, uses vehicle's current location")
    destination: LocationInput = Field(..., description="Destination location")
    vehicle_id: Optional[str] = Field(None, description="Vehicle ID. Required if origin not provided")
    current_soc: Optional[int] = Field(None, ge=0, le=100, description="Current SOC. If not provided, fetches from vehicle")
    car_type: str = Field("model_y_long_range", description="Car type for energy calculation")
    min_arrival_soc: int = Field(20, ge=5, le=50, description="Minimum SOC at arrival")


class ChargingStopResponse(BaseModel):
    """Charging stop in route."""

    station_id: str
    name: str
    latitude: float
    longitude: float
    address: Optional[str] = None
    operator: Optional[str] = None
    distance_from_start_km: float
    arrival_soc: int
    departure_soc: int
    charging_duration_minutes: int


class RoutePlanResponse(BaseModel):
    """Route planning response."""

    route_id: Optional[int] = None
    origin: dict
    destination: dict
    total_distance_km: float
    total_duration_minutes: int
    driving_duration_minutes: int
    charging_duration_minutes: int
    charging_stops: List[ChargingStopResponse]
    num_charging_stops: int
    initial_soc: int
    arrival_soc: int
    warnings: List[str] = []


class NavigateRouteRequest(BaseModel):
    """Request to send route to vehicle."""

    vehicle_id: str
    waypoints: Optional[List[LocationInput]] = None  # If not provided, uses charging stops


class GeocodeRequest(BaseModel):
    """Geocode request."""

    address: str


class GeocodeResponse(BaseModel):
    """Geocode response."""

    latitude: float
    longitude: float
    address: str
    formatted_address: Optional[str] = None


@router.post("/plan", response_model=RoutePlanResponse)
async def plan_route(
    request: RoutePlanRequest,
    user: Optional[User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_db),
):
    """Plan a charging route.

    Plans an optimal route with charging stops. Can optionally:
    - Use vehicle's current location as origin
    - Fetch current SOC from vehicle
    - Save the plan to database for authenticated users
    """
    origin_lat = None
    origin_lng = None
    current_soc = request.current_soc or 100

    # Get origin from request or vehicle
    if request.origin:
        origin_lat = request.origin.latitude
        origin_lng = request.origin.longitude
    elif request.vehicle_id and user:
        # Try to get vehicle's current location
        try:
            from app.core.deps import get_tesla_client as _get_client

            # Get Tesla token for user
            from app.db.models import TeslaToken
            from app.core.security import TokenEncryption

            result = await db.execute(
                select(TeslaToken)
                .where(TeslaToken.user_id == user.id)
                .order_by(TeslaToken.updated_at.desc())
            )
            tesla_token = result.scalar_one_or_none()

            if tesla_token:
                encryption = TokenEncryption()
                try:
                    access_token = encryption.decrypt(tesla_token.access_token)
                except Exception:
                    access_token = tesla_token.access_token

                async with TeslaClient(access_token=access_token) as client:
                    vehicle_data = await client.get_vehicle_data(
                        request.vehicle_id,
                        endpoints=["drive_state", "location_data", "charge_state"],
                    )
                    response = vehicle_data.get("response", {})
                    drive_state = response.get("drive_state", {})
                    charge_state = response.get("charge_state", {})

                    origin_lat = drive_state.get("latitude")
                    origin_lng = drive_state.get("longitude")

                    # Also get SOC if not provided
                    if request.current_soc is None:
                        current_soc = charge_state.get("usable_battery_level") or \
                                     charge_state.get("battery_level") or 100
        except Exception as e:
            # Fall through to error
            pass

    if origin_lat is None or origin_lng is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Origin location required. Provide origin coordinates or vehicle_id.",
        )

    # Plan the route
    try:
        async with RoutePlanner() as planner:
            result = await planner.plan_route(
                origin=(origin_lat, origin_lng),
                destination=(request.destination.latitude, request.destination.longitude),
                initial_soc=current_soc,
                car_type=request.car_type,
                min_arrival_soc=request.min_arrival_soc,
            )

            # Save to database if user is authenticated
            route_id = None
            if user:
                route_plan = RoutePlan(
                    user_id=user.id,
                    origin_lat=origin_lat,
                    origin_lng=origin_lng,
                    origin_address=result.origin_name,
                    dest_lat=request.destination.latitude,
                    dest_lng=request.destination.longitude,
                    dest_address=result.destination_name,
                    total_distance_km=result.total_distance_km,
                    total_duration_minutes=result.total_duration_minutes,
                    charging_stops_json=json.dumps([s.to_dict() for s in result.charging_stops]),
                    polyline_json=json.dumps(result.polyline) if result.polyline else None,
                    status="completed",
                )
                db.add(route_plan)
                await db.commit()
                await db.refresh(route_plan)
                route_id = route_plan.id

            return RoutePlanResponse(
                route_id=route_id,
                origin=result.to_dict()["origin"],
                destination=result.to_dict()["destination"],
                total_distance_km=result.total_distance_km,
                total_duration_minutes=result.total_duration_minutes,
                driving_duration_minutes=result.driving_duration_minutes,
                charging_duration_minutes=result.charging_duration_minutes,
                charging_stops=[
                    ChargingStopResponse(
                        station_id=s.station_id,
                        name=s.name,
                        latitude=s.latitude,
                        longitude=s.longitude,
                        address=s.address,
                        operator=s.operator,
                        distance_from_start_km=s.distance_from_start_km,
                        arrival_soc=s.arrival_soc,
                        departure_soc=s.departure_soc,
                        charging_duration_minutes=s.charging_duration_minutes,
                    )
                    for s in result.charging_stops
                ],
                num_charging_stops=len(result.charging_stops),
                initial_soc=result.initial_soc,
                arrival_soc=result.arrival_soc,
                warnings=result.warnings,
            )

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Route planning failed: {str(e)}",
        )


@router.post("/navigate")
async def navigate_route(
    request: NavigateRouteRequest,
    user: User = Depends(get_current_user),
    tesla_client: TeslaClient = Depends(get_tesla_client),
):
    """Send planned route to vehicle.

    Sends navigation waypoints to the vehicle's navigation system.
    By default, sends the charging stops as waypoints.
    """
    waypoints = request.waypoints or []

    if not waypoints:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No waypoints to send. Provide waypoints or ensure route has charging stops.",
        )

    try:
        async with tesla_client:
            results = []
            for i, wp in enumerate(waypoints):
                await tesla_client.navigation_gps_request(
                    vehicle_tag=request.vehicle_id,
                    latitude=wp.latitude,
                    longitude=wp.longitude,
                    order=i + 1,
                )
                results.append({
                    "order": i + 1,
                    "latitude": wp.latitude,
                    "longitude": wp.longitude,
                    "status": "sent",
                })

            return {
                "success": True,
                "message": f"Sent {len(waypoints)} waypoints to vehicle",
                "waypoints": results,
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


@router.post("/navigate/{route_id}")
async def navigate_saved_route(
    route_id: int,
    user: User = Depends(get_current_user),
    tesla_client: TeslaClient = Depends(get_tesla_client),
    db: AsyncSession = Depends(get_db),
):
    """Send a saved route to vehicle.

    Retrieves the route from database and sends charging stops as waypoints.
    """
    # Get the route
    result = await db.execute(
        select(RoutePlan).where(
            RoutePlan.id == route_id,
            RoutePlan.user_id == user.id,
        )
    )
    route = result.scalar_one_or_none()

    if not route:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Route not found",
        )

    # Get user's primary vehicle if not specified
    result = await db.execute(
        select(Vehicle).where(
            Vehicle.user_id == user.id,
            Vehicle.is_primary == True,
        )
    )
    vehicle = result.scalar_one_or_none()

    if not vehicle:
        # Get first vehicle
        result = await db.execute(
            select(Vehicle).where(Vehicle.user_id == user.id).limit(1)
        )
        vehicle = result.scalar_one_or_none()

    if not vehicle:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No vehicle found. Please link a Tesla vehicle first.",
        )

    # Parse charging stops
    charging_stops = []
    if route.charging_stops_json:
        try:
            charging_stops = json.loads(route.charging_stops_json)
        except json.JSONDecodeError:
            pass

    # Build waypoints: charging stops + final destination
    waypoints = []
    for stop in charging_stops:
        waypoints.append({
            "latitude": stop["latitude"],
            "longitude": stop["longitude"],
            "name": stop.get("name", "Charging Stop"),
        })

    # Add final destination
    waypoints.append({
        "latitude": route.dest_lat,
        "longitude": route.dest_lng,
        "name": route.dest_address or "Destination",
    })

    try:
        async with tesla_client:
            results = []
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

            # Update route status
            route.status = "sent_to_car"
            await db.commit()

            return {
                "success": True,
                "message": f"Sent route to vehicle {vehicle.display_name}",
                "vehicle_id": vehicle.vehicle_id,
                "waypoints": results,
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


@router.get("/saved/{route_id}", response_model=RoutePlanResponse)
async def get_route(
    route_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get a saved route plan."""
    result = await db.execute(
        select(RoutePlan).where(
            RoutePlan.id == route_id,
            RoutePlan.user_id == user.id,
        )
    )
    route = result.scalar_one_or_none()

    if not route:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Route not found",
        )

    # Parse charging stops
    charging_stops = []
    if route.charging_stops_json:
        try:
            stops_data = json.loads(route.charging_stops_json)
            charging_stops = [
                ChargingStopResponse(
                    station_id=s.get("station_id", ""),
                    name=s.get("name", ""),
                    latitude=s.get("latitude", 0),
                    longitude=s.get("longitude", 0),
                    address=s.get("address"),
                    operator=s.get("operator"),
                    distance_from_start_km=s.get("distance_from_start_km", 0),
                    arrival_soc=s.get("arrival_soc", 0),
                    departure_soc=s.get("departure_soc", 0),
                    charging_duration_minutes=s.get("charging_duration_minutes", 0),
                )
                for s in stops_data
            ]
        except json.JSONDecodeError:
            pass

    return RoutePlanResponse(
        route_id=route.id,
        origin={
            "lat": route.origin_lat,
            "lng": route.origin_lng,
            "name": route.origin_address or "",
        },
        destination={
            "lat": route.dest_lat,
            "lng": route.dest_lng,
            "name": route.dest_address or "",
        },
        total_distance_km=route.total_distance_km or 0,
        total_duration_minutes=route.total_duration_minutes or 0,
        driving_duration_minutes=route.total_duration_minutes or 0,  # Approximate
        charging_duration_minutes=0,
        charging_stops=charging_stops,
        num_charging_stops=len(charging_stops),
        initial_soc=100,  # Not stored
        arrival_soc=20,  # Not stored
        warnings=[],
    )


@router.get("/")
async def list_routes(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    limit: int = 10,
    offset: int = 0,
):
    """List user's saved routes."""
    result = await db.execute(
        select(RoutePlan)
        .where(RoutePlan.user_id == user.id)
        .order_by(RoutePlan.created_at.desc())
        .limit(limit)
        .offset(offset)
    )
    routes = result.scalars().all()

    return {
        "count": len(routes),
        "routes": [
            {
                "id": r.id,
                "origin": {
                    "lat": r.origin_lat,
                    "lng": r.origin_lng,
                    "address": r.origin_address,
                },
                "destination": {
                    "lat": r.dest_lat,
                    "lng": r.dest_lng,
                    "address": r.dest_address,
                },
                "total_distance_km": r.total_distance_km,
                "total_duration_minutes": r.total_duration_minutes,
                "status": r.status,
                "created_at": r.created_at.isoformat() if r.created_at else None,
            }
            for r in routes
        ],
    }


@router.post("/geocode", response_model=GeocodeResponse)
async def geocode_address(request: GeocodeRequest):
    """Convert address to coordinates.

    Useful for getting coordinates from user-entered addresses.
    """
    try:
        async with TencentMapClient() as client:
            result = await client.geocode(request.address)

            location = result.get("location", {})
            lat = location.get("lat", 0)
            lng = location.get("lng", 0)

            if lat == 0 and lng == 0:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Address not found",
                )

            return GeocodeResponse(
                latitude=lat,
                longitude=lng,
                address=request.address,
                formatted_address=result.get("address", request.address),
            )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Geocoding failed: {str(e)}",
        )


@router.post("/reverse-geocode")
async def reverse_geocode(
    latitude: float,
    longitude: float,
):
    """Convert coordinates to address.

    Useful for displaying readable location names.
    """
    try:
        async with TencentMapClient() as client:
            result = await client.reverse_geocode(latitude, longitude)

            return {
                "latitude": latitude,
                "longitude": longitude,
                "address": result.get("address", ""),
                "formatted_address": result.get("formatted_addresses", {}).get("recommend", ""),
                "components": result.get("address_component", {}),
            }

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Reverse geocoding failed: {str(e)}",
        )


@router.get("/search")
async def search_places(
    keyword: str,
    location: Optional[str] = None,
):
    """Search for places by keyword.

    Args:
        keyword: Search keyword (e.g., city name, POI name)
        location: Optional center location "lat,lng" for distance calculation

    Returns:
        List of matching places with name, address, location and distance
    """
    from app.config import settings

    # Check if API key is configured
    if not settings.TENCENT_MAP_KEY and not settings.TENCENT_MAP_API_KEY:
        return {"results": []}

    try:
        async with TencentMapClient() as client:
            # Parse center location for distance calculation
            center_lat, center_lng = None, None
            if location:
                try:
                    parts = location.split(",")
                    center_lat = float(parts[0])
                    center_lng = float(parts[1])
                except (ValueError, IndexError):
                    pass

            # Use suggestion API or search nearby
            if center_lat and center_lng:
                pois = await client.search_nearby(
                    latitude=center_lat,
                    longitude=center_lng,
                    keyword=keyword,
                    radius=500000,  # 500km radius
                    page_size=10,
                )
            else:
                # Fallback to geocode for the keyword
                result = await client.geocode(keyword)
                if result and result.get("location"):
                    loc = result["location"]
                    return {
                        "results": [{
                            "id": "geo_1",
                            "title": result.get("title", keyword),
                            "name": result.get("title", keyword),
                            "address": result.get("address", keyword),
                            "location": {"lat": loc.get("lat"), "lng": loc.get("lng")},
                            "distance_km": None,
                        }]
                    }
                return {"results": []}

            # Format results
            results = []
            for poi in pois:
                loc = poi.get("location", {})
                lat = loc.get("lat", 0)
                lng = loc.get("lng", 0)

                # Calculate distance if center provided
                distance_km = None
                if center_lat and center_lng and lat and lng:
                    import math
                    R = 6371
                    dlat = math.radians(lat - center_lat)
                    dlng = math.radians(lng - center_lng)
                    a = math.sin(dlat/2)**2 + math.cos(math.radians(center_lat)) * math.cos(math.radians(lat)) * math.sin(dlng/2)**2
                    distance_km = round(R * 2 * math.atan2(math.sqrt(a), math.sqrt(1-a)))

                results.append({
                    "id": poi.get("id", ""),
                    "title": poi.get("title", ""),
                    "name": poi.get("title", ""),
                    "address": poi.get("address", ""),
                    "location": {"lat": lat, "lng": lng},
                    "distance_km": distance_km,
                })

            return {"results": results}

    except Exception as e:
        import logging
        logging.error(f"Place search failed: {str(e)}")
        return {"results": []}
