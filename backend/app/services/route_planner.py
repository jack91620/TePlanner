"""Route planning service."""

from typing import List, Optional

from app.schemas.route import (
    ChargingStop,
    Location,
    RoutePlanRequest,
    RoutePlanResponse,
)
from app.services.energy_model import EnergyModel


class RoutePlanner:
    """Plan routes with optimal charging stops."""

    def __init__(self):
        """Initialize route planner."""
        self.energy_model = EnergyModel()

    async def plan_route(
        self,
        request: RoutePlanRequest,
        car_type: Optional[str] = None,
    ) -> RoutePlanResponse:
        """Plan a route with charging stops.

        Args:
            request: Route planning request.
            car_type: Tesla model type for energy calculations.

        Returns:
            Route plan with charging stops.
        """
        # TODO: Integrate with Tencent Map API for actual routing
        # For now, return a placeholder response

        # Calculate straight-line distance (placeholder)
        distance_km = self._calculate_distance(
            request.origin.latitude,
            request.origin.longitude,
            request.destination.latitude,
            request.destination.longitude,
        )

        # Estimate driving time (assume 80 km/h average)
        driving_minutes = int(distance_km / 80 * 60)

        # Calculate energy consumption
        consumption = self.energy_model.calculate_consumption(
            distance_km=distance_km,
            car_type=car_type,
        )

        # Determine if charging is needed
        charging_stops: List[ChargingStop] = []
        charging_minutes = 0
        arrival_soc = request.initial_soc - int(consumption["soc_consumed"])
        warnings: List[str] = []

        if arrival_soc < request.target_arrival_soc:
            # Need charging stops
            warnings.append(
                f"Direct route would arrive with {arrival_soc}% SOC. "
                f"Charging stops recommended."
            )
            # TODO: Find optimal charging stations along route
            # This would integrate with charging station database

        if arrival_soc < 0:
            warnings.append(
                "Warning: Route may not be possible with current battery level. "
                "Please charge before departure."
            )
            arrival_soc = 0

        return RoutePlanResponse(
            origin=request.origin,
            destination=request.destination,
            total_distance_km=round(distance_km, 1),
            total_duration_minutes=driving_minutes + charging_minutes,
            driving_duration_minutes=driving_minutes,
            charging_duration_minutes=charging_minutes,
            charging_stops=charging_stops,
            arrival_soc=max(0, arrival_soc),
            warnings=warnings,
        )

    def _calculate_distance(
        self,
        lat1: float,
        lon1: float,
        lat2: float,
        lon2: float,
    ) -> float:
        """Calculate approximate distance using Haversine formula.

        Returns distance in kilometers.
        """
        import math

        R = 6371  # Earth's radius in km

        lat1_rad = math.radians(lat1)
        lat2_rad = math.radians(lat2)
        delta_lat = math.radians(lat2 - lat1)
        delta_lon = math.radians(lon2 - lon1)

        a = (
            math.sin(delta_lat / 2) ** 2
            + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(delta_lon / 2) ** 2
        )
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

        return R * c

    async def find_charging_stations(
        self,
        latitude: float,
        longitude: float,
        radius_km: float = 50,
        prefer_supercharger: bool = True,
    ) -> List[dict]:
        """Find charging stations near a location.

        Args:
            latitude: Center point latitude.
            longitude: Center point longitude.
            radius_km: Search radius in km.
            prefer_supercharger: Prefer Tesla Superchargers.

        Returns:
            List of charging stations.
        """
        # TODO: Integrate with charging station APIs
        # - Tesla Supercharger network
        # - Third-party networks (State Grid, etc.)
        return []
