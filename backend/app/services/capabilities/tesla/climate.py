"""Tesla climate-related capabilities."""

from __future__ import annotations

from app.services.capabilities import register
from app.services.capabilities.base import (
    Capability,
    CapabilityCallContext,
    CapabilityResult,
    SafetyClass,
)


class SetClimateKeeperMode(Capability):
    """Set climate keeper mode: 0=off, 1=keep, 2=dog, 3=camp.

    Wraps `TeslaClient.set_climate_keeper_mode` (VCP-signed via
    tesla-http-proxy, keys on VIN).
    """

    @property
    def id(self) -> str:
        return "tesla.climate.set_keeper_mode"

    @property
    def safety_class(self) -> SafetyClass:
        return SafetyClass.WRITABLE

    @property
    def params_schema(self) -> dict:
        return {
            "type": "object",
            "properties": {
                "mode": {
                    "type": "integer",
                    "enum": [0, 1, 2, 3],
                    "description": "0=off, 1=keep, 2=dog, 3=camp",
                }
            },
            "required": ["mode"],
        }

    async def invoke(
        self, ctx: CapabilityCallContext, params: dict
    ) -> CapabilityResult:
        mode = params.get("mode")
        if mode not in (0, 1, 2, 3):
            return CapabilityResult(success=False, error="mode must be 0..3")
        if not ctx.vin:
            return CapabilityResult(success=False, error="VIN required")
        await ctx.tesla_client.set_climate_keeper_mode(ctx.vin, mode)
        return CapabilityResult(success=True, data={"mode": mode})

    def expected_state(self, params: dict) -> dict:
        # After set_keeper_mode(N), the next telemetry frame should
        # show vehicle.climate.keeper_mode == N. Phase 9 confirmation.
        mode = params.get("mode")
        if mode not in (0, 1, 2, 3):
            return {}
        return {"vehicle.climate.keeper_mode": mode}


class Preheat(Capability):
    """Start HVAC (auto_conditioning_start) so the cabin is at temp
    on arrival. Used by the 出发前预热 automation."""

    @property
    def id(self) -> str:
        return "tesla.climate.preheat"

    @property
    def safety_class(self) -> SafetyClass:
        return SafetyClass.WRITABLE

    async def invoke(
        self, ctx: CapabilityCallContext, params: dict
    ) -> CapabilityResult:
        if not ctx.vin:
            return CapabilityResult(success=False, error="VIN required")
        await ctx.tesla_client.auto_conditioning_start(ctx.vin)
        return CapabilityResult(success=True)

    @property
    def dispatch_policy(self) -> str:
        # Preheat is time-sensitive: a "preheat at 7am" command that
        # finally lands at 9am because the car was asleep would
        # surprise the user. Drop instead of queue.
        return "drop_if_offline"


register(SetClimateKeeperMode())
register(Preheat())
