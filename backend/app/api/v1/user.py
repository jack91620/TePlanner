"""User-scoped endpoints — Phase A.3 + A.5.

This module owns the user-scoped per-account state that doesn't fit
under a vehicle:
  - Scheduled departure (A.3) — single active "next departure" entry
    that drives the preheat reminder.
  - User settings (A.5) — opaque key/value store the iOS app uses for
    cross-device preference sync (charge-limit suggestion targets,
    departure window length, etc.).

We deliberately keep the endpoints under ``/api/v1/user/*`` (not
``/api/v1/users/me/*``) — there's only ever one current user, JWT
already disambiguates, and the shorter path keeps Hurl + iOS routes
clean.
"""

from __future__ import annotations

import logging
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, status
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user, get_db
from app.db.models import ScheduledDeparture, User

logger = logging.getLogger(__name__)
router = APIRouter()


# ---------------------------------------------------------------------------
# Phase A.3 — scheduled departure.
#
# Mirrors iOS ScheduledDeparture.swift: one row per user, latest write
# replaces. iOS Phase D will wire this in place of the
# UserDefaultsScheduledDepartureStore.

class ScheduledDepartureRequest(BaseModel):
    departure_at_utc: datetime = Field(
        ..., description="When the user intends to drive off (UTC).",
    )
    lead_minutes: int = Field(15, ge=1, le=240)
    label: Optional[str] = Field(None, max_length=64)
    vehicle_id: Optional[str] = Field(None, max_length=64)
    target_charge_soc: Optional[int] = Field(None, ge=20, le=100)
    enabled: bool = True


class ScheduledDepartureResponse(BaseModel):
    id: int
    departure_at_utc: datetime
    lead_minutes: int
    label: Optional[str] = None
    vehicle_id: Optional[str] = None
    target_charge_soc: Optional[int] = None
    enabled: bool
    fire_at_utc: datetime
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


def _row_to_response(row: ScheduledDeparture) -> ScheduledDepartureResponse:
    from datetime import timedelta
    return ScheduledDepartureResponse(
        id=row.id,
        departure_at_utc=row.departure_at_utc,
        lead_minutes=row.lead_minutes,
        label=row.label,
        vehicle_id=row.vehicle_id,
        target_charge_soc=row.target_charge_soc,
        enabled=row.enabled,
        fire_at_utc=row.departure_at_utc - timedelta(minutes=row.lead_minutes),
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


@router.get(
    "/scheduled-departure",
    response_model=Optional[ScheduledDepartureResponse],
)
async def get_scheduled_departure(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Optional[ScheduledDepartureResponse]:
    """Fetch the user's active scheduled departure. Returns ``null``
    when none is set — iOS treats null as "not scheduled" and shows
    the empty card."""
    row = (await db.execute(
        select(ScheduledDeparture).where(ScheduledDeparture.user_id == user.id)
    )).scalar_one_or_none()
    if row is None:
        return None
    return _row_to_response(row)


@router.put(
    "/scheduled-departure",
    response_model=ScheduledDepartureResponse,
)
async def upsert_scheduled_departure(
    body: ScheduledDepartureRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ScheduledDepartureResponse:
    """Replace the user's scheduled departure with the supplied row.
    UNIQUE(user_id) enforces single-row semantics; we update in place
    when a row already exists rather than relying on the DB unique
    error to bubble up.

    Past departures are accepted — the iOS UI prevents them, but a
    server reject would race with clock skew and break preheat
    cancellation flows.
    """
    departure_naive = body.departure_at_utc.replace(tzinfo=None)
    existing = (await db.execute(
        select(ScheduledDeparture).where(ScheduledDeparture.user_id == user.id)
    )).scalar_one_or_none()
    if existing is not None:
        existing.departure_at_utc = departure_naive
        existing.lead_minutes = body.lead_minutes
        existing.label = body.label
        existing.vehicle_id = body.vehicle_id
        existing.target_charge_soc = body.target_charge_soc
        existing.enabled = body.enabled
        row = existing
    else:
        row = ScheduledDeparture(
            user_id=user.id,
            departure_at_utc=departure_naive,
            lead_minutes=body.lead_minutes,
            label=body.label,
            vehicle_id=body.vehicle_id,
            target_charge_soc=body.target_charge_soc,
            enabled=body.enabled,
            created_at=datetime.utcnow(),
        )
        db.add(row)
    await db.flush()
    logger.info(
        "user %s upsert scheduled-departure: at=%s lead=%dmin vehicle=%s",
        user.id, departure_naive.isoformat(), body.lead_minutes, body.vehicle_id,
    )
    return _row_to_response(row)


@router.delete(
    "/scheduled-departure",
    status_code=status.HTTP_200_OK,
)
async def clear_scheduled_departure(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Idempotent — clearing a non-existent row is a 200, not 404."""
    row = (await db.execute(
        select(ScheduledDeparture).where(ScheduledDeparture.user_id == user.id)
    )).scalar_one_or_none()
    if row is not None:
        await db.delete(row)
        await db.flush()
        logger.info("user %s cleared scheduled-departure", user.id)
    return {"success": True}
