"""Closures — door lock/unlock, trunk, window, sunroof.

Most of these are SECURITY or movement-class so the iOS rule
builder gates them behind the "我已知道：此 capability 是 X 级别"
toggle before save.
"""

from __future__ import annotations

from app.services.capabilities import register
from app.services.capabilities.base import (
    Capability,
    CapabilityCallContext,
    CapabilityResult,
    SafetyClass,
)


class DoorLock(Capability):
    @property
    def id(self) -> str: return "tesla.security.door_lock"
    @property
    def safety_class(self) -> SafetyClass: return SafetyClass.SECURITY

    async def invoke(self, ctx: CapabilityCallContext, params: dict) -> CapabilityResult:
        if not ctx.vin: return CapabilityResult(success=False, error="VIN required")
        await ctx.tesla_client.door_lock(ctx.vin)
        return CapabilityResult(success=True)

    def expected_state(self, params: dict) -> dict:
        return {"vehicle.locked": True}


class DoorUnlock(Capability):
    @property
    def id(self) -> str: return "tesla.security.door_unlock"
    @property
    def safety_class(self) -> SafetyClass: return SafetyClass.SECURITY

    async def invoke(self, ctx: CapabilityCallContext, params: dict) -> CapabilityResult:
        if not ctx.vin: return CapabilityResult(success=False, error="VIN required")
        await ctx.tesla_client.door_unlock(ctx.vin)
        return CapabilityResult(success=True)

    def expected_state(self, params: dict) -> dict:
        return {"vehicle.locked": False}


class ActuateFrontTrunk(Capability):
    """Open the front trunk (frunk). Tesla doesn't expose a 'close'
    on the front trunk — closing is mechanical."""

    @property
    def id(self) -> str: return "tesla.security.actuate_frunk"
    @property
    def safety_class(self) -> SafetyClass: return SafetyClass.MOVEMENT

    async def invoke(self, ctx: CapabilityCallContext, params: dict) -> CapabilityResult:
        if not ctx.vin: return CapabilityResult(success=False, error="VIN required")
        await ctx.tesla_client.actuate_trunk(ctx.vin, "front")
        return CapabilityResult(success=True)


class ActuateRearTrunk(Capability):
    """Power-actuate the rear trunk. On Model 3/Y this opens; on
    Model X falcon-wing-door spec lets it close too."""

    @property
    def id(self) -> str: return "tesla.security.actuate_trunk"
    @property
    def safety_class(self) -> SafetyClass: return SafetyClass.MOVEMENT

    async def invoke(self, ctx: CapabilityCallContext, params: dict) -> CapabilityResult:
        if not ctx.vin: return CapabilityResult(success=False, error="VIN required")
        await ctx.tesla_client.actuate_trunk(ctx.vin, "rear")
        return CapabilityResult(success=True)


class WindowVent(Capability):
    """Vent all 4 windows (small crack for cooling). Tesla's
    `window_control` requires lat/lng = 0,0 for vent with no GPS
    constraint. Vent ≠ full-open; same command can also close."""

    @property
    def id(self) -> str: return "tesla.closures.window_vent"
    @property
    def safety_class(self) -> SafetyClass: return SafetyClass.MOVEMENT

    async def invoke(self, ctx: CapabilityCallContext, params: dict) -> CapabilityResult:
        if not ctx.vin: return CapabilityResult(success=False, error="VIN required")
        await ctx.tesla_client.window_control(ctx.vin, command="vent", lat=0.0, lon=0.0)
        return CapabilityResult(success=True)

    def expected_state(self, params: dict) -> dict:
        return {"vehicle.window_open": True}


class WindowClose(Capability):
    @property
    def id(self) -> str: return "tesla.closures.window_close"
    @property
    def safety_class(self) -> SafetyClass: return SafetyClass.MOVEMENT

    async def invoke(self, ctx: CapabilityCallContext, params: dict) -> CapabilityResult:
        if not ctx.vin: return CapabilityResult(success=False, error="VIN required")
        await ctx.tesla_client.window_control(ctx.vin, command="close", lat=0.0, lon=0.0)
        return CapabilityResult(success=True)

    def expected_state(self, params: dict) -> dict:
        return {"vehicle.window_open": False}


class SunRoofVent(Capability):
    """Model S/X/Y panoramic roof. Mostly inert on Model 3."""

    @property
    def id(self) -> str: return "tesla.closures.sun_roof_vent"
    @property
    def safety_class(self) -> SafetyClass: return SafetyClass.MOVEMENT

    async def invoke(self, ctx: CapabilityCallContext, params: dict) -> CapabilityResult:
        if not ctx.vin: return CapabilityResult(success=False, error="VIN required")
        await ctx.tesla_client.sun_roof_control(ctx.vin, "vent")
        return CapabilityResult(success=True)


class SunRoofClose(Capability):
    @property
    def id(self) -> str: return "tesla.closures.sun_roof_close"
    @property
    def safety_class(self) -> SafetyClass: return SafetyClass.MOVEMENT

    async def invoke(self, ctx: CapabilityCallContext, params: dict) -> CapabilityResult:
        if not ctx.vin: return CapabilityResult(success=False, error="VIN required")
        await ctx.tesla_client.sun_roof_control(ctx.vin, "close")
        return CapabilityResult(success=True)


register(DoorLock())
register(DoorUnlock())
register(ActuateFrontTrunk())
register(ActuateRearTrunk())
register(WindowVent())
register(WindowClose())
register(SunRoofVent())
register(SunRoofClose())
