"""Charging station endpoints."""

from typing import List, Optional

from fastapi import APIRouter, Query, HTTPException
from pydantic import BaseModel

from app.integrations.tencent_map.client import TencentMapClient

router = APIRouter()


class ChargingStation(BaseModel):
    """Charging station model."""

    id: str
    name: str
    address: str
    latitude: float
    longitude: float
    distance_km: Optional[float] = None
    operator: Optional[str] = None
    tel: Optional[str] = None
    power_kw: Optional[int] = None
    available_ports: Optional[int] = None
    total_ports: Optional[int] = None
    price_per_kwh: Optional[float] = None
    open_hours: Optional[str] = None
    category: Optional[str] = None
    type: Optional[str] = None


class StationSearchResponse(BaseModel):
    """Station search response."""

    count: int
    stations: List[ChargingStation]


def _parse_station_from_poi(
    poi: dict,
    center_lat: float = None,
    center_lng: float = None,
    station_type: str = None,
) -> ChargingStation:
    """Parse a charging station from Tencent Map POI data.

    Args:
        poi: POI data from Tencent Map API.
        center_lat: Center latitude for distance calculation.
        center_lng: Center longitude for distance calculation.
        station_type: Station type to set.

    Returns:
        ChargingStation object.
    """
    location = poi.get("location", {})
    lat = location.get("lat", 0)
    lng = location.get("lng", 0)

    # Calculate distance if center provided
    distance_km = None
    if center_lat is not None and center_lng is not None:
        # Tencent's `_distance` field is in meters; convert to km.
        # If Tencent didn't attach it, fall back to a haversine
        # calculation (already in km).
        distance_m = poi.get("_distance")
        if distance_m is not None:
            distance_km = distance_m / 1000.0
        else:
            import math
            R = 6371
            dlat = math.radians(lat - center_lat)
            dlng = math.radians(lng - center_lng)
            a = math.sin(dlat/2)**2 + math.cos(math.radians(center_lat)) * math.cos(math.radians(lat)) * math.sin(dlng/2)**2
            distance_km = R * 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))

    # Try to extract operator from title or category. Order matters
    # for substring matches that share characters (e.g. "蔚来 NIO" 蔚
    # before 蔚来汽车).
    title = poi.get("title", "")
    title_lower = title.lower()
    operator = None
    operator_rules = [
        ("特斯拉", ["特斯拉", "tesla"]),
        ("国家电网", ["国家电网", "国网"]),
        ("特来电", ["特来电"]),
        ("星星充电", ["星星充电"]),
        ("小桔充电", ["小桔充电", "小桔"]),
        ("蔚来换电", ["蔚来", "nio"]),
        ("小鹏充电", ["小鹏"]),
        ("理想超充", ["理想超充", "理想"]),
        ("壳牌充电", ["壳牌"]),
        ("能链智电", ["能链", "快电"]),
        ("万马爱充", ["万马"]),
        ("依威能源", ["依威能源", "依威"]),
        ("e充电", ["e充电"]),
    ]
    for name, needles in operator_rules:
        if any(n in title for n in needles) or any(n.lower() in title_lower for n in needles):
            operator = name
            break

    # Tencent sometimes returns a phone in `tel` (semicolon-delimited
    # for stations with multiple lines); take the first.
    tel = poi.get("tel") or None
    if isinstance(tel, str):
        tel = tel.split(";", 1)[0].strip() or None

    return ChargingStation(
        id=poi.get("id", ""),
        name=title,
        address=poi.get("address", ""),
        latitude=lat,
        longitude=lng,
        distance_km=round(distance_km, 2) if distance_km else None,
        operator=operator,
        tel=tel,
        category=poi.get("category", ""),
        type=station_type,
    )


@router.get("/nearby", response_model=StationSearchResponse)
async def search_nearby_stations(
    latitude: float = Query(..., description="中心点纬度"),
    longitude: float = Query(..., description="中心点经度"),
    type: Optional[str] = Query("all", description="类型: supercharger/destination/service/all"),
    radius: float = Query(50, description="搜索半径(公里)"),
):
    """搜索附近充电站 (前端兼容接口).

    Args:
        latitude: 中心点纬度
        longitude: 中心点经度
        type: 充电站类型
        radius: 搜索半径，默认50公里
    """
    from app.config import settings

    # Check if API key is configured
    if not settings.TENCENT_MAP_KEY and not settings.TENCENT_MAP_API_KEY:
        # Return empty result if no API key
        return StationSearchResponse(count=0, stations=[])

    try:
        async with TencentMapClient() as client:
            # Different search based on type
            if type == "supercharger":
                pois = await client.search_nearby(
                    latitude=latitude,
                    longitude=longitude,
                    keyword="特斯拉超级充电",
                    radius=int(radius * 1000),
                )
            elif type == "destination":
                pois = await client.search_nearby(
                    latitude=latitude,
                    longitude=longitude,
                    keyword="特斯拉目的地充电",
                    radius=int(radius * 1000),
                )
            elif type == "service":
                pois = await client.search_service_areas(
                    latitude=latitude,
                    longitude=longitude,
                    radius=int(radius * 1000),
                )
            else:
                pois = await client.search_charging_stations(
                    latitude=latitude,
                    longitude=longitude,
                    radius=int(radius * 1000),
                )

            station_type = type if type != "all" else "charger"
            stations = []
            for poi in pois:
                station = _parse_station_from_poi(poi, latitude, longitude, station_type)
                stations.append(station)

            # Sort by distance
            stations.sort(key=lambda s: s.distance_km or 999)

            return StationSearchResponse(
                count=len(stations),
                stations=stations,
            )

    except Exception as e:
        # Log error but return empty result instead of 500
        import logging
        logging.error(f"搜索充电站失败: {str(e)}")
        return StationSearchResponse(count=0, stations=[])


