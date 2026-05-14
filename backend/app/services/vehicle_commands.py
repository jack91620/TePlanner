"""Vehicle command dispatch service.

Extracted from `app/api/v1/vehicles.py` so handlers stay thin (parse
request → call service → return response) and the dispatch logic
itself becomes unit-testable without spinning up FastAPI's TestClient.

The two public entry points are:

  - ``resolve_vin(vehicle_id, user, db)``: numeric Tesla vehicle_id
    → VIN. VCP / signed-command path keys on VIN; the iOS contract
    uses numeric ids matching `list_vehicles()` output.

  - ``invoke_capability(capability_id, vehicle_id, params, user,
    tesla_client, db, require_vin=True)``: shared command pipeline
    used by all 6 write endpoints (climate-keeper-mode, sentry-mode,
    charge-limit, preheat, navigate, navigate-address). It:

      1. Resolves VIN (if required).
      2. Phase 10: checks vehicle connectivity. If DISCONNECTED:
         - dispatch_policy=drop_if_offline → 503
         - dispatch_policy=queue → write CommandQueue row, return 202
         - else fall through to normal dispatch.
      3. Dispatches the capability via the registry.
      4. Maps Tesla SDK exceptions to HTTPException (kept here for
         pragmatic reasons — FastAPI handles HTTPException natively).
      5. Phase 9: writes CommandPending so the resolver can confirm
         via the next telemetry frame.

Note on layering: this service still raises HTTPException because the
sole consumer is FastAPI handlers. If a non-HTTP caller (background
job, CLI) needs the same logic later, swap the HTTPException raises
for domain-specific exceptions and translate at the handler layer.
"""

from __future__ import annotations

import logging
from typing import Optional

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import User, Vehicle
from app.integrations.tesla import TeslaClient
from app.integrations.tesla.exceptions import TeslaAPIError, TeslaVehicleOfflineError
from app.services.capabilities import dispatch as capability_dispatch
from app.services.capabilities import get as get_capability
from app.services.capabilities.base import Capability, CapabilityCallContext
from app.services.command_queue import connectivity_state, enqueue
from app.services.automation.pending_resolver import write_pending
from app.services.telemetry.snapshot import _read_value

logger = logging.getLogger(__name__)


def _values_equal(observed: object, target: object) -> bool:
    """Compare a fresh telemetry reading against the capability's
    declared post-state target. Telemetry decoders return native
    Python types (bool / int / float / str); we mostly need exact
    equality but normalize numeric comparisons so an int target
    matches a float reading.
    """
    if isinstance(target, bool):
        return isinstance(observed, bool) and observed == target
    if isinstance(target, (int, float)) and not isinstance(target, bool):
        if isinstance(observed, bool) or not isinstance(observed, (int, float)):
            return False
        return float(observed) == float(target)
    return observed == target


async def _already_at_target(
    db: AsyncSession,
    user_id: int,
    vin: str,
    cap: Capability,
    params: dict,
) -> Optional[dict]:
    """Return ``{"current": {...}, "target": {...}}`` when fresh
    telemetry shows every entity the capability would mutate is
    already at the declared target value — meaning dispatching the
    command is a no-op. Returns ``None`` whenever the target cannot
    be verified (empty expected_state, any entity stale or never
    observed, mismatch).

    Why: avoids colliding with Tesla on-car Routines (and our own
    re-fires) when both systems aim at the same end state. ``_read_value``
    already enforces a staleness gate so we never treat a 3-hour-old
    reading as proof of "no command needed".
    """
    target = cap.expected_state(params)
    if not target:
        return None
    snapshot: dict = {}
    for entity in target:
        snapshot[entity] = await _read_value(db, user_id, vin, entity)
    if any(v is None for v in snapshot.values()):
        return None
    if not all(_values_equal(snapshot[e], target[e]) for e in target):
        return None
    return {"current": snapshot, "target": dict(target)}


async def resolve_vin(
    vehicle_id: str,
    user: User,
    db: AsyncSession,
) -> str:
    """Look up the VIN for a Tesla numeric vehicle ID.

    Raises 404 when the vehicle isn't tied to the requesting user.
    """
    result = await db.execute(
        select(Vehicle).where(
            Vehicle.user_id == user.id,
            Vehicle.vehicle_id == vehicle_id,
        )
    )
    veh = result.scalar_one_or_none()
    if not veh or not veh.vin:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Vehicle {vehicle_id} not found or has no VIN",
        )
    return veh.vin


async def invoke_capability(
    capability_id: str,
    vehicle_id: str,
    params: dict,
    user: User,
    tesla_client: TeslaClient,
    db: AsyncSession,
    require_vin: bool = True,
) -> dict:
    """Dispatch a Tesla capability for the given vehicle.

    Same shape as the previous private helper in vehicles.py. See
    module docstring for the steps it runs.
    """
    vin = await resolve_vin(vehicle_id, user, db) if require_vin else None
    ctx = CapabilityCallContext(
        vehicle_id=vehicle_id,
        vin=vin,
        tesla_client=tesla_client,
        user_id=user.id,
    )

    if vin:
        cap = get_capability(capability_id)
        # Idempotence — if fresh telemetry already shows the car at the
        # target state, don't dispatch. Prevents collisions with Tesla
        # 车机 Routines and our own re-fires within the cron window.
        # Runs before the connectivity branch so we don't queue a
        # no-op for an offline car either.
        if cap is not None:
            match = await _already_at_target(db, user.id, vin, cap, params)
            if match is not None:
                logger.info(
                    "skip command idempotence: capability=%s vin=%s "
                    "user=%s target=%s",
                    capability_id, vin, user.id, match["target"],
                )
                return {
                    "success": True,
                    "skipped": True,
                    "reason": "already_at_target",
                    "current": match["current"],
                    "target": match["target"],
                }
        conn = await connectivity_state(db, user.id, vin)
        if cap is not None and conn == "DISCONNECTED":
            policy = cap.dispatch_policy
            if policy == "drop_if_offline":
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail="Vehicle offline; this command can't be queued.",
                )
            if policy == "queue":
                row = await enqueue(
                    db,
                    user_id=user.id, vin=vin,
                    capability_id=capability_id,
                    params=params,
                    dispatch_policy=policy,
                )
                await db.commit()
                return {
                    "success": True,
                    "queued": True,
                    "queued_command_id": row.id,
                    "message": "Vehicle offline. Command will run on next connect.",
                }

    try:
        async with tesla_client:
            result = await capability_dispatch(capability_id, ctx, params)
    except TeslaVehicleOfflineError:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Vehicle is offline. Please wake up the vehicle first.",
        )
    except TeslaAPIError as e:
        raise HTTPException(
            status_code=e.status_code or 500,
            detail=f"Tesla API error: {str(e)}",
        )
    if not result.success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=result.error or "Capability invocation failed",
        )

    # Phase 9 — write a CommandPending row so the resolver can confirm
    # via the next telemetry frame.
    pending_id: Optional[int] = None
    if vin:
        cap = get_capability(capability_id)
        if cap is not None:
            expected = cap.expected_state(params)
            row = await write_pending(
                db,
                user_id=user.id,
                vehicle_id=vin,
                capability_id=capability_id,
                expected=expected,
            )
            if row is not None:
                await db.commit()
                pending_id = row.id

    out = {"success": True, **(result.data or {})}
    if pending_id is not None:
        out["pending_command_id"] = pending_id
    return out
