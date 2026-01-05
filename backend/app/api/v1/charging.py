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
    power_kw: Optional[int] = None
    available_ports: Optional[int] = None
    total_ports: Optional[int] = None
    price_per_kwh: Optional[float] = None
    open_hours: Optional[str] = None
    category: Optional[str] = None


class StationSearchResponse(BaseModel):
    """Station search response."""

    count: int
    stations: List[ChargingStation]


def _parse_station_from_poi(poi: dict, center_lat: float = None, center_lng: float = None) -> ChargingStation:
    """Parse a charging station from Tencent Map POI data.

    Args:
        poi: POI data from Tencent Map API.
        center_lat: Center latitude for distance calculation.
        center_lng: Center longitude for distance calculation.

    Returns:
        ChargingStation object.
    """
    location = poi.get("location", {})
    lat = location.get("lat", 0)
    lng = location.get("lng", 0)

    # Calculate distance if center provided
    distance_km = None
    if center_lat is not None and center_lng is not None:
        distance_km = poi.get("_distance")
        if distance_km is None:
            # Calculate using simple formula
            import math
            R = 6371
            dlat = math.radians(lat - center_lat)
            dlng = math.radians(lng - center_lng)
            a = math.sin(dlat/2)**2 + math.cos(math.radians(center_lat)) * math.cos(math.radians(lat)) * math.sin(dlng/2)**2
            distance_km = R * 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))

    # Try to extract operator from title or category
    title = poi.get("title", "")
    operator = None
    if "国家电网" in title or "国网" in title:
        operator = "国家电网"
    elif "特来电" in title:
        operator = "特来电"
    elif "星星充电" in title:
        operator = "星星充电"
    elif "特斯拉" in title or "Tesla" in title.lower():
        operator = "特斯拉超级充电"
    elif "小鹏" in title:
        operator = "小鹏充电"
    elif "蔚来" in title or "NIO" in title.upper():
        operator = "蔚来换电站"

    return ChargingStation(
        id=poi.get("id", ""),
        name=title,
        address=poi.get("address", ""),
        latitude=lat,
        longitude=lng,
        distance_km=round(distance_km, 2) if distance_km else None,
        operator=operator,
        category=poi.get("category", ""),
    )


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
