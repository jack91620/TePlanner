"""Climate command extensions — stop, set_temps, preconditioning,
cabin overheat protection. set_keeper_mode + preheat live in
climate.py.
"""

from __future__ import annotations

from app.services.capabilities import register
from app.services.capabilities.base import (
    Capability,
    CapabilityCallContext,
    CapabilityResult,
    SafetyClass,
)


class ClimateStop(Capability):
    """`auto_conditioning_stop` — turn off the HVAC system entirely.
    Counterpart to tesla.climate.preheat (auto_conditioning_start)."""

    @property
    def id(self) -> str: return "tesla.climate.stop"
    @property
    def safety_class(self) -> SafetyClass: return SafetyClass.WRITABLE

    async def invoke(self, ctx: CapabilityCallContext, params: dict) -> CapabilityResult:
        if not ctx.vin: return CapabilityResult(success=False, error="VIN required")
        await ctx.tesla_client.auto_conditioning_stop(ctx.vin)
        return CapabilityResult(success=True)


class SetTemps(Capability):
    """Set driver + passenger target temperatures (Celsius). Range
    Tesla-supported is roughly 15–28 °C with 0.5 step."""

    @property
    def id(self) -> str: return "tesla.climate.set_temps"
    @property
    def safety_class(self) -> SafetyClass: return SafetyClass.WRITABLE

    @property
    def params_schema(self) -> dict:
        return {
            "type": "object",
            "properties": {
                "driver_temp": {"type": "number", "minimum": 15, "maximum": 28},
                "passenger_temp": {"type": "number", "minimum": 15, "maximum": 28},
            },
            "required": ["driver_temp", "passenger_temp"],
        }

    async def invoke(self, ctx: CapabilityCallContext, params: dict) -> CapabilityResult:
        try:
            d = float(params["driver_temp"])
            p = float(params["passenger_temp"])
        except (KeyError, ValueError, TypeError):
            return CapabilityResult(success=False, error="driver/passenger temp required")
        if not (15 <= d <= 28) or not (15 <= p <= 28):
            return CapabilityResult(success=False, error="temp out of 15-28°C range")
        if not ctx.vin: return CapabilityResult(success=False, error="VIN required")
        await ctx.tesla_client.set_temps(ctx.vin, d, p)
        return CapabilityResult(success=True, data={"driver": d, "passenger": p})


class SetPreconditioningMax(Capability):
    """Tesla 'max defrost' mode — runs HVAC at max heat + sets
    seat heaters to high. Useful to stage before leaving in
    sub-zero weather. on=true engages, on=false disengages."""

    @property
    def id(self) -> str: return "tesla.climate.set_preconditioning_max"
    @property
    def safety_class(self) -> SafetyClass: return SafetyClass.WRITABLE

    @property
    def params_schema(self) -> dict:
        return {
            "type": "object",
            "properties": {"on": {"type": "boolean"}},
            "required": ["on"],
        }

    async def invoke(self, ctx: CapabilityCallContext, params: dict) -> CapabilityResult:
        on = params.get("on")
        if not isinstance(on, bool):
            return CapabilityResult(success=False, error="on must be bool")
        if not ctx.vin: return CapabilityResult(success=False, error="VIN required")
        await ctx.tesla_client.set_preconditioning_max(ctx.vin, on)
        return CapabilityResult(success=True, data={"on": on})


class SetCabinOverheatProtection(Capability):
    """Tesla cabin-overheat protection mode — keeps cabin under
    a target temp while parked in summer. Modes:
    0=Off, 1=On (no fan), 2=Fan-only.
    """

    @property
    def id(self) -> str: return "tesla.climate.set_cabin_overheat"
    @property
    def safety_class(self) -> SafetyClass: return SafetyClass.WRITABLE

    @property
    def params_schema(self) -> dict:
        return {
            "type": "object",
            "properties": {
                "mode": {"type": "integer", "enum": [0, 1, 2]},
            },
            "required": ["mode"],
        }

    async def invoke(self, ctx: CapabilityCallContext, params: dict) -> CapabilityResult:
        mode = params.get("mode")
        if mode not in (0, 1, 2):
            return CapabilityResult(success=False, error="mode must be 0/1/2")
        if not ctx.vin: return CapabilityResult(success=False, error="VIN required")
        await ctx.tesla_client.set_cabin_overheat_protection(ctx.vin, mode)
        return CapabilityResult(success=True, data={"mode": mode})

    def expected_state(self, params: dict) -> dict:
        # tel:vehicle.cabin_overheat_protection_on is bool — true for mode 1 OR 2
        mode = params.get("mode")
        if not isinstance(mode, int):
            return {}
        return {"vehicle.cabin_overheat_protection_on": mode != 0}


register(ClimateStop())
register(SetTemps())
register(SetPreconditioningMax())
register(SetCabinOverheatProtection())
