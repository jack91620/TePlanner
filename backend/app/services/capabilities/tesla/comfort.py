"""Tesla 座椅 / 媒体 capabilities — daily-use writes the user can
chain into automation rules.

Examples:
  · 进入家 geofence → 关闭哨兵 + 暂停车机播放
  · 工作日 7:30 → 启动预热 + 主驾座椅加热中档
"""

from __future__ import annotations

from app.services.capabilities import register
from app.services.capabilities.base import (
    Capability,
    CapabilityCallContext,
    CapabilityResult,
    SafetyClass,
)


# 0=driver, 1=passenger, 2=rear-left, 4=rear-center, 5=rear-right.
# 3 is reserved by Tesla; 6/7 are third-row on Model X / Model S Plaid.
_SEAT_LABELS = {
    0: "主驾", 1: "副驾",
    2: "后排左", 4: "后排中", 5: "后排右",
}


class SetSeatHeater(Capability):
    """Set the heated-seat level for one of the 5 main seats. Levels:
    0=关闭, 1=低, 2=中, 3=高."""

    @property
    def id(self) -> str:
        return "tesla.comfort.set_seat_heater"

    @property
    def safety_class(self) -> SafetyClass:
        return SafetyClass.WRITABLE

    @property
    def params_schema(self) -> dict:
        return {
            "type": "object",
            "properties": {
                "seat": {
                    "type": "integer",
                    "enum": list(_SEAT_LABELS.keys()),
                    "description": "0=主驾 1=副驾 2=后左 4=后中 5=后右",
                },
                "level": {
                    "type": "integer",
                    "enum": [0, 1, 2, 3],
                    "description": "0=关闭 1=低 2=中 3=高",
                },
            },
            "required": ["seat", "level"],
        }

    async def invoke(
        self, ctx: CapabilityCallContext, params: dict,
    ) -> CapabilityResult:
        seat = params.get("seat")
        level = params.get("level")
        if seat not in _SEAT_LABELS:
            return CapabilityResult(success=False, error="invalid seat")
        if level not in (0, 1, 2, 3):
            return CapabilityResult(success=False, error="level must be 0..3")
        if not ctx.vin:
            return CapabilityResult(success=False, error="VIN required")
        await ctx.tesla_client.remote_seat_heater_request(ctx.vin, seat, level)
        return CapabilityResult(success=True, data={"seat": seat, "level": level})


class SetSteeringWheelHeater(Capability):
    """Toggle the steering-wheel heater. Most Model 3/Y variants
    support this; level granularity isn't exposed by Fleet API,
    only on/off."""

    @property
    def id(self) -> str:
        return "tesla.comfort.set_steering_wheel_heater"

    @property
    def safety_class(self) -> SafetyClass:
        return SafetyClass.WRITABLE

    @property
    def params_schema(self) -> dict:
        return {
            "type": "object",
            "properties": {"on": {"type": "boolean"}},
            "required": ["on"],
        }

    async def invoke(
        self, ctx: CapabilityCallContext, params: dict,
    ) -> CapabilityResult:
        on = params.get("on")
        if not isinstance(on, bool):
            return CapabilityResult(success=False, error="on must be bool")
        if not ctx.vin:
            return CapabilityResult(success=False, error="VIN required")
        await ctx.tesla_client.remote_steering_wheel_heater_request(ctx.vin, on)
        return CapabilityResult(success=True, data={"on": on})


class MediaTogglePlayback(Capability):
    """Toggle car-side media playback (pause/resume). Per-track
    next/prev are separate capabilities."""

    @property
    def id(self) -> str:
        return "tesla.media.toggle_playback"

    @property
    def safety_class(self) -> SafetyClass:
        return SafetyClass.WRITABLE

    async def invoke(
        self, ctx: CapabilityCallContext, params: dict,
    ) -> CapabilityResult:
        if not ctx.vin:
            return CapabilityResult(success=False, error="VIN required")
        await ctx.tesla_client.media_toggle_playback(ctx.vin)
        return CapabilityResult(success=True)


class AdjustMediaVolume(Capability):
    """Set car-side media volume. Tesla's accepted range is 0.0–11.0.
    iOS preset rules typically use integer 0..10 for simplicity."""

    @property
    def id(self) -> str:
        return "tesla.media.set_volume"

    @property
    def safety_class(self) -> SafetyClass:
        return SafetyClass.WRITABLE

    @property
    def params_schema(self) -> dict:
        return {
            "type": "object",
            "properties": {
                "volume": {
                    "type": "number",
                    "minimum": 0,
                    "maximum": 11,
                    "description": "音量 0–11",
                },
            },
            "required": ["volume"],
        }

    async def invoke(
        self, ctx: CapabilityCallContext, params: dict,
    ) -> CapabilityResult:
        try:
            volume = float(params["volume"])
        except (KeyError, ValueError, TypeError):
            return CapabilityResult(success=False, error="volume required")
        if not (0 <= volume <= 11):
            return CapabilityResult(success=False, error="volume must be 0..11")
        if not ctx.vin:
            return CapabilityResult(success=False, error="VIN required")
        await ctx.tesla_client.adjust_volume(ctx.vin, volume)
        return CapabilityResult(success=True, data={"volume": volume})


register(SetSeatHeater())
register(SetSteeringWheelHeater())
register(MediaTogglePlayback())
register(AdjustMediaVolume())
