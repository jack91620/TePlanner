"""Background polling scheduler — the heart of the automation-first
product bet. Runs alongside FastAPI under the same asyncio loop, ticks
every settings.AUTOMATION_POLL_INTERVAL_SECONDS, and for each
(user, vehicle) pair:

  1. Fetches a fresh Tesla token (refreshes if expired).
  2. Calls Tesla Fleet API /vehicle_data.
  3. Hands the snapshot to AutomationEngine which writes per-rule state
     and fires APNs pushes on transitions.

Doesn't wake sleeping cars (would burn Tesla quota + drain battery).
Skips users without a registered device token (no one to push to).
Token refresh failures are logged and the user is skipped this tick.

Lifecycle is bound to FastAPI's lifespan; cancelling the task on
shutdown gives it ~AUTOMATION_POLL_INTERVAL_SECONDS to drain.
"""

from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timedelta, timezone
from typing import Iterable, List, Optional

from sqlalchemy import distinct, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.core.security import TokenEncryption
from app.db.models import DeviceToken, TeslaToken, User, Vehicle
from app.db.session import async_session
from app.integrations.tesla import TeslaAuth, TeslaClient
from app.services.automation.base import (
    AutomationSettings,
    VehicleStateSnapshot,
)
from app.services.automation.engine import AutomationEngine

logger = logging.getLogger(__name__)


async def _get_or_refresh_tesla_token(
    db: AsyncSession, user_id: int
) -> Optional[str]:
    """Return a usable plaintext access token for `user_id`, refreshing
    if the stored token has expired. Returns None when the user has no
    tokens or refresh fails (caller should skip the tick).
    """
    stmt = (
        select(TeslaToken)
        .where(TeslaToken.user_id == user_id)
        .order_by(TeslaToken.updated_at.desc())
    )
    token = (await db.execute(stmt)).scalars().first()
    if token is None:
        return None

    encryption = TokenEncryption()
    is_expired = token.expires_at is None or token.expires_at < datetime.utcnow()
    if is_expired:
        try:
            refresh_plain = encryption.decrypt(token.refresh_token)
        except Exception:
            refresh_plain = token.refresh_token
        try:
            auth = TeslaAuth()
            new_tokens = await auth.refresh_token(refresh_plain)
            token.access_token = encryption.encrypt(new_tokens["access_token"])
            token.refresh_token = encryption.encrypt(new_tokens["refresh_token"])
            token.expires_at = datetime.utcnow() + timedelta(
                seconds=new_tokens.get("expires_in", 3600)
            )
            await db.flush()
            return new_tokens["access_token"]
        except Exception as exc:
            logger.warning("tesla token refresh failed for user=%s: %s", user_id, exc)
            return None

    try:
        return encryption.decrypt(token.access_token)
    except Exception:
        return token.access_token


def _build_snapshot(vehicle_data: dict) -> VehicleStateSnapshot:
    """Fold a raw /vehicle_data response into the subset the rules read."""
    response = vehicle_data.get("response", {}) or vehicle_data
    charge_state = response.get("charge_state", {}) or {}
    climate_state = response.get("climate_state", {}) or {}
    vehicle_state = response.get("vehicle_state", {}) or {}
    drive_state = response.get("drive_state", {}) or {}

    raw_keeper = climate_state.get("climate_keeper_mode")
    keeper_int: Optional[int]
    if isinstance(raw_keeper, int):
        keeper_int = raw_keeper
    elif isinstance(raw_keeper, str):
        keeper_int = {"off": 0, "on": 1, "dog": 2, "camp": 3}.get(raw_keeper.lower())
    else:
        keeper_int = None

    cabin_overheat = climate_state.get("cabin_overheat_protection") or climate_state.get(
        "cabin_overheat_protection_on"
    )
    cabin_overheat_on: Optional[bool]
    if isinstance(cabin_overheat, bool):
        cabin_overheat_on = cabin_overheat
    elif isinstance(cabin_overheat, str):
        cabin_overheat_on = cabin_overheat.lower() in ("on", "true", "1")
    else:
        cabin_overheat_on = None

    # Slice A — closure / lock state. Tesla returns each door + window
    # as int (0=closed, non-zero=open) at the vehicle_state.* path;
    # frunk/trunk are `ft`/`rt`. Reduce to a single bool per category
    # so rules can speak "any door open" without enumerating four ids.
    def _any_nonzero(*keys: str) -> Optional[bool]:
        seen_value = False
        any_open = False
        for k in keys:
            v = vehicle_state.get(k)
            if v is None:
                continue
            seen_value = True
            try:
                if int(v) != 0:
                    any_open = True
                    break
            except (TypeError, ValueError):
                pass
        return any_open if seen_value else None

    locked_raw = vehicle_state.get("locked")
    locked: Optional[bool] = bool(locked_raw) if isinstance(locked_raw, bool) else None

    return VehicleStateSnapshot(
        battery_level=charge_state.get("battery_level"),
        charging_state=charge_state.get("charging_state"),
        sentry_mode_on=vehicle_state.get("sentry_mode"),
        cabin_overheat_protection_on=cabin_overheat_on,
        climate_keeper_mode=keeper_int,
        locked=locked,
        shift_state=drive_state.get("shift_state"),
        door_open=_any_nonzero("df", "dr", "pf", "pr"),
        window_open=_any_nonzero("fd_window", "fp_window", "rd_window", "rp_window"),
        frunk_open=_any_nonzero("ft"),
        trunk_open=_any_nonzero("rt"),
    )


