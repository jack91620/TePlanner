"""Tencent Map API client."""

from typing import Any, Dict, List, Optional

import httpx

from app.config import settings


class TencentMapClient:
    """Client for Tencent Map Web Service API."""

    BASE_URL = "https://apis.map.qq.com"

    def __init__(self):
        """Initialize Tencent Map client."""
        self.api_key = settings.TENCENT_MAP_API_KEY
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
    ) -> List[Dict[str, Any]]:
        """Search for POIs near a location.

        Args:
            latitude: Center latitude.
            longitude: Center longitude.
            keyword: Search keyword (e.g., "charging station").
            radius: Search radius in meters.

        Returns:
            List of POI results.
        """
        data = await self._request(
            "/ws/place/v1/search",
            params={
                "keyword": keyword,
                "boundary": f"nearby({latitude},{longitude},{radius})",
            },
        )
        return data.get("data", [])
