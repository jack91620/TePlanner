"""Route planning service with charging optimization."""

import math
from typing import List, Optional, Tuple

from app.integrations.tencent_map.client import TencentMapClient
from app.services.energy_model import EnergyModel


class ChargingStop:
    """A charging stop in the route."""

    def __init__(
        self,
        station_id: str,
        name: str,
        latitude: float,
        longitude: float,
        distance_from_start_km: float,
        arrival_soc: int,
        departure_soc: int,
        charging_duration_minutes: int,
        operator: Optional[str] = None,
        address: Optional[str] = None,
    ):
        self.station_id = station_id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.distance_from_start_km = distance_from_start_km
        self.arrival_soc = arrival_soc
        self.departure_soc = departure_soc
        self.charging_duration_minutes = charging_duration_minutes
        self.operator = operator
        self.address = address

    def to_dict(self) -> dict:
        return {
            "station_id": self.station_id,
            "name": self.name,
            "latitude": self.latitude,
            "longitude": self.longitude,
            "distance_from_start_km": self.distance_from_start_km,
            "arrival_soc": self.arrival_soc,
            "departure_soc": self.departure_soc,
            "charging_duration_minutes": self.charging_duration_minutes,
            "operator": self.operator,
            "address": self.address,
        }


class RoutePlanResult:
    """Result of route planning."""

    def __init__(
        self,
        origin: Tuple[float, float],
        destination: Tuple[float, float],
        origin_name: str = "",
        destination_name: str = "",
        total_distance_km: float = 0,
        driving_duration_minutes: int = 0,
        charging_duration_minutes: int = 0,
        charging_stops: Optional[List[ChargingStop]] = None,
        arrival_soc: int = 0,
        initial_soc: int = 100,
        polyline: Optional[List] = None,
        warnings: Optional[List[str]] = None,
    ):
        self.origin = origin
        self.destination = destination
        self.origin_name = origin_name
        self.destination_name = destination_name
        self.total_distance_km = total_distance_km
        self.driving_duration_minutes = driving_duration_minutes
        self.charging_duration_minutes = charging_duration_minutes
        self.charging_stops = charging_stops or []
        self.arrival_soc = arrival_soc
        self.initial_soc = initial_soc
        self.polyline = polyline or []
        self.warnings = warnings or []

    @property
    def total_duration_minutes(self) -> int:
        return self.driving_duration_minutes + self.charging_duration_minutes

    def to_dict(self) -> dict:
        return {
            "origin": {"lat": self.origin[0], "lng": self.origin[1], "name": self.origin_name},
            "destination": {"lat": self.destination[0], "lng": self.destination[1], "name": self.destination_name},
            "total_distance_km": round(self.total_distance_km, 1),
            "total_duration_minutes": self.total_duration_minutes,
            "driving_duration_minutes": self.driving_duration_minutes,
            "charging_duration_minutes": self.charging_duration_minutes,
            "charging_stops": [stop.to_dict() for stop in self.charging_stops],
            "num_charging_stops": len(self.charging_stops),
            "initial_soc": self.initial_soc,
            "arrival_soc": self.arrival_soc,
            "warnings": self.warnings,
        }