async def _eligible_user_ids(db: AsyncSession) -> List[int]:
    """Users that have BOTH a TeslaToken and at least one DeviceToken
    are the only ones worth polling — no Tesla token = nothing to read,
    no device token = nowhere to push.
    """
    has_device_q = select(distinct(DeviceToken.user_id))
    has_tesla_q = select(distinct(TeslaToken.user_id))
    device_users = set((await db.execute(has_device_q)).scalars().all())
    tesla_users = set((await db.execute(has_tesla_q)).scalars().all())
    return sorted(device_users & tesla_users)


async def _poll_one_user(db: AsyncSession, user_id: int, engine: AutomationEngine) -> None:
    access_token = await _get_or_refresh_tesla_token(db, user_id)
    if not access_token:
        return

    # Pick the user's first vehicle (we don't yet support multi-vehicle
    # per user in the UI either; matches current iOS HomeViewModel).
    veh_stmt = select(Vehicle).where(Vehicle.user_id == user_id).limit(1)
    vehicle = (await db.execute(veh_stmt)).scalars().first()
    if vehicle is None:
        return

    rule_settings = AutomationSettings()
    try:
        async with TeslaClient(access_token=access_token) as client:
            data = await client.get_vehicle_data(vehicle.tesla_vehicle_id)
    except Exception as exc:
        # Common: vehicle is asleep (408) or token revoked (401). Skip
        # this tick rather than waking — quota / battery hostile.
        logger.info("vehicle_data skipped user=%s vid=%s: %s", user_id, vehicle.id, exc)
        return

    snapshot = _build_snapshot(data)
    result = await engine.run_for_vehicle(
        db,
        user_id=user_id,
        vehicle_id=str(vehicle.tesla_vehicle_id),
        state=snapshot,
        settings=rule_settings,
    )
    if result.pushed_count or result.cleared_count:
        logger.info(
            "tick user=%s pushed=%s cleared=%s alerts=%s",
            user_id,
            result.pushed_count,
            result.cleared_count,
            [a.kind.value for a in result.alerts],
        )


async def run_one_tick(engine: Optional[AutomationEngine] = None) -> int:
    """One full pass over all eligible users. Returns the number of
    users polled. Exposed for ad-hoc /admin or smoke testing.
    """
    engine = engine or AutomationEngine()
    polled = 0
    async with async_session() as db:
        try:
            user_ids = await _eligible_user_ids(db)
            for uid in user_ids:
                try:
                    await _poll_one_user(db, uid, engine)
                    polled += 1
                except Exception as exc:
                    logger.exception("poll failed user=%s: %s", uid, exc)
            await db.commit()
        except Exception:
            await db.rollback()
            raise
    return polled


async def polling_loop(stop_event: asyncio.Event) -> None:
    """Long-running coroutine: tick → sleep → tick → … Cancelled by
    setting `stop_event` (FastAPI lifespan does this on shutdown).
    """
    interval = float(settings.AUTOMATION_POLL_INTERVAL_SECONDS)
    engine = AutomationEngine()
    logger.info("polling loop started (interval=%.0fs)", interval)
    while not stop_event.is_set():
        started = datetime.now(timezone.utc)
        try:
            count = await run_one_tick(engine)
            elapsed = (datetime.now(timezone.utc) - started).total_seconds()
            logger.info("polling tick complete: users=%s elapsed=%.1fs", count, elapsed)
        except Exception as exc:
            logger.exception("polling tick crashed: %s", exc)
        # Sleep with cancellable wait so shutdown is responsive.
        try:
            await asyncio.wait_for(stop_event.wait(), timeout=interval)
        except asyncio.TimeoutError:
            pass
    logger.info("polling loop stopping")
