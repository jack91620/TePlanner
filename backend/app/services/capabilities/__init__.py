"""Capability registry — singleton dict + dispatch.

Tesla capabilities self-register on import via the side-effect-only
imports at the bottom of this file. Adding a new capability is:
  1. Subclass `Capability` in a new file under tesla/ (or another
     brand's folder later).
  2. Call `register(MyCapability())` at module bottom.
  3. Ensure that file is imported here (or under tesla/__init__.py).
"""

from __future__ import annotations

import logging
from typing import Optional

from app.services.capabilities.base import (
    Capability,
    CapabilityCallContext,
    CapabilityResult,
    SafetyClass,
)

logger = logging.getLogger(__name__)

_registry: dict[str, Capability] = {}


def register(cap: Capability) -> Capability:
    if cap.id in _registry:
        # Re-registration is a programming error — surface immediately.
        raise ValueError(f"Capability already registered: {cap.id}")
    _registry[cap.id] = cap
    return cap


def get(capability_id: str) -> Optional[Capability]:
    return _registry.get(capability_id)


def all_capabilities() -> list[Capability]:
    return list(_registry.values())


async def dispatch(
    capability_id: str,
    ctx: CapabilityCallContext,
    params: dict,
) -> CapabilityResult:
    """Look up and invoke. Returns success/failure as CapabilityResult
    for in-band errors (unknown id, validation, business logic).
    Network / Tesla SDK exceptions are intentionally NOT caught — they
    propagate so HTTP handlers can map TeslaVehicleOfflineError → 503
    etc. The automation engine wraps in its own try/except.
    """
    cap = _registry.get(capability_id)
    if cap is None:
        logger.warning("dispatch: unknown capability %s", capability_id)
        return CapabilityResult(
            success=False, error=f"Unknown capability: {capability_id}"
        )
    return await cap.invoke(ctx, params)


# Side-effect imports to populate the registry. Order doesn't matter
# but listing all brand modules here prevents the "import cycle" trap
# of touching only some on cold start.
from app.services.capabilities.tesla import climate as _climate  # noqa: E402,F401
from app.services.capabilities.tesla import climate_extra as _climate_extra  # noqa: E402,F401
from app.services.capabilities.tesla import security as _security  # noqa: E402,F401
from app.services.capabilities.tesla import charging as _charging  # noqa: E402,F401
from app.services.capabilities.tesla import charging_extra as _charging_extra  # noqa: E402,F401
from app.services.capabilities.tesla import navigation as _navigation  # noqa: E402,F401
from app.services.capabilities.tesla import comfort as _comfort  # noqa: E402,F401
from app.services.capabilities.tesla import closures as _closures  # noqa: E402,F401
from app.services.capabilities.tesla import attention as _attention  # noqa: E402,F401
