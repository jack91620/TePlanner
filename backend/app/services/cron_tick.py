"""Cron-only background tick — Phase 6.

State-driven rules (camp/sentry/cabin/charge-complete/locked/closures/
low-battery) now evaluate from inside the Telemetry consumer the moment
a transition writes a `tel:*` row. They no longer depend on a periodic
loop calling /vehicle_data.

What still needs a periodic wakeup is the **cron-trigger family** —
``WEEKDAY_PREHEAT`` and any future schedule-based rules. They fire
based on wall-clock time, not vehicle state, so the consumer can't
drive them on its own. This module is that wakeup, and nothing else.

No Tesla HTTP calls happen here. The snapshot fed to the engine is
reconstructed from the latest telemetry-recorded ``tel:<entity>:value``
rows — same source the consumer uses. Cron rules don't read the
snapshot, but state-duration rules might still re-fire here if their
threshold elapsed mid-tick (e.g. camp mode crossed 2h between V
records). That's correct behaviour and basically free.
"""

from __future__ import annotations

import asyncio
import logging
from typing import List, Optional

from sqlalchemy import distinct, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.db.models import DeviceToken, TeslaToken, Vehicle
from app.db.session import async_session
from app.services.automation.base import AutomationSettings
from app.services.automation.engine import AutomationEngine
from app.services.automation.pending_resolver import check_and_resolve
from app.services.telemetry.snapshot import build_snapshot_from_telemetry

logger = logging.getLogger(__name__)


async def _eligible_user_ids(db: AsyncSession) -> List[int]:
    """Users with both a TeslaToken (so the engine can sign commands
    if a rule's action requires VCP) and a DeviceToken (so we have
    somewhere to push). Drops users who logged out or never registered
    a device.
    """
    has_device_q = select(distinct(DeviceToken.user_id))
    has_tesla_q = select(distinct(TeslaToken.user_id))
    device_users = set((await db.execute(has_device_q)).scalars().all())
    tesla_users = set((await db.execute(has_tesla_q)).scalars().all())
    return sorted(device_users & tesla_users)


async def _tick_one_user(
    db: AsyncSession, user_id: int, engine: AutomationEngine,
) -> None:
    veh_stmt = select(Vehicle).where(Vehicle.user_id == user_id).limit(1)
    vehicle = (await db.execute(veh_stmt)).scalars().first()
    if vehicle is None:
        return
    vin = vehicle.vin
    if not vin:
        return

    snapshot = await build_snapshot_from_telemetry(
        db, user_id=user_id, vehicle_id=vin,
    )
    result = await engine.run_for_vehicle(
        db,
        user_id=user_id,
        vehicle_id=vin,
        state=snapshot,
        settings=AutomationSettings(),
    )
    # Phase 9 — resolve pending VCP commands. Telemetry path catches
    # confirmations on transitions; this catches timeouts that the
    # telemetry path missed (vehicle never produced a matching frame).
    await check_and_resolve(
        db, user_id=user_id, vehicle_id=vin, snap=snapshot,
    )
    if result.pushed_count or result.cleared_count:
        logger.info(
            "cron tick user=%s vin=%s pushed=%s cleared=%s",
            user_id, vin, result.pushed_count, result.cleared_count,
        )


async def run_one_tick(engine: Optional[AutomationEngine] = None) -> int:
    """One pass over all eligible users. Returns the count polled.
    Exposed for the /run-automation-tick admin endpoint.
    """
    engine = engine or AutomationEngine()
    polled = 0
    async with async_session() as db:
        try:
            user_ids = await _eligible_user_ids(db)
            for uid in user_ids:
                try:
                    await _tick_one_user(db, uid, engine)
                    polled += 1
                except Exception as exc:
                    logger.exception("cron tick failed user=%s: %s", uid, exc)
            await db.commit()
        except Exception:
            await db.rollback()
            raise
    return polled


def _interval_seconds() -> float:
    """Phase 6 introduces AUTOMATION_CRON_TICK_SECONDS (default 30).
    For one-release backwards compatibility, fall through to the old
    AUTOMATION_POLL_INTERVAL_SECONDS if the new setting is unset or
    holds its default poll-era value of 300.
    """
    new = getattr(settings, "AUTOMATION_CRON_TICK_SECONDS", 0)
    if new and int(new) > 0:
        return float(new)
    return float(settings.AUTOMATION_POLL_INTERVAL_SECONDS)


async def run_loop(stop_event: asyncio.Event) -> None:
    interval = _interval_seconds()
    engine = AutomationEngine()
    logger.info("cron tick loop started (interval=%.0fs)", interval)
    while not stop_event.is_set():
        try:
            await run_one_tick(engine)
        except Exception as exc:
            logger.exception("cron tick crashed: %s", exc)
        try:
            await asyncio.wait_for(stop_event.wait(), timeout=interval)
        except asyncio.TimeoutError:
            pass
    logger.info("cron tick loop stopping")
