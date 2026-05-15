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

import json
import logging
from datetime import datetime
from typing import Any, Optional

from fastapi import APIRouter, Depends, HTTPException, Response, status
from pydantic import BaseModel, Field
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user, get_db
from app.db.models import (
    ActiveTrip,
    AutomationRule,
    AutomationSnooze,
    AutomationState,
    ChargingSession,
    CommandPending,
    CommandQueue,
    DeviceToken,
    OAuthState,
    PendingWait,
    PushedAlert,
    RoutePlan,
    ScheduledDeparture,
    Share,
    TeslaToken,
    User,
    UserSetting,
    Vehicle,
)

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


# ---------------------------------------------------------------------------
# Phase A.5 — user settings sync.
#
# Opaque key/value JSON store for cross-device UI preference sync.
# Schema is intentionally NOT enforced server-side: clients send
# whatever JSON they want and read it back. Phase D wires iOS
# UserDefaultsSettingsStore to read+write these endpoints; Android /
# Harmony will adopt directly.

class UserSettingsResponse(BaseModel):
    settings: dict[str, Any]
    updated_at: Optional[datetime] = None


class UserSettingsRequest(BaseModel):
    settings: dict[str, Any] = Field(
        ...,
        description=(
            "Full settings document. PUT replaces the keys present "
            "in this dict but leaves untouched keys alone — pass "
            "`replace_all=true` to wipe and re-seed."
        ),
    )
    replace_all: bool = False


def _decode_value(raw: str) -> Any:
    try:
        return json.loads(raw)
    except (json.JSONDecodeError, TypeError):
        return raw


# ---------------------------------------------------------------------------
# Account deletion — App Store 5.1.1(v) hard requirement (since 2022-06).
#
# Removes every row keyed on user_id across the schema, then the User row
# itself. Idempotent inside a single transaction — caller commits or
# rolls back atomically. We do NOT call Tesla's token-revoke endpoint;
# that's the user's choice in tesla.com / app, and partial-permission
# revocation is fragile. The local TeslaToken row is deleted so we
# stop using the credential immediately.

# Tables fanned out per user_id. Order matters: anything that might
# carry an FK to another row in this list goes first. Today no such
# child-of-child FKs exist, but if a future migration adds one
# (e.g. push_history.device_token_id) it has to land before device_tokens.
_DELETION_TABLES = (
    CommandPending,        # tied to vehicle telemetry/commands
    CommandQueue,
    PendingWait,
    DeviceToken,
    PushedAlert,
    AutomationState,
    AutomationSnooze,
    AutomationRule,
    ActiveTrip,
    ScheduledDeparture,
    ChargingSession,
    UserSetting,
    RoutePlan,
    Vehicle,
    TeslaToken,
)


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_account(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Response:
    """Permanently delete the authenticated user's account.

    Apple's 5.1.1(v) review rule (mandatory since June 2022) requires
    in-app account deletion that produces real data removal — not
    deactivation. iOS surfaces this via Settings → 危险操作 → 删除账号.

    What we wipe, in dependency-safe order:
      - All vehicle-scoped queued / pending commands and waits
      - Push device tokens and the per-rule pushed_alerts ledger
      - Automation rules / state / snoozes
      - Active trip, scheduled departure, charging session history
      - User settings dict, saved route plans, vehicles, Tesla tokens
      - Shares the user originated (owner_user_id)
      - OAuth state rows tied to this user
      - The User row itself

    We deliberately don't touch the Tesla account at api.tesla.com —
    that's the user's choice (revoke at tesla.com/account-settings).
    Re-authenticating later via Tesla OAuth simply creates a new User
    row; the existing VIN-dedup logic in tesla_auth_service handles
    the rebuild of vehicle bindings.
    """
    user_id = user.id

    for model in _DELETION_TABLES:
        await db.execute(delete(model).where(model.user_id == user_id))

    # Tables with non-standard FK column names.
    await db.execute(delete(Share).where(Share.owner_user_id == user_id))
    await db.execute(delete(OAuthState).where(OAuthState.user_id == user_id))

    # Finally drop the User row.
    await db.execute(delete(User).where(User.id == user_id))
    await db.commit()

    logger.warning("user %s deleted their account via DELETE /user/me", user_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/settings", response_model=UserSettingsResponse)
async def get_user_settings(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> UserSettingsResponse:
    """Return the user's full settings dict. Empty dict when never set.
    `updated_at` is the most recent row update — clients use it to
    short-circuit re-fetches."""
    rows = (await db.execute(
        select(UserSetting).where(UserSetting.user_id == user.id)
    )).scalars().all()
    settings = {row.key: _decode_value(row.value_json) for row in rows}
    most_recent = max((r.updated_at for r in rows if r.updated_at), default=None)
    return UserSettingsResponse(settings=settings, updated_at=most_recent)


@router.put("/settings", response_model=UserSettingsResponse)
async def upsert_user_settings(
    body: UserSettingsRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> UserSettingsResponse:
    """Merge ``body.settings`` into the user's settings dict (or
    replace entirely if ``replace_all=true``). Each value is
    JSON-encoded for storage. Keys longer than 80 chars or empty are
    rejected (matches column constraint).
    """
    bad_keys = [
        k for k in body.settings.keys()
        if not isinstance(k, str) or not (1 <= len(k) <= 80)
    ]
    if bad_keys:
        raise HTTPException(400, f"invalid setting keys: {bad_keys}")

    existing_rows = (await db.execute(
        select(UserSetting).where(UserSetting.user_id == user.id)
    )).scalars().all()
    by_key = {row.key: row for row in existing_rows}

    if body.replace_all:
        for row in existing_rows:
            if row.key not in body.settings:
                await db.delete(row)

    for key, value in body.settings.items():
        encoded = json.dumps(value, ensure_ascii=False)
        existing = by_key.get(key)
        if existing is not None:
            existing.value_json = encoded
        else:
            db.add(UserSetting(
                user_id=user.id,
                key=key,
                value_json=encoded,
                created_at=datetime.utcnow(),
            ))

    await db.flush()
    logger.info(
        "user %s updated %d settings (replace_all=%s)",
        user.id, len(body.settings), body.replace_all,
    )

    rows = (await db.execute(
        select(UserSetting).where(UserSetting.user_id == user.id)
    )).scalars().all()
    settings = {row.key: _decode_value(row.value_json) for row in rows}
    most_recent = max((r.updated_at for r in rows if r.updated_at), default=None)
    return UserSettingsResponse(settings=settings, updated_at=most_recent)
