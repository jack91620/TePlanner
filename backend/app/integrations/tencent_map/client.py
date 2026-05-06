"""Tencent Map API client."""

from typing import Any, Dict, List, Optional, Tuple

import httpx

from app.config import settings


class TencentMapClient:
    """Client for Tencent Map Web Service API.

    Provides access to:
    - Geocoding (address to coordinates)
    - Reverse geocoding (coordinates to address)
    - Driving route planning
    - POI search (nearby and along route)
    """

    BASE_URL = "https://apis.map.qq.com"

    def __init__(self, api_key: Optional[str] = None):
        """Initialize Tencent Map client.

        Args:
            api_key: Optional API key, defaults to settings.TENCENT_MAP_API_KEY
        """
        self.api_key = api_key or settings.TENCENT_MAP_API_KEY or settings.TENCENT_MAP_KEY
        self._client: Optional[httpx.AsyncClient] = None

    async def _get_client(self) -> httpx.AsyncClient:
        """Get or create HTTP client."""
        if self._client is None:
            self._client = httpx.AsyncClient(
                base_url=self.BASE_URL,
                timeout=30.0,
            )
        return self._client

    async def close(self):
        """Close the HTTP client."""
        if self._client:
            await self._client.aclose()
            self._client = None

    async def __aenter__(self):
        """Async context manager entry."""
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Async context manager exit."""
        await self.close()

    async def _request(
        self,
        endpoint: str,
        params: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """Make API request."""
        client = await self._get_client()
        params = params or {}
        params["key"] = self.api_key

        response = await client.get(endpoint, params=params)
        response.raise_for_status()
        data = response.json()

        if data.get("status") != 0:
            raise Exception(f"Tencent Map API error: {data.get('message')}")

        return data

    async def geocode(self, address: str) -> Dict[str, Any]:
        """Convert address to coordinates.

        Args:
            address: Address string.

        Returns:
            Location data with lat/lng.
        """
        data = await self._request(
            "/ws/geocoder/v1/",
            params={"address": address},
        )
        return data.get("result", {})

    async def reverse_geocode(
        self,
        latitude: float,
        longitude: float,
    ) -> Dict[str, Any]:
        """Convert coordinates to address.

        Args:
            latitude: Latitude.
            longitude: Longitude.

        Returns:
            Address data.
        """
        data = await self._request(
            "/ws/geocoder/v1/",
            params={"location": f"{latitude},{longitude}"},
        )
        return data.get("result", {})

    async def driving_route(
        self,
        origin: tuple,
        destination: tuple,
        waypoints: Optional[List[tuple]] = None,
    ) -> Dict[str, Any]:
        """Get driving route.

        Args:
            origin: (latitude, longitude) tuple.
            destination: (latitude, longitude) tuple.
            waypoints: Optional list of waypoints.

        Returns:
            Route data with distance, duration, polyline.
        """
        params = {
            "from": f"{origin[0]},{origin[1]}",
            "to": f"{destination[0]},{destination[1]}",
        }

        if waypoints:
            wp_str = ";".join(f"{lat},{lng}" for lat, lng in waypoints)
            params["waypoints"] = wp_str

        data = await self._request("/ws/direction/v1/driving/", params=params)
        return data.get("result", {})

    async def search_nearby(
        self,
        latitude: float,
        longitude: float,
        keyword: str,
        radius: int = 5000,
        page_size: int = 20,
        page_index: int = 1,
    ) -> List[Dict[str, Any]]:
        """Search for POIs near a location.

        Args:
            latitude: Center latitude.
            longitude: Center longitude.
            keyword: Search keyword (e.g., "充电站").
            radius: Search radius in meters.
            page_size: Number of results per page (max 20).
            page_index: Page number (starting from 1).

        Returns:
            List of POI results.
        """
        data = await self._request(
            "/ws/place/v1/search",
            params={
                "keyword": keyword,
                "boundary": f"nearby({latitude},{longitude},{radius})",
                "page_size": min(page_size, 20),
                "page_index": page_index,
            },
        )
        return data.get("data", [])

    # 沿途搜索专用 KEY（需单独申请开通）
    async def search_along_route(
        self,
        polyline: str,
        keyword: str = "服务区",
    ) -> List[Dict[str, Any]]:
        """沿路线搜索 POI（使用 alongby 接口）。

        Args:
            polyline: 路线坐标串 "lat,lng,lat,lng,..." (逗号分隔)
            keyword: 搜索关键词（服务区/充电站/加油站等）
                支持的关键词: 充电站、厕所、停车场、购物、加油站、
                银行ATM、加气站、便利店、服务区、汽车维修、中石油、中石化

        Returns:
            List of POI results along the route.
        """
        # The alongby endpoint is a "Webservice API" feature on
        # Tencent's developer console — it has to be explicitly
        # enabled for the key. We use the same key as the rest of
        # the integration (settings.TENCENT_MAP_API_KEY) so a single
        # configuration works for everything.
        client = await self._get_client()
        params = {
            "keyword": keyword,
            "polyline": polyline,
            "key": self.api_key,
        }

        response = await client.get("/ws/place/v1/alongby", params=params)
        response.raise_for_status()
        data = response.json()

        if data.get("status") != 0:
            raise Exception(f"Tencent Map alongby API error: {data.get('message')}")

        return data.get("result", [])

    async def search_along_route_via_nearby(
        self,
        polyline_points: List[Tuple[float, float]],
        keyword: str = "充电站",
        radius_m: int = 3000,
        sample_every: int = 6,
    ) -> List[Dict[str, Any]]:
        """Fallback when `alongby` is disabled on the key — sample
        every `sample_every`th polyline point and call the regular
        `place/v1/search` (region/nearby) for each, then merge + dedup.

        Slower than alongby but only depends on the geocoder API
        which is on by default.
        """
        if not polyline_points:
            return []

        seen: Dict[str, Dict[str, Any]] = {}
        # Sample the polyline so we don't hammer the API.
        sampled = polyline_points[::max(1, sample_every)]
        for lat, lng in sampled:
            try:
                results = await self.search_nearby(
                    latitude=lat,
                    longitude=lng,
                    keyword=keyword,
                    radius=radius_m,
                )
            except Exception as e:
                # Keep going — partial results are better than none.
                print(f"[along-route fallback] nearby({lat:.4f},{lng:.4f}) failed: {e}")
                continue
            for poi in results:
                pid = poi.get("id")
                if pid and pid not in seen:
                    seen[pid] = poi
        return list(seen.values())

    async def search_charging_stations(
        self,
        latitude: float,
        longitude: float,
        radius: int = 10000,
    ) -> List[Dict[str, Any]]:
        """Search for charging stations near a location.

        Args:
            latitude: Center latitude.
            longitude: Center longitude.
            radius: Search radius in meters (default 10km).

        Returns:
            List of charging station POIs.
        """
        return await self.search_nearby(
            latitude=latitude,
            longitude=longitude,
            keyword="充电站",
            radius=radius,
        )

    async def search_service_areas(
        self,
        latitude: float,
        longitude: float,
        radius: int = 50000,
    ) -> List[Dict[str, Any]]:
        """Search for highway service areas near a location.

        Args:
            latitude: Center latitude.
            longitude: Center longitude.
            radius: Search radius in meters (default 50km).

        Returns:
            List of service area POIs.
        """
        return await self.search_nearby(
            latitude=latitude,
            longitude=longitude,
            keyword="服务区",
            radius=radius,
        )

    async def search_service_area_charging_along_route(
        self,
        polyline: str,
    ) -> List[Dict[str, Any]]:
        """沿路线搜索充电站。

        直接使用 alongby 接口搜索"充电站"，
        因为是沿路线搜索，结果自然就是高速沿途的充电站。

        Args:
            polyline: 路线坐标串 "lat,lng,lat,lng,..." (逗号分隔)

        Returns:
            充电站列表，每个元素包含:
            - id: 充电站ID
            - title: 充电站名称
            - location: 位置 {lat, lng}
            - address: 地址
        """
        # 直接搜索沿途充电站（分段搜索以避免 URL 过长）
        stations = await self._search_along_route_segmented(
            polyline=polyline,
            keyword="充电站",
        )

        # If the alongby endpoint isn't enabled on the key, every
        # segment fails and we get an empty list. Fall back to
        # `search_nearby` at sampled polyline points — slower but
        # only requires the geocoder API which is on by default.
        if not stations:
            print("[along-route] alongby returned 0 — falling back to nearby search")
            points: List[Tuple[float, float]] = []
            coords = polyline.split(",")
            for i in range(0, len(coords) - 1, 2):
                try:
                    points.append((float(coords[i]), float(coords[i + 1])))
                except (ValueError, IndexError):
                    continue
            stations = await self.search_along_route_via_nearby(
                polyline_points=points,
                keyword="充电站",
            )

        result = []
        seen_ids = set()  # 去重

        for station in stations:
            station_id = station.get("id")
            if not station_id or station_id in seen_ids:
                continue
            seen_ids.add(station_id)

            result.append({
                "id": station_id,
                "title": station.get("title"),
                "location": station.get("location", {}),
                "address": station.get("address"),
            })

        return result

    async def _search_along_route_segmented(
        self,
        polyline: str,
        keyword: str = "服务区",
    ) -> List[Dict[str, Any]]:
        """分段沿途搜索 POI（避免 URL 过长）。

        将长 polyline 分成多段，分别搜索后合并结果。

        Args:
            polyline: 路线坐标串 "lat,lng,lat,lng,..." (逗号分隔)
            keyword: 搜索关键词

        Returns:
            合并后的 POI 结果列表
        """
        # 解析 polyline 为坐标点列表
        coords = polyline.split(",")
        points = []
        for i in range(0, len(coords) - 1, 2):
            try:
                lat = float(coords[i])
                lng = float(coords[i + 1])
                points.append((lat, lng))
            except (ValueError, IndexError):
                continue

        if not points:
            return []

        # 每段最多 40 个点（约 80 个坐标值），确保 URL 不会过长
        max_points_per_segment = 40
        all_results = []

        for start_idx in range(0, len(points), max_points_per_segment - 5):
            # 每段有 5 个点的重叠，确保不遗漏服务区
            end_idx = min(start_idx + max_points_per_segment, len(points))
            segment_points = points[start_idx:end_idx]

            if len(segment_points) < 2:
                continue

            # 构建该段的 polyline 字符串
            segment_polyline = ",".join(
                f"{lat:.6f},{lng:.6f}" for lat, lng in segment_points
            )

            try:
                results = await self.search_along_route(
                    polyline=segment_polyline,
                    keyword=keyword,
                )
                all_results.extend(results)
            except Exception as e:
                print(f"分段搜索失败 (段 {start_idx}-{end_idx}): {e}")
                continue

        return all_results

    async def get_driving_route_detailed(
        self,
        origin: Tuple[float, float],
        destination: Tuple[float, float],
        waypoints: Optional[List[Tuple[float, float]]] = None,
        get_polyline: bool = True,
    ) -> Dict[str, Any]:
        """Get detailed driving route with full response.

        Args:
            origin: (latitude, longitude) tuple.
            destination: (latitude, longitude) tuple.
            waypoints: Optional list of waypoint (lat, lng) tuples.
            get_polyline: Whether to include polyline data.

        Returns:
            Full route response including:
            - distance (meters)
            - duration (seconds)
            - polyline (for map display)
            - steps (turn-by-turn directions)
        """
        params = {
            "from": f"{origin[0]},{origin[1]}",
            "to": f"{destination[0]},{destination[1]}",
            "get_mp": "1" if get_polyline else "0",  # Get polyline
            "output": "json",
        }

        if waypoints:
            wp_str = ";".join(f"{lat},{lng}" for lat, lng in waypoints)
            params["waypoints"] = wp_str

        data = await self._request("/ws/direction/v1/driving/", params=params)
        result = data.get("result", {})

        # Extract the first (optimal) route
        routes = result.get("routes", [])
        if not routes:
            return {
                "distance": 0,
                "duration": 0,
                "polyline": [],
                "steps": [],
            }

        route = routes[0]

        # Decode delta-encoded polyline
        raw_polyline = route.get("polyline", [])
        decoded_polyline = self._decode_polyline(raw_polyline)

        return {
            "distance": route.get("distance", 0),  # meters
            "duration": route.get("duration", 0),  # minutes (Tencent API returns minutes)
            "polyline": decoded_polyline,
            "steps": route.get("steps", []),
            "waypoints": result.get("waypoints", []),
            "taxi_cost": route.get("taxi_cost", {}),
        }

    def _decode_polyline(self, raw_polyline: List) -> List[Tuple[float, float]]:
        """Decode Tencent Map delta-encoded polyline.

        The format is:
        - First two values are the starting lat/lng
        - Subsequent pairs are delta values (offset * 1e6)

        Args:
            raw_polyline: Flat array of encoded values

        Returns:
            List of (lat, lng) tuples
        """
        if not raw_polyline or len(raw_polyline) < 2:
            return []

        points = []

        # First point is absolute coordinates
        lat = raw_polyline[0]
        lng = raw_polyline[1]
        points.append((lat, lng))

        # Remaining points are delta-encoded
        for i in range(2, len(raw_polyline) - 1, 2):
            lat += raw_polyline[i] / 1e6
            lng += raw_polyline[i + 1] / 1e6
            points.append((lat, lng))

        return points

    async def calculate_route_with_charging(
        self,
        origin: Tuple[float, float],
        destination: Tuple[float, float],
        search_interval_km: float = 100,
    ) -> Dict[str, Any]:
        """Calculate route and find charging stations along it.

        Args:
            origin: (latitude, longitude) start point.
            destination: (latitude, longitude) end point.
            search_interval_km: Interval to search for charging stations (km).

        Returns:
            Dict with route info and charging stations.
        """
        # Get driving route
        route = await self.get_driving_route_detailed(origin, destination)

        distance_km = route["distance"] / 1000
        duration_minutes = route["duration"]

        # Search for charging stations along the route
        charging_stations = []
        if route.get("polyline"):
            # Convert polyline to string format for along-route search
            polyline_str = ";".join(
                f"{p[0]},{p[1]}" for p in route["polyline"][:50]  # Limit points
            )
            try:
                charging_stations = await self.search_along_route(
                    polyline=polyline_str,
                    keyword="充电站",
                    max_distance=3000,
                )
            except Exception:
                # Fallback: search at intervals along the route
                pass

        return {
            "origin": {"lat": origin[0], "lng": origin[1]},
            "destination": {"lat": destination[0], "lng": destination[1]},
            "distance_km": round(distance_km, 1),
            "duration_minutes": round(duration_minutes, 0),
            "polyline": route.get("polyline", []),
            "steps": route.get("steps", []),
            "charging_stations": charging_stations,
        }
