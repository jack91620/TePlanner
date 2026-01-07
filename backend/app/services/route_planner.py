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
        vehicle_range_km: Optional[float] = None,
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
            vehicle_range_km: Actual vehicle range at 100% SOC (from Tesla API)
                             If provided, overrides car_type based calculations

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
        if vehicle_range_km and vehicle_range_km > 0:
            # Use actual range from Tesla API - more accurate
            soc_consumed = (total_distance_km / vehicle_range_km) * 100
        else:
            # Fallback to car_type based calculation
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
            vehicle_range_km=vehicle_range_km,
        )

        # Calculate total charging time
        total_charging_minutes = sum(stop.charging_duration_minutes for stop in charging_stops)

        # Calculate final arrival SOC
        final_arrival_soc = self._calculate_final_soc(
            initial_soc=initial_soc,
            total_distance_km=total_distance_km,
            charging_stops=charging_stops,
            car_type=car_type,
            vehicle_range_km=vehicle_range_km,
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
        vehicle_range_km: Optional[float] = None,
    ) -> List[ChargingStop]:
        """Find optimal charging stops along the route.

        Uses a two-step approach:
        1. First, search for all service areas with charging facilities along the route
        2. Then, use greedy algorithm to select optimal charging points based on range

        This ensures all charging stops are at highway service areas.

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
            vehicle_range_km: Actual vehicle range at 100% SOC (from Tesla API)

        Returns:
            List of charging stops (all at highway service areas)
        """
        map_client = await self._get_map_client()

        # Calculate max range based on vehicle_range_km or car_type specs
        if vehicle_range_km and vehicle_range_km > 0:
            full_range_km = vehicle_range_km
        else:
            specs = self.energy_model.get_vehicle_specs(car_type)
            battery_capacity = specs.get("battery_capacity_kwh", 60)
            consumption_per_km = specs.get("consumption_wh_per_km", 150) / 1000
            full_range_km = battery_capacity / consumption_per_km

        # Step 1: 先搜索整条路线沿途有充电设施的服务区
        polyline_str = self._build_polyline_string(polyline)
        service_areas = []

        if polyline_str:
            try:
                service_areas = await map_client.search_service_area_charging_along_route(
                    polyline=polyline_str
                )
            except Exception as e:
                print(f"搜索沿途服务区失败: {e}")

        # 计算每个服务区距离起点的距离
        for area in service_areas:
            area["distance_from_start_km"] = self._calculate_distance_along_route(
                polyline, area.get("location", {}), total_distance_km
            )

        # 按距离排序
        service_areas.sort(key=lambda x: x.get("distance_from_start_km", 0))

        # 如果没有找到服务区，返回空列表
        if not service_areas:
            return []

        # Step 2: 根据剩余续航从服务区列表中选择最优充电点
        charging_stops = []
        current_soc = initial_soc
        distance_traveled = 0

        while distance_traveled < total_distance_km:
            # 计算当前电量能开多远
            usable_soc = current_soc - min_charging_soc
            max_range_km = full_range_km * (usable_soc / 100)

            remaining_distance = total_distance_km - distance_traveled

            # 检查是否能直接到达目的地
            soc_to_destination = (remaining_distance / full_range_km) * 100
            if current_soc - soc_to_destination >= min_arrival_soc:
                break  # 可以到达，不需要更多充电

            # 从服务区列表中找到在可达范围内的最远服务区（贪心策略）
            best_area = None
            for area in service_areas:
                area_distance = area.get("distance_from_start_km", 0)
                # 服务区在当前位置之后，且在可达范围的90%以内
                if area_distance > distance_traveled + 10:  # 至少前进 10km
                    if area_distance <= distance_traveled + max_range_km * 0.9:
                        best_area = area  # 取最远的那个（贪心）

            if not best_area:
                # 没有找到合适的服务区，尝试找最近的一个
                for area in service_areas:
                    area_distance = area.get("distance_from_start_km", 0)
                    if area_distance > distance_traveled + 10:
                        best_area = area
                        break

            if not best_area:
                break  # 没有更多可用的服务区

            # 获取服务区信息
            area_location = best_area.get("location", {})
            station_lat = area_location.get("lat", 0)
            station_lng = area_location.get("lng", 0)
            station_distance = best_area.get("distance_from_start_km", 0)

            # 计算到达该服务区时的电量
            segment_distance = station_distance - distance_traveled
            soc_used = (segment_distance / full_range_km) * 100
            arrival_soc_at_station = current_soc - int(soc_used)
            arrival_soc_at_station = max(0, arrival_soc_at_station)

            # 计算充电时长（估算）
            estimated_battery_kwh = 70
            soc_to_add = target_charging_soc - arrival_soc_at_station
            energy_to_add = estimated_battery_kwh * (soc_to_add / 100)
            charging_minutes = int((energy_to_add / self.DEFAULT_CHARGING_POWER_KW) * 60)

            # 创建充电站记录
            charging_stop = ChargingStop(
                station_id=best_area.get("id", f"service_area_{len(charging_stops)}"),
                name=best_area.get("title", "服务区充电站"),
                latitude=station_lat,
                longitude=station_lng,
                distance_from_start_km=round(station_distance, 1),
                arrival_soc=arrival_soc_at_station,
                departure_soc=target_charging_soc,
                charging_duration_minutes=charging_minutes,
                operator=self._extract_operator(best_area.get("title", "")),
                address=best_area.get("address", ""),
            )

            charging_stops.append(charging_stop)

            # 更新状态
            distance_traveled = station_distance
            current_soc = target_charging_soc

            # 防止无限循环
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
        vehicle_range_km: Optional[float] = None,
    ) -> int:
        """Calculate the final SOC at destination.

        Args:
            initial_soc: Starting SOC
            total_distance_km: Total route distance
            charging_stops: List of charging stops
            car_type: Vehicle type
            vehicle_range_km: Actual vehicle range at 100% SOC (from Tesla API)

        Returns:
            Final SOC percentage
        """
        def calc_soc_consumed(distance_km: float) -> float:
            """Calculate SOC consumed for a given distance."""
            if vehicle_range_km and vehicle_range_km > 0:
                return (distance_km / vehicle_range_km) * 100
            else:
                consumption = self.energy_model.calculate_consumption(
                    distance_km=distance_km,
                    car_type=car_type,
                )
                return consumption["soc_consumed"]

        if not charging_stops:
            return max(0, initial_soc - int(calc_soc_consumed(total_distance_km)))

        # Calculate SOC at each segment
        current_soc = initial_soc
        previous_distance = 0

        for stop in charging_stops:
            segment_distance = stop.distance_from_start_km - previous_distance
            current_soc -= int(calc_soc_consumed(segment_distance))
            current_soc = stop.departure_soc  # Charge to departure SOC
            previous_distance = stop.distance_from_start_km

        # Final segment to destination
        final_segment = total_distance_km - previous_distance
        if final_segment > 0:
            current_soc -= int(calc_soc_consumed(final_segment))

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

    def _build_polyline_string(self, polyline: List) -> str:
        """构建 alongby API 需要的 polyline 字符串。

        Args:
            polyline: 路线点列表，可以是 (lat, lng) 元组或 {lat, lng} 字典

        Returns:
            逗号分隔的坐标串 "lat,lng,lat,lng,..."
            采样后约 200 个坐标点（client 会进行分段搜索）
        """
        if not polyline:
            return ""

        # 采样以控制坐标点数量
        # client.py 的 _search_along_route_segmented 会自动分段搜索
        # 200 个点可以较好地表示长途路线
        max_points = 200
        sample_step = max(1, len(polyline) // max_points)
        sampled_points = polyline[::sample_step][:max_points]

        coords = []
        for point in sampled_points:
            if isinstance(point, dict):
                lat = point.get("lat", 0)
                lng = point.get("lng", 0)
            elif isinstance(point, (list, tuple)) and len(point) >= 2:
                lat, lng = point[0], point[1]
            else:
                continue
            # 保留 6 位小数
            coords.append(f"{lat:.6f},{lng:.6f}")

        return ",".join(coords)

    def _calculate_distance_along_route(
        self,
        polyline: List,
        location: dict,
        total_distance_km: float,
    ) -> float:
        """计算某个位置沿路线距离起点的距离。

        通过在 polyline 中找到最近的点，然后估算距离。

        Args:
            polyline: 路线点列表
            location: 目标位置 {lat, lng}
            total_distance_km: 总路线距离

        Returns:
            距离起点的公里数
        """
        if not polyline or not location:
            return 0

        target_lat = location.get("lat", 0)
        target_lng = location.get("lng", 0)

        # 找到 polyline 中距离目标位置最近的点
        min_distance = float("inf")
        closest_index = 0

        for i, point in enumerate(polyline):
            if isinstance(point, dict):
                p_lat = point.get("lat", 0)
                p_lng = point.get("lng", 0)
            elif isinstance(point, (list, tuple)) and len(point) >= 2:
                p_lat, p_lng = point[0], point[1]
            else:
                continue

            dist = self._calculate_distance(target_lat, target_lng, p_lat, p_lng)
            if dist < min_distance:
                min_distance = dist
                closest_index = i

        # 根据在 polyline 中的位置估算距离
        fraction = closest_index / max(1, len(polyline) - 1)
        return fraction * total_distance_km