class RoutePlanner:
    """Plan routes with optimal charging stops for Tesla vehicles."""

    # Default parameters
    DEFAULT_MIN_SOC = 10  # Minimum SOC before charging (%)
    DEFAULT_TARGET_SOC = 80  # Target SOC after charging (%)
    DEFAULT_ARRIVAL_SOC = 20  # Target arrival SOC at destination (%)
    DEFAULT_CHARGING_POWER_KW = 120  # Assumed average charging power

    def __init__(self):
        """Initialize route planner."""
        self.energy_model = EnergyModel()
        self.map_client: Optional[TencentMapClient] = None

    async def _get_map_client(self) -> TencentMapClient:
        """Get or create map client."""
        if self.map_client is None:
            self.map_client = TencentMapClient()
        return self.map_client

    async def close(self):
        """Close resources."""
        if self.map_client:
            await self.map_client.close()
            self.map_client = None

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        await self.close()

    async def plan_route(
        self,
        origin: Tuple[float, float],
        destination: Tuple[float, float],
        initial_soc: int = 100,
        car_type: str = "model_y_long_range",
        min_arrival_soc: int = DEFAULT_ARRIVAL_SOC,
        min_charging_soc: int = DEFAULT_MIN_SOC,
        target_charging_soc: int = DEFAULT_TARGET_SOC,
    ) -> RoutePlanResult:
        """Plan a route with optimal charging stops.

        Args:
            origin: (latitude, longitude) of start point
            destination: (latitude, longitude) of end point
            initial_soc: Current battery SOC (0-100)
            car_type: Tesla model type for energy calculations
            min_arrival_soc: Minimum SOC at destination
            min_charging_soc: Minimum SOC before stopping to charge
            target_charging_soc: Target SOC after charging

        Returns:
            RoutePlanResult with optimized charging stops
        """
        map_client = await self._get_map_client()

        # Step 1: Get driving route from map API
        route_data = await map_client.get_driving_route_detailed(
            origin=origin,
            destination=destination,
        )

        total_distance_km = route_data["distance"] / 1000
        driving_minutes = int(route_data["duration"] / 60)
        polyline = route_data.get("polyline", [])

        # Step 2: Get origin and destination names
        origin_name = ""
        destination_name = ""
        try:
            origin_geo = await map_client.reverse_geocode(origin[0], origin[1])
            origin_name = origin_geo.get("address", "")
        except Exception:
            pass
        try:
            dest_geo = await map_client.reverse_geocode(destination[0], destination[1])
            destination_name = dest_geo.get("address", "")
        except Exception:
            pass

        # Step 3: Calculate energy consumption
        consumption = self.energy_model.calculate_consumption(
            distance_km=total_distance_km,
            car_type=car_type,
        )
        soc_consumed = consumption["soc_consumed"]
        direct_arrival_soc = initial_soc - int(soc_consumed)

        warnings = []

        # Step 4: Check if charging is needed
        if direct_arrival_soc >= min_arrival_soc:
            # No charging needed
            return RoutePlanResult(
                origin=origin,
                destination=destination,
                origin_name=origin_name,
                destination_name=destination_name,
                total_distance_km=total_distance_km,
                driving_duration_minutes=driving_minutes,
                charging_duration_minutes=0,
                charging_stops=[],
                arrival_soc=max(0, direct_arrival_soc),
                initial_soc=initial_soc,
                polyline=polyline,
                warnings=warnings,
            )

        # Step 5: Need charging - find optimal stops
        charging_stops = await self._find_optimal_charging_stops(
            origin=origin,
            destination=destination,
            polyline=polyline,
            total_distance_km=total_distance_km,
            initial_soc=initial_soc,
            car_type=car_type,
            min_charging_soc=min_charging_soc,
            target_charging_soc=target_charging_soc,
            min_arrival_soc=min_arrival_soc,
        )

        # Calculate total charging time
        total_charging_minutes = sum(stop.charging_duration_minutes for stop in charging_stops)

        # Calculate final arrival SOC
        final_arrival_soc = self._calculate_final_soc(
            initial_soc=initial_soc,
            total_distance_km=total_distance_km,
            charging_stops=charging_stops,
            car_type=car_type,
        )

        if final_arrival_soc < min_arrival_soc:
            warnings.append(
                f"规划的路线可能无法达到目标到达电量 {min_arrival_soc}%。"
                f"预计到达电量: {final_arrival_soc}%"
            )

        if not charging_stops:
            warnings.append(
                f"未找到合适的充电站。直接行驶将在到达时剩余 {direct_arrival_soc}% 电量。"
            )

        return RoutePlanResult(
            origin=origin,
            destination=destination,
            origin_name=origin_name,
            destination_name=destination_name,
            total_distance_km=total_distance_km,
            driving_duration_minutes=driving_minutes,
            charging_duration_minutes=total_charging_minutes,
            charging_stops=charging_stops,
            arrival_soc=final_arrival_soc,
            initial_soc=initial_soc,
            polyline=polyline,
            warnings=warnings,
        )

    async def _find_optimal_charging_stops(
        self,
        origin: Tuple[float, float],
        destination: Tuple[float, float],
        polyline: List,
        total_distance_km: float,
        initial_soc: int,
        car_type: str,
        min_charging_soc: int,
        target_charging_soc: int,
        min_arrival_soc: int,
    ) -> List[ChargingStop]:
        """Find optimal charging stops along the route.

        Uses a greedy algorithm:
        1. Calculate how far we can drive before needing to charge
        2. Find charging stations near that point
        3. Select the best one and repeat

        Args:
            origin: Start point
            destination: End point
            polyline: Route polyline points
            total_distance_km: Total route distance
            initial_soc: Starting SOC
            car_type: Vehicle type
            min_charging_soc: Minimum SOC before charging
            target_charging_soc: Target SOC after charging
            min_arrival_soc: Target arrival SOC

        Returns:
            List of charging stops
        """
        map_client = await self._get_map_client()

        # Get vehicle specs
        specs = self.energy_model.get_vehicle_specs(car_type)
        battery_capacity = specs["battery_capacity_kwh"]
        consumption_per_km = specs["consumption_wh_per_km"] / 1000  # Convert to kWh/km

        charging_stops = []
        current_soc = initial_soc
        distance_traveled = 0

        while distance_traveled < total_distance_km:
            # Calculate how far we can go with current SOC
            usable_soc = current_soc - min_charging_soc
            usable_energy = battery_capacity * (usable_soc / 100)
            max_range_km = usable_energy / consumption_per_km

            remaining_distance = total_distance_km - distance_traveled

            # Check if we can reach destination
            energy_to_destination = remaining_distance * consumption_per_km
            soc_to_destination = (energy_to_destination / battery_capacity) * 100

            if current_soc - soc_to_destination >= min_arrival_soc:
                # Can reach destination without more charging
                break

            # Need to charge - find a station
            target_distance = distance_traveled + max_range_km * 0.8  # 80% of max range

            if target_distance >= total_distance_km:
                target_distance = total_distance_km * 0.7  # Charge at 70% of total distance

            # Find point along route at target distance
            target_point = self._get_point_at_distance(
                polyline, distance_traveled, target_distance, total_distance_km
            )

            if target_point is None:
                break

            # Search for charging stations near this point
            try:
                stations = await map_client.search_charging_stations(
                    latitude=target_point[0],
                    longitude=target_point[1],
                    radius=20000,  # 20km radius
                )
            except Exception:
                stations = []

            if not stations:
                # Try searching at midpoint
                midpoint = self._get_point_at_distance(
                    polyline, 0, total_distance_km / 2, total_distance_km
                )
                if midpoint:
                    try:
                        stations = await map_client.search_charging_stations(
                            latitude=midpoint[0],
                            longitude=midpoint[1],
                            radius=30000,
                        )
                    except Exception:
                        pass

            if not stations:
                break

            # Select best station (closest to target point)
            best_station = stations[0]
            station_location = best_station.get("location", {})
            station_lat = station_location.get("lat", target_point[0])
            station_lng = station_location.get("lng", target_point[1])

            # Calculate distance to station
            distance_to_station = self._calculate_distance(
                origin[0] if not charging_stops else charging_stops[-1].latitude,
                origin[1] if not charging_stops else charging_stops[-1].longitude,
                station_lat,
                station_lng,
            )

            # Approximate station's position along route
            station_distance = distance_traveled + distance_to_station

            # Calculate arrival SOC at station
            energy_used = distance_to_station * consumption_per_km
            arrival_soc_at_station = current_soc - int((energy_used / battery_capacity) * 100)
            arrival_soc_at_station = max(0, arrival_soc_at_station)

            # Calculate charging time (rough estimate)
            soc_to_add = target_charging_soc - arrival_soc_at_station
            energy_to_add = battery_capacity * (soc_to_add / 100)
            charging_minutes = int((energy_to_add / self.DEFAULT_CHARGING_POWER_KW) * 60)

            charging_stop = ChargingStop(
                station_id=best_station.get("id", f"station_{len(charging_stops)}"),
                name=best_station.get("title", "充电站"),
                latitude=station_lat,
                longitude=station_lng,
                distance_from_start_km=round(station_distance, 1),
                arrival_soc=arrival_soc_at_station,
                departure_soc=target_charging_soc,
                charging_duration_minutes=charging_minutes,
                operator=self._extract_operator(best_station.get("title", "")),
                address=best_station.get("address", ""),
            )

            charging_stops.append(charging_stop)

            # Update state
            distance_traveled = station_distance
            current_soc = target_charging_soc

            # Prevent infinite loop
            if len(charging_stops) >= 10:
                break

        return charging_stops

    def _get_point_at_distance(
        self,
        polyline: List,
        current_distance: float,
        target_distance: float,
        total_distance: float,
    ) -> Optional[Tuple[float, float]]:
        """Get a point along the polyline at a specific distance.

        Args:
            polyline: List of (lat, lng) points
            current_distance: Current distance from start
            target_distance: Target distance from start
            total_distance: Total route distance

        Returns:
            (latitude, longitude) tuple or None
        """
        if not polyline:
            return None

        # Estimate position as fraction of route
        fraction = target_distance / total_distance
        fraction = max(0, min(1, fraction))

        index = int(fraction * (len(polyline) - 1))
        index = max(0, min(len(polyline) - 1, index))

        point = polyline[index]
        if isinstance(point, dict):
            return (point.get("lat", 0), point.get("lng", 0))
        elif isinstance(point, (list, tuple)) and len(point) >= 2:
            return (point[0], point[1])

        return None

    def _calculate_distance(
        self,
        lat1: float,
        lon1: float,
        lat2: float,
        lon2: float,
    ) -> float:
        """Calculate distance between two points using Haversine formula.

        Returns distance in kilometers.
        """
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

    def _calculate_final_soc(
        self,
        initial_soc: int,
        total_distance_km: float,
        charging_stops: List[ChargingStop],
        car_type: str,
    ) -> int:
        """Calculate the final SOC at destination.

        Args:
            initial_soc: Starting SOC
            total_distance_km: Total route distance
            charging_stops: List of charging stops
            car_type: Vehicle type

        Returns:
            Final SOC percentage
        """
        if not charging_stops:
            consumption = self.energy_model.calculate_consumption(
                distance_km=total_distance_km,
                car_type=car_type,
            )
            return max(0, initial_soc - int(consumption["soc_consumed"]))

        # Calculate SOC at each segment
        current_soc = initial_soc
        previous_distance = 0

        for stop in charging_stops:
            segment_distance = stop.distance_from_start_km - previous_distance
            consumption = self.energy_model.calculate_consumption(
                distance_km=segment_distance,
                car_type=car_type,
            )
            current_soc -= int(consumption["soc_consumed"])
            current_soc = stop.departure_soc  # Charge to departure SOC
            previous_distance = stop.distance_from_start_km

        # Final segment to destination
        final_segment = total_distance_km - previous_distance
        if final_segment > 0:
            consumption = self.energy_model.calculate_consumption(
                distance_km=final_segment,
                car_type=car_type,
            )
            current_soc -= int(consumption["soc_consumed"])

        return max(0, current_soc)

    def _extract_operator(self, name: str) -> Optional[str]:
        """Extract operator name from station name."""
        if "国家电网" in name or "国网" in name:
            return "国家电网"
        elif "特来电" in name:
            return "特来电"
        elif "星星充电" in name:
            return "星星充电"
        elif "特斯拉" in name or "Tesla" in name.lower():
            return "特斯拉超级充电"
        elif "小鹏" in name:
            return "小鹏充电"
        elif "蔚来" in name or "NIO" in name.upper():
            return "蔚来换电站"
        return None
