"""AMap (高德) Web Service REST client.

Drop-in replacement for `TencentMapClient` — same methods, same
return shapes (mostly). Implementation calls AMap's REST endpoints
and translates field names back to Tencent's shape so callers can
swap imports without other changes.

Conventions:
- AMap REST uses `location=<lng>,<lat>` (longitude first). We accept
  the same `(latitude, longitude)` arguments as the old client and
  format internally.
- AMap returns distance in meters, duration in seconds. Tencent
  returns duration in minutes for the direction API. We convert
  AMap's seconds → minutes in `get_driving_route_detailed` to match.
- AMap polyline strings are `lng,lat;lng,lat;…` per step. We
  decode + flip to `(lat, lng)` tuples so callers see the same
  shape as Tencent's decoded polyline.
"""

from typing import Any, Dict, List, Optional, Tuple
from math import asin, cos, radians, sin, sqrt

import httpx

from app.config import settings


class AmapWebClient:
    """AMap REST client that mimics the legacy Tencent client surface."""

    BASE_URL = "https://restapi.amap.com"

    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or settings.AMAP_WEB_API_KEY
        self._client: Optional[httpx.AsyncClient] = None

    async def _get_client(self) -> httpx.AsyncClient:
        if self._client is None:
            self._client = httpx.AsyncClient(base_url=self.BASE_URL, timeout=30.0)
        return self._client

    async def close(self):
        if self._client:
            await self._client.aclose()
            self._client = None

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        await self.close()

    async def _request(self, path: str, params: Dict[str, Any]) -> Dict[str, Any]:
        client = await self._get_client()
        params = {**params, "key": self.api_key, "output": "json"}
        response = await client.get(path, params=params)
        response.raise_for_status()
        data = response.json()
        # AMap returns status="1" on success, "0" on error.
        # Some endpoints return status as int.
        status = data.get("status")
        if status not in ("1", 1):
            info = data.get("info", "unknown")
            infocode = data.get("infocode", "")
            raise Exception(f"AMap API error: {info} (infocode={infocode})")
        return data

    # MARK: - geocoding

    async def geocode(self, address: str) -> Dict[str, Any]:
        """address → coordinates. Returns Tencent-shape dict."""
        data = await self._request("/v3/geocode/geo", {"address": address})
        geocodes = data.get("geocodes", [])
        if not geocodes:
            return {}
        first = geocodes[0]
        lng_str, lat_str = (first.get("location") or "0,0").split(",")
        return {
            "title": first.get("formatted_address", address),
            "location": {"lat": float(lat_str), "lng": float(lng_str)},
            "address": first.get("formatted_address", address),
            "ad_info": {
                "province": first.get("province", ""),
                "city": first.get("city", ""),
                "district": first.get("district", ""),
                "adcode": first.get("adcode", ""),
            },
        }

    async def reverse_geocode(
        self,
        latitude: float,
        longitude: float,
    ) -> Dict[str, Any]:
        """coordinates → address. Returns Tencent-shape dict with
        `address` + `formatted_addresses.recommend` etc."""
        data = await self._request(
            "/v3/geocode/regeo",
            {"location": f"{longitude},{latitude}"},
        )
        regeo = data.get("regeocode", {})
        addr = regeo.get("formatted_address", "")
        comp = regeo.get("addressComponent", {})
        return {
            "address": addr,
            "formatted_addresses": {"recommend": addr, "rough": addr},
            "ad_info": {
                "province": comp.get("province", ""),
                "city": comp.get("city", ""),
                "district": comp.get("district", ""),
                "adcode": comp.get("adcode", ""),
            },
            "address_component": {
                "nation": "中国",
                "province": comp.get("province", ""),
                "city": comp.get("city", ""),
                "district": comp.get("district", ""),
                "street": comp.get("streetNumber", {}).get("street", "")
                if isinstance(comp.get("streetNumber"), dict)
                else "",
            },
        }

    # MARK: - POI search

    @staticmethod
    def _amap_poi_to_tencent(poi: Dict[str, Any]) -> Dict[str, Any]:
        """Translate one AMap POI to Tencent-shape so charging.py /
        route_planner.py can read the same fields without changes.

        AMap fields → Tencent fields:
          name        → title
          location    → {lat, lng}     (AMap has "lng,lat" string)
          type        → category       (AMap returns ";"-separated tree)
          distance    → _distance      (meters; numeric or empty str)
          tel         → tel
          address     → address
          id          → id
        """
        loc_str = poi.get("location") or "0,0"
        try:
            lng_s, lat_s = loc_str.split(",")
            lat, lng = float(lat_s), float(lng_s)
        except Exception:
            lat, lng = 0.0, 0.0

        # AMap distance is sometimes "" or "[]" (empty). Coerce to None.
        raw_dist = poi.get("distance")
        distance: Optional[float]
        try:
            distance = float(raw_dist) if raw_dist not in (None, "", []) else None
        except (TypeError, ValueError):
            distance = None

        type_str = poi.get("type") or ""
        category = type_str.split(";")[-1] if type_str else ""

        # AMap may give tel as ";"-separated list of numbers.
        tel_raw = poi.get("tel") or ""
        if isinstance(tel_raw, list):
            tel_raw = ";".join(str(x) for x in tel_raw)
        tel_first = (tel_raw.split(";")[0] if tel_raw else "").strip() or None

        return {
            "id": poi.get("id", ""),
            "title": poi.get("name", ""),
            "address": poi.get("address", "") if isinstance(poi.get("address"), str) else "",
            "location": {"lat": lat, "lng": lng},
            "_distance": distance,
            "tel": tel_first,
            "category": category,
            "ad_info": {
                "province": poi.get("pname", ""),
                "city": poi.get("cityname", ""),
                "district": poi.get("adname", ""),
                "adcode": poi.get("adcode", ""),
            },
        }

    async def search_nearby(
        self,
        latitude: float,
        longitude: float,
        keyword: str,
        radius: int = 5000,
        page_size: int = 20,
        page_index: int = 1,
    ) -> List[Dict[str, Any]]:
        """周边搜索 — POI around (lat, lng) within `radius` meters."""
        # AMap: GET /v3/place/around
        data = await self._request(
            "/v3/place/around",
            {
                "keywords": keyword,
                "location": f"{longitude},{latitude}",
                "radius": min(radius, 50000),  # AMap caps at 50km
                "offset": min(page_size, 25),  # AMap uses "offset" for page size
                "page": page_index,
                "extensions": "all",
            },
        )
        return [self._amap_poi_to_tencent(p) for p in data.get("pois", [])]

    async def search_charging_stations(
        self, latitude: float, longitude: float, radius: int = 10000,
    ) -> List[Dict[str, Any]]:
        return await self.search_nearby(latitude, longitude, "充电站", radius=radius)

    # MARK: - driving routes

    async def get_driving_route_detailed(
        self,
        origin: Tuple[float, float],
        destination: Tuple[float, float],
        waypoints: Optional[List[Tuple[float, float]]] = None,
        get_polyline: bool = True,
    ) -> Dict[str, Any]:
        """AMap returns paths with per-step polylines; we concatenate
        and decode to (lat,lng) tuples to match the Tencent shape."""
        params = {
            "origin": f"{origin[1]},{origin[0]}",       # AMap: lng,lat
            "destination": f"{destination[1]},{destination[0]}",
            "extensions": "all" if get_polyline else "base",
        }
        if waypoints:
            wp = ";".join(f"{lng},{lat}" for lat, lng in waypoints)
            params["waypoints"] = wp

        data = await self._request("/v3/direction/driving", params)
        route = data.get("route", {}) or {}
        paths = route.get("paths", [])
        if not paths:
            return {"distance": 0, "duration": 0, "polyline": [], "steps": []}

        path = paths[0]
        # Concatenate polylines from each step.
        decoded: List[Tuple[float, float]] = []
        for step in path.get("steps", []):
            poly_str = step.get("polyline", "")
            for p in poly_str.split(";"):
                if not p:
                    continue
                try:
                    lng_s, lat_s = p.split(",")
                    decoded.append((float(lat_s), float(lng_s)))
                except Exception:
                    continue

        try:
            distance_m = float(path.get("distance", 0))
        except (TypeError, ValueError):
            distance_m = 0.0
        try:
            duration_s = float(path.get("duration", 0))
        except (TypeError, ValueError):
            duration_s = 0.0
        # Tencent returns duration in minutes for direction; AMap in
        # seconds. Convert so downstream math (route_planner) stays put.
        duration_min = duration_s / 60.0

        return {
            "distance": int(distance_m),
            "duration": duration_min,
            "polyline": decoded,
            "steps": path.get("steps", []),
            "waypoints": [],
            "taxi_cost": {},
        }

    async def driving_route(
        self,
        origin: tuple,
        destination: tuple,
        waypoints: Optional[List[tuple]] = None,
    ) -> Dict[str, Any]:
        return await self.get_driving_route_detailed(
            origin=origin, destination=destination, waypoints=waypoints, get_polyline=True,
        )
