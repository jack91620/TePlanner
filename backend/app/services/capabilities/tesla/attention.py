"""'Attention' capabilities — flash lights, honk horn, trigger
HomeLink. Useful in geofence + 'where's my car?' rules.
"""

from __future__ import annotations

from app.services.capabilities import register
from app.services.capabilities.base import (
    Capability,
    CapabilityCallContext,
    CapabilityResult,
    SafetyClass,
)


class FlashLights(Capability):
    @property
    def id(self) -> str: return "tesla.attention.flash_lights"
    @property
    def safety_class(self) -> SafetyClass: return SafetyClass.WRITABLE

    async def invoke(self, ctx: CapabilityCallContext, params: dict) -> CapabilityResult:
        if not ctx.vin: return CapabilityResult(success=False, error="VIN required")
        await ctx.tesla_client.flash_lights(ctx.vin)
        return CapabilityResult(success=True)


class HonkHorn(Capability):
    @property
    def id(self) -> str: return "tesla.attention.honk_horn"
    @property
    def safety_class(self) -> SafetyClass: return SafetyClass.WRITABLE

    async def invoke(self, ctx: CapabilityCallContext, params: dict) -> CapabilityResult:
        if not ctx.vin: return CapabilityResult(success=False, error="VIN required")
        await ctx.tesla_client.honk_horn(ctx.vin)
        return CapabilityResult(success=True)


class TriggerHomeLink(Capability):
    """Activate HomeLink (garage door) at the current GPS position.
    Tesla validates the location on-vehicle to prevent remote attack
    — caller must pass current lat/lng (typically from telemetry)."""

    @property
    def id(self) -> str: return "tesla.attention.trigger_homelink"
    @property
    def safety_class(self) -> SafetyClass: return SafetyClass.SECURITY

    @property
    def params_schema(self) -> dict:
        return {
            "type": "object",
            "properties": {
                "lat": {"type": "number"},
                "lon": {"type": "number"},
            },
            "required": ["lat", "lon"],
        }

    async def invoke(self, ctx: CapabilityCallContext, params: dict) -> CapabilityResult:
        try:
            lat = float(params["lat"])
            lon = float(params["lon"])
        except (KeyError, ValueError, TypeError):
            return CapabilityResult(success=False, error="lat / lon required")
        if not ctx.vin: return CapabilityResult(success=False, error="VIN required")
        await ctx.tesla_client.trigger_homelink(ctx.vin, lat, lon)
        return CapabilityResult(success=True)


class MediaNextTrack(Capability):
    @property
    def id(self) -> str: return "tesla.media.next_track"
    @property
    def safety_class(self) -> SafetyClass: return SafetyClass.WRITABLE

    async def invoke(self, ctx: CapabilityCallContext, params: dict) -> CapabilityResult:
        if not ctx.vin: return CapabilityResult(success=False, error="VIN required")
        await ctx.tesla_client.media_next_track(ctx.vin)
        return CapabilityResult(success=True)


class MediaPrevTrack(Capability):
    @property
    def id(self) -> str: return "tesla.media.prev_track"
    @property
    def safety_class(self) -> SafetyClass: return SafetyClass.WRITABLE

    async def invoke(self, ctx: CapabilityCallContext, params: dict) -> CapabilityResult:
        if not ctx.vin: return CapabilityResult(success=False, error="VIN required")
        await ctx.tesla_client.media_prev_track(ctx.vin)
        return CapabilityResult(success=True)


class NavigateAddress(Capability):
    """Send a textual address to Tesla nav (street + city + country
    string parsed by Tesla maps). Differs from
    tesla.navigation.send (which takes lat/lng GPS coords) — handy
    when the user knows the address but not the coords.
    """

    @property
    def id(self) -> str: return "tesla.navigation.send_address"
    @property
    def safety_class(self) -> SafetyClass: return SafetyClass.WRITABLE

    @property
    def params_schema(self) -> dict:
        return {
            "type": "object",
            "properties": {
                "address": {"type": "string"},
                "locale": {"type": "string", "default": "zh-CN"},
            },
            "required": ["address"],
        }

    async def invoke(self, ctx: CapabilityCallContext, params: dict) -> CapabilityResult:
        addr = params.get("address")
        if not isinstance(addr, str) or not addr:
            return CapabilityResult(success=False, error="address required")
        locale = params.get("locale", "zh-CN")
        await ctx.tesla_client.navigation_request(
            ctx.vehicle_id, address=addr, locale=locale,
        )
        return CapabilityResult(success=True, data={"address": addr})


register(FlashLights())
register(HonkHorn())
register(TriggerHomeLink())
register(MediaNextTrack())
register(MediaPrevTrack())
register(NavigateAddress())
