"""Regression test for the route duration unit bug.

The Tencent Maps direction API returns ``duration`` in **minutes**, but
``route_planner.plan_route`` (and the helper inside the map client)
historically divided it by 60 a second time, producing absurd values
(e.g. 12 minutes for a 1159 km Beijing→Suzhou route).
"""

from unittest.mock import AsyncMock, patch

import pytest

from app.services.route_planner import RoutePlanner


@pytest.mark.anyio
async def test_driving_minutes_uses_api_value_directly(monkeypatch):
    fake_route = {
        "distance": 50_000,  # 50 km in meters
        "duration": 45,      # 45 minutes — Tencent returns minutes already
        "polyline": [],
        "steps": [],
    }

    class FakeMapClient:
        async def get_driving_route_detailed(self, origin, destination):
            return fake_route

        async def reverse_geocode(self, lat, lng):
            return {"address": "stub"}

        async def search_service_area_charging_along_route(self, polyline):
            return []

        async def close(self):
            pass

    planner = RoutePlanner()
    planner.map_client = FakeMapClient()

    result = await planner.plan_route(
        origin=(40.0, 116.4),
        destination=(40.5, 116.5),
        initial_soc=80,
    )

    # 50 km on a Model Y at 80% SOC easily makes it without charging,
    # so we end on the no-charging branch and `total_duration_minutes`
    # equals `driving_duration_minutes`.
    assert result.driving_duration_minutes == 45, (
        f"expected 45 min (raw API value), got {result.driving_duration_minutes}"
    )
    assert result.total_duration_minutes == 45
    assert result.charging_duration_minutes == 0
