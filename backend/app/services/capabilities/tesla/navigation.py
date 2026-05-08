"""Tesla navigation capabilities."""

from __future__ import annotations

from app.services.capabilities import register
from app.services.capabilities.base import (
    Capability,
    CapabilityCallContext,
    CapabilityResult,
    SafetyClass,
)


class SendNavigation(Capability):
    """Send GPS coordinates to vehicle nav. Uses numeric vehicle_id
    (not VIN) — navigation_gps_request is one of the few endpoints
    that doesn't go through the VCP signing path."""

    @property
    def id(self) -> str:
        return "tesla.navigation.send"

    @property
    def safety_class(self) -> SafetyClass:
        return SafetyClass.WRITABLE

    @property
    def params_schema(self) -> dict:
        return {
            "type": "object",
            "properties": {
                "latitude": {"type": "number"},
                "longitude": {"type": "number"},
                "name": {"type": "string"},
                "order": {"type": "integer", "minimum": 1, "default": 1},
            },
            "required": ["latitude", "longitude"],
        }

    async def invoke(
        self, ctx: CapabilityCallContext, params: dict
    ) -> CapabilityResult:
        try:
            lat = float(params["latitude"])
            lon = float(params["longitude"])
        except (KeyError, ValueError, TypeError):
            return CapabilityResult(
                success=False, error="latitude / longitude required"
            )
        order = int(params.get("order", 1))
        await ctx.tesla_client.navigation_gps_request(
            vehicle_tag=ctx.vehicle_id,
            lat=lat,
            lon=lon,
            order=order,
        )
        return CapabilityResult(
            success=True,
            data={"destination": {"latitude": lat, "longitude": lon}},
        )


register(SendNavigation())