@router.get("/stations", response_model=StationSearchResponse)
async def search_stations(
    lat: float = Query(..., description="中心点纬度"),
    lng: float = Query(..., description="中心点经度"),
    radius_km: float = Query(10, description="搜索半径(公里)"),
    min_power_kw: Optional[int] = Query(None, description="最小充电功率(kW)"),
    operator: Optional[str] = Query(None, description="运营商筛选"),
):
    """搜索附近充电站.

    Args:
        lat: 中心点纬度
        lng: 中心点经度
        radius_km: 搜索半径，默认10公里
        min_power_kw: 最小充电功率筛选
        operator: 运营商筛选
    """
    try:
        async with TencentMapClient() as client:
            pois = await client.search_charging_stations(
                latitude=lat,
                longitude=lng,
                radius=int(radius_km * 1000),
            )

            stations = []
            for poi in pois:
                station = _parse_station_from_poi(poi, lat, lng)

                # Apply filters
                if operator and station.operator != operator:
                    continue
                if min_power_kw and station.power_kw and station.power_kw < min_power_kw:
                    continue

                stations.append(station)

            # Sort by distance
            stations.sort(key=lambda s: s.distance_km or 999)

            return StationSearchResponse(
                count=len(stations),
                stations=stations,
            )

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"搜索充电站失败: {str(e)}")


@router.get("/stations/{station_id}", response_model=ChargingStation)
async def get_station(station_id: str):
    """获取充电站详情.

    Args:
        station_id: 充电站ID
    """
    # TODO: Implement station detail lookup
    # For now, return a placeholder
    raise HTTPException(status_code=404, detail="充电站不存在")


@router.get("/service-areas", response_model=StationSearchResponse)
async def search_service_areas(
    lat: float = Query(..., description="中心点纬度"),
    lng: float = Query(..., description="中心点经度"),
    radius_km: float = Query(50, description="搜索半径(公里)"),
):
    """搜索高速服务区.

    Args:
        lat: 中心点纬度
        lng: 中心点经度
        radius_km: 搜索半径，默认50公里
    """
    try:
        async with TencentMapClient() as client:
            pois = await client.search_service_areas(
                latitude=lat,
                longitude=lng,
                radius=int(radius_km * 1000),
            )

            stations = []
            for poi in pois:
                station = _parse_station_from_poi(poi, lat, lng)
                stations.append(station)

            # Sort by distance
            stations.sort(key=lambda s: s.distance_km or 999)

            return StationSearchResponse(
                count=len(stations),
                stations=stations,
            )

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"搜索服务区失败: {str(e)}")


@router.get("/along-route", response_model=StationSearchResponse)
async def search_along_route(
    origin_lat: float = Query(..., description="起点纬度"),
    origin_lng: float = Query(..., description="起点经度"),
    dest_lat: float = Query(..., description="终点纬度"),
    dest_lng: float = Query(..., description="终点经度"),
    max_distance_m: int = Query(3000, description="距离路线最大距离(米)"),
):
    """沿路线搜索充电站.

    首先规划路线，然后沿路线搜索充电站。

    Args:
        origin_lat: 起点纬度
        origin_lng: 起点经度
        dest_lat: 终点纬度
        dest_lng: 终点经度
        max_distance_m: 距离路线最大距离，默认3000米
    """
    try:
        async with TencentMapClient() as client:
            # First get the route
            route = await client.get_driving_route_detailed(
                origin=(origin_lat, origin_lng),
                destination=(dest_lat, dest_lng),
            )

            polyline = route.get("polyline", [])
            if not polyline:
                return StationSearchResponse(count=0, stations=[])

            # Convert polyline to string format
            # Sample points to avoid too long polyline
            step = max(1, len(polyline) // 30)
            sampled_points = polyline[::step][:30]
            polyline_str = ";".join(f"{p[0]},{p[1]}" for p in sampled_points)

            # Search along route
            pois = await client.search_along_route(
                polyline=polyline_str,
                keyword="充电站",
                max_distance=max_distance_m,
            )

            stations = []
            for poi in pois:
                station = _parse_station_from_poi(poi, origin_lat, origin_lng)
                stations.append(station)

            return StationSearchResponse(
                count=len(stations),
                stations=stations,
            )

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"沿途搜索充电站失败: {str(e)}")


@router.get("/superchargers", response_model=StationSearchResponse)
async def search_superchargers(
    lat: float = Query(..., description="中心点纬度"),
    lng: float = Query(..., description="中心点经度"),
    radius_km: float = Query(50, description="搜索半径(公里)"),
):
    """搜索特斯拉超级充电站.

    Args:
        lat: 中心点纬度
        lng: 中心点经度
        radius_km: 搜索半径，默认50公里
    """
    try:
        async with TencentMapClient() as client:
            pois = await client.search_nearby(
                latitude=lat,
                longitude=lng,
                keyword="特斯拉超级充电",
                radius=int(radius_km * 1000),
            )

            stations = []
            for poi in pois:
                station = _parse_station_from_poi(poi, lat, lng)
                station.operator = "特斯拉超级充电"
                stations.append(station)

            # Sort by distance
            stations.sort(key=lambda s: s.distance_km or 999)

            return StationSearchResponse(
                count=len(stations),
                stations=stations,
            )

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"搜索超级充电站失败: {str(e)}")
