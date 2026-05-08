"""Tesla charging-related capabilities."""

from __future__ import annotations

from app.services.capabilities import register
from app.services.capabilities.base import (
    Capability,
    CapabilityCallContext,
    CapabilityResult,
    SafetyClass,
)


class SetChargeLimit(Capability):
    """Set the daily charge limit SOC (50..100). Tesla rejects values
    outside that range; we validate up-front."""

    @property
    def id(self) -> str:
        return "tesla.charging.set_limit"

    @property
    def safety_class(self) -> SafetyClass:
        return SafetyClass.WRITABLE

    @property
    def params_schema(self) -> dict:
        return {
            "type": "object",
            "properties": {
                "percent": {"type": "integer", "minimum": 50, "maximum": 100}
            },
            "required": ["percent"],
        }

    async def invoke(
        self, ctx: CapabilityCallContext, params: dict
    ) -> CapabilityResult:
        percent = params.get("percent")
        if not isinstance(percent, int) or not (50 <= percent <= 100):
            return CapabilityResult(
                success=False, error="percent must be 50..100"
            )
        if not ctx.vin:
            return CapabilityResult(success=False, error="VIN required")
        await ctx.tesla_client.set_charge_limit(ctx.vin, percent)
        return CapabilityResult(success=True, data={"percent": percent})


register(SetChargeLimit())
