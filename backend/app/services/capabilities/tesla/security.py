"""Tesla security-related capabilities (sentry, locks)."""

from __future__ import annotations

from app.services.capabilities import register
from app.services.capabilities.base import (
    Capability,
    CapabilityCallContext,
    CapabilityResult,
    SafetyClass,
)


class SetSentryMode(Capability):
    """Toggle sentry mode. Disabling weakens parked-car security
    posture, so user-authored rules invoking this need explicit
    confirmation."""

    @property
    def id(self) -> str:
        return "tesla.security.set_sentry"

    @property
    def safety_class(self) -> SafetyClass:
        return SafetyClass.SECURITY

    @property
    def params_schema(self) -> dict:
        return {
            "type": "object",
            "properties": {"on": {"type": "boolean"}},
            "required": ["on"],
        }

    async def invoke(
        self, ctx: CapabilityCallContext, params: dict
    ) -> CapabilityResult:
        on = params.get("on")
        if not isinstance(on, bool):
            return CapabilityResult(success=False, error="on must be boolean")
        if not ctx.vin:
            return CapabilityResult(success=False, error="VIN required")
        await ctx.tesla_client.set_sentry_mode(ctx.vin, on)
        return CapabilityResult(success=True, data={"on": on})

    def expected_state(self, params: dict) -> dict:
        on = params.get("on")
        if not isinstance(on, bool):
            return {}
        return {"vehicle.sentry_mode_on": on}


register(SetSentryMode())
