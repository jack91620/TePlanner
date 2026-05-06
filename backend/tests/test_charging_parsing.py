"""Tests for charging-station POI → ChargingStation parsing."""

import pytest

from app.api.v1.charging import _parse_station_from_poi


def _poi(title: str, **extra) -> dict:
    poi = {
        "id": "p1",
        "title": title,
        "address": "addr",
        "location": {"lat": 39.9, "lng": 116.4},
    }
    poi.update(extra)
    return poi


@pytest.mark.parametrize("title,expected_operator", [
    ("特斯拉超级充电站(三里屯)",     "特斯拉"),
    ("Tesla Supercharger - SOHO",   "特斯拉"),
    ("国家电网充电站(朝阳门外)",       "国家电网"),
    ("国网快充站(亦庄一区)",          "国家电网"),
    ("特来电(荣乌大港服务区(西)充电站)", "特来电"),
    ("星星充电(望京SOHO)",            "星星充电"),
    ("小桔充电站(青塔蔚园)",          "小桔充电"),
    ("蔚来换电站(海淀北四环)",         "蔚来换电"),
    ("NIO Power Swap Station",        "蔚来换电"),
    ("小鹏自营充电站(亦庄)",          "小鹏充电"),
    ("理想超充站(西海国际中心)",        "理想超充"),
    ("壳牌充电(海淀亿德大厦)",         "壳牌充电"),
    ("能链智电",                       "能链智电"),
    ("快电充电站",                     "能链智电"),
    ("万马爱充充电站",                 "万马爱充"),
    ("依威能源(新起点嘉园)",            "依威能源"),
    ("e充电(北京站)",                  "e充电"),
    ("某乡村小卖部",                   None),  # no known brand
])
def test_operator_detection(title: str, expected_operator):
    station = _parse_station_from_poi(_poi(title))
    assert station.operator == expected_operator, (
        f"expected {expected_operator!r} for {title!r}, got {station.operator!r}"
    )


def test_tel_first_segment_extracted():
    station = _parse_station_from_poi(_poi("X", tel="010-12345;010-67890"))
    assert station.tel == "010-12345"


def test_tel_falls_back_to_none_when_empty():
    station = _parse_station_from_poi(_poi("X", tel=""))
    assert station.tel is None


def test_distance_meters_to_km_via_underscore_distance():
    station = _parse_station_from_poi(
        _poi("X", _distance=840),
        center_lat=39.91,
        center_lng=116.41,
    )
    # 840 m → 0.84 km, rounded to 2 decimals
    assert station.distance_km == 0.84
