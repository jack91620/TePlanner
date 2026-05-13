"""Background fetch + persist of Tesla vehicle_config.

Fired after a user binds their Tesla account so the iOS rule-builder
/ Hub Action editor can collapse model-specific capabilities (天窗 /
manual charge port) on the *first* open of the picker, without making
the user wait for the car to wake up.

Why not just rely on the next /state call?
- iOS Hub doesn't auto-retry a 503 (asleep car), so the user might
  see the full capability list including 天窗 — fine, but jarring on
  the first try.
- This task is fire-and-forget: errors stay in the log, never
  surface to the user, never block OAuth.

Why asyncio.create_task instead of FastAPI BackgroundTasks?
- BackgroundTasks runs *after the response* but only until the
  request handler scope ends. The Tesla wake-up cycle can take
  30 s + 30 s polling, longer than that scope.
- asyncio.create_task on the application event loop (uvicorn keeps
  it alive across requests) is fine for fire-and-forget background
  jobs the user can't see. We add an unhandled-exception logger so
  silent task crashes don't go unnoticed.
"""

from __future__ import annotations

import asyncio
import logging
from datetime import datetime
from typing import Optional

from sqlalchemy import select

from app.db.models import TeslaToken, Vehicle
from app.db.session import async_session
from app.integrations.tesla import TeslaClient

logger = logging.getLogger(__name__)


# Tunables — keep modest. We're prefetching, not racing real-time.
_WAKE_POLL_SECONDS = 3.0
_WAKE_TIMEOUT_SECONDS = 60.0


async def prefetch_user_vehicle_configs(user_id: int) -> None:
    """Fire-and-forget: wake every vehicle linked to this user, fetch
    its vehicle_config block, and persist car_type / roof_color /
    motorized_charge_port to the vehicles row.

    Skips vehicles that already have a non-null `config_fetched_at`
    (cached forever — these fields are factory-set).
    """
    try:
        await _do_prefetch(user_id)
    except Exception:  # pylint: disable=broad-except
        # Last-line defense. asyncio.create_task swallows exceptions
        # by default — log so we have a paper trail.
        logger.exception(
            "vehicle_config prefetch crashed for user=%s",
            user_id,
        )


async def _do_prefetch(user_id: int) -> None:
    async with async_session() as db:
        # 1. Look up the user's Tesla access token.
        token = (
            await db.execute(
                select(TeslaToken).where(TeslaToken.user_id == user_id)
            )
        ).scalar_one_or_none()
        if token is None:
            logger.debug(
                "vehicle_config prefetch: user=%s has no TeslaToken — skipping",
                user_id,
            )
            return

        # 2. List the vehicles we'd act on (skip ones we already cached).
        vehicles = (await db.execute(
            select(Vehicle).where(
                Vehicle.user_id == user_id,
                Vehicle.config_fetched_at.is_(None),
            )
        )).scalars().all()
        if not vehicles:
            logger.debug(
                "vehicle_config prefetch: user=%s has no uncached vehicles",
                user_id,
            )
            return

        async with TeslaClient(access_token=token.access_token) as client:
            for vehicle in vehicles:
                try:
                    await _fetch_one(client, db, vehicle)
                except Exception:  # pylint: disable=broad-except
                    logger.exception(
                        "vehicle_config prefetch: failed for user=%s vehicle=%s",
                        user_id, vehicle.vehicle_id,
                    )
        await db.commit()


async def _fetch_one(
    client: TeslaClient, db, vehicle: Vehicle,
) -> None:
    """Wake `vehicle` (if needed) and stash its vehicle_config block."""
    woke = await _wake_until_online(client, vehicle.vehicle_id)
    if not woke:
        logger.info(
            "vehicle_config prefetch: vehicle=%s didn't wake within %ss — "
            "leaving cache empty; next /state call will populate naturally",
            vehicle.vehicle_id, _WAKE_TIMEOUT_SECONDS,
        )
        return

    try:
        response = await client.get_vehicle_data(
            vehicle.vehicle_id, endpoints=["vehicle_config"]
        )
    except Exception as exc:  # noqa: BLE001
        logger.warning(
            "vehicle_config prefetch: /vehicle_data failed for vehicle=%s: %s",
            vehicle.vehicle_id, exc,
        )
        return

    config = (response or {}).get("response", {}).get("vehicle_config") or {}
    if not config:
        logger.info(
            "vehicle_config prefetch: empty config for vehicle=%s — "
            "Tesla returned no block, will retry on next /state",
            vehicle.vehicle_id,
        )
        return

    vehicle.car_type = config.get("car_type") or vehicle.car_type
    vehicle.roof_color = config.get("roof_color") or vehicle.roof_color
    if config.get("motorized_charge_port") is not None:
        vehicle.motorized_charge_port = config.get("motorized_charge_port")
    vehicle.config_fetched_at = datetime.utcnow()
    logger.info(
        "vehicle_config prefetch: cached vehicle=%s car_type=%s roof=%s motor_port=%s",
        vehicle.vehicle_id,
        vehicle.car_type, vehicle.roof_color, vehicle.motorized_charge_port,
    )


async def _wake_until_online(
    client: TeslaClient, vehicle_id: str,
) -> bool:
    """Issue `/wake_up` and poll the vehicle's state until "online" or
    until we hit the timeout. Returns True on success."""
    try:
        await client.wake_up(vehicle_id)
    except Exception as exc:  # noqa: BLE001
        logger.warning(
            "vehicle_config prefetch: wake_up failed for vehicle=%s: %s",
            vehicle_id, exc,
        )
        return False

    elapsed = 0.0
    while elapsed < _WAKE_TIMEOUT_SECONDS:
        await asyncio.sleep(_WAKE_POLL_SECONDS)
        elapsed += _WAKE_POLL_SECONDS
        try:
            state = await client.get_vehicle(vehicle_id)
        except Exception as exc:  # noqa: BLE001
            logger.debug(
                "vehicle_config prefetch: poll get_vehicle failed at %.1fs: %s",
                elapsed, exc,
            )
            continue
        if (state or {}).get("response", {}).get("state") == "online":
            return True
    return False


def schedule_prefetch(user_id: Optional[int]) -> None:
    """Spawn a fire-and-forget prefetch task on the running event loop.
    Safe to call from any async handler; no-op when user_id is None."""
    if user_id is None:
        return
    try:
        loop = asyncio.get_running_loop()
    except RuntimeError:
        # No running loop — caller wasn't async. Shouldn't happen in
        # the FastAPI handlers we care about; warn rather than raise.
        logger.warning(
            "schedule_prefetch: no running loop, skipping user=%s",
            user_id,
        )
        return
    loop.create_task(prefetch_user_vehicle_configs(user_id))
