"""Charging command extensions — start/stop, port door,
amperage. The set_limit capability lives in charging.py.
"""

from __future__ import annotations

from app.services.capabilities import register
from app.services.capabilities.base import (
    Capability,
    CapabilityCallContext,
    CapabilityResult,
    SafetyClass,
)


class ChargeStart(Capability):
    @property
    def id(self) -> str: return "tesla.charging.start"
    @property
    def safety_class(self) -> SafetyClass: return SafetyClass.WRITABLE

    async def invoke(self, ctx: CapabilityCallContext, params: dict) -> CapabilityResult:
        if not ctx.vin: return CapabilityResult(success=False, error="VIN required")
        await ctx.tesla_client.charge_start(ctx.vin)
        return CapabilityResult(success=True)

    def expected_state(self, params: dict) -> dict:
        return {"vehicle.charging.state": "Charging"}


class ChargeStop(Capability):
    @property
    def id(self) -> str: return "tesla.charging.stop"
    @property
    def safety_class(self) -> SafetyClass: return SafetyClass.WRITABLE

    async def invoke(self, ctx: CapabilityCallContext, params: dict) -> CapabilityResult:
        if not ctx.vin: return CapabilityResult(success=False, error="VIN required")
        await ctx.tesla_client.charge_stop(ctx.vin)
        return CapabilityResult(success=True)

    def expected_state(self, params: dict) -> dict:
        return {"vehicle.charging.state": "Stopped"}


class ChargePortOpen(Capability):
    @property
    def id(self) -> str: return "tesla.charging.port_open"
    @property
    def safety_class(self) -> SafetyClass: return SafetyClass.MOVEMENT

    async def invoke(self, ctx: CapabilityCallContext, params: dict) -> CapabilityResult:
        if not ctx.vin: return CapabilityResult(success=False, error="VIN required")
        await ctx.tesla_client.charge_port_door_open(ctx.vin)
        return CapabilityResult(success=True)


class ChargePortClose(Capability):
    @property
    def id(self) -> str: return "tesla.charging.port_close"
    @property
    def safety_class(self) -> SafetyClass: return SafetyClass.MOVEMENT

    async def invoke(self, ctx: CapabilityCallContext, params: dict) -> CapabilityResult:
        if not ctx.vin: return CapabilityResult(success=False, error="VIN required")
        await ctx.tesla_client.charge_port_door_close(ctx.vin)
        return CapabilityResult(success=True)


class SetChargingAmps(Capability):
    """Set the AC charging amperage (e.g. throttle home charger to 16 A)."""

    @property
    def id(self) -> str: return "tesla.charging.set_amps"
    @property
    def safety_class(self) -> SafetyClass: return SafetyClass.WRITABLE

    @property
    def params_schema(self) -> dict:
        return {
            "type": "object",
            "properties": {
                "amps": {
                    "type": "integer",
                    "minimum": 5,
                    "maximum": 48,
                    "description": "充电电流 5–48 A",
                },
            },
            "required": ["amps"],
        }

    async def invoke(self, ctx: CapabilityCallContext, params: dict) -> CapabilityResult:
        amps = params.get("amps")
        if not isinstance(amps, int) or not (5 <= amps <= 48):
            return CapabilityResult(success=False, error="amps must be 5..48")
        if not ctx.vin: return CapabilityResult(success=False, error="VIN required")
        await ctx.tesla_client.set_charging_amps(ctx.vin, amps)
        return CapabilityResult(success=True, data={"amps": amps})


register(ChargeStart())
register(ChargeStop())
register(ChargePortOpen())
register(ChargePortClose())
register(SetChargingAmps())
