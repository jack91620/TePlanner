"""Capability registry — Tesla / future-brand command surface.

Phase 10.1: groundwork for the user-extensible automation engine.
Each "capability" is a typed wrapper around one Tesla Fleet API
command (today) or one read (later). The automation engine and HTTP
endpoints both invoke through the registry rather than calling
TeslaClient methods directly. Lets us:

- swap brands later (Li Auto, NIO, HomeKit) without touching the engine
- expose a single capability list to the iOS visual builder
- enforce safety-class metadata at one place

This module only defines the protocol + value types. Concrete Tesla
capabilities live under `tesla/` and self-register on import.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Optional


class SafetyClass(str, Enum):
    """How dangerous is invoking this capability without explicit user
    intent? Used by the rule builder to gate user-authored rules and
    by the engine to require additional acknowledgement on dispatch.
    """
    READ = "read"           # state read, side-effect free
    WRITABLE = "writable"   # changes a setting (climate, charge limit)
    SECURITY = "security"   # weakens car's security posture (sentry off, unlock)
    MOVEMENT = "movement"   # could cause physical motion (drive, summon)


@dataclass
class CapabilityResult:
    success: bool
    data: Optional[dict] = None
    error: Optional[str] = None


@dataclass
class CapabilityCallContext:
    """Plumbing each capability needs. Built by the dispatcher from
    the HTTP request / automation tick.

    `vehicle_id` is the numeric Tesla id (used by old REST endpoints
    like navigation_gps_request); `vin` is the resolved VIN (required
    for VCP-signed commands routed through tesla-http-proxy). The
    dispatcher resolves both when it can.
    """
    vehicle_id: str
    vin: Optional[str]
    tesla_client: Any
    user_id: int


class Capability(ABC):
    """One Tesla command/read. Subclasses live under
    `app/services/capabilities/tesla/` and self-register at import
    time via `register(...)`.
    """

    @property
    @abstractmethod
    def id(self) -> str: ...

    @property
    def brand(self) -> str:
        return "tesla"

    @property
    @abstractmethod
    def safety_class(self) -> SafetyClass: ...

    @property
    def requires_user_confirm(self) -> bool:
        """User-authored rules invoking this need an explicit "I
        understand" toggle before save. Always True for non-READ.
        """
        return self.safety_class != SafetyClass.READ

    @property
    def cost_units(self) -> int:
        """Approximate Tesla Fleet API quota cost. Used by future rate
        limiter; default 1 token per invocation."""
        return 1

    @property
    def params_schema(self) -> dict:
        """JSONSchema describing accepted params. Used by the iOS
        builder to render param inputs. Default empty (no params)."""
        return {}

    @abstractmethod
    async def invoke(
        self, ctx: CapabilityCallContext, params: dict
    ) -> CapabilityResult: ...

    def describe(self) -> dict:
        """Serialized form for /api/v1/capabilities listing."""
        return {
            "id": self.id,
            "brand": self.brand,
            "safety_class": self.safety_class.value,
            "requires_user_confirm": self.requires_user_confirm,
            "cost_units": self.cost_units,
            "params_schema": self.params_schema,
        }
