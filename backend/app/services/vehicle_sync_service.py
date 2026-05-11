"""Tesla → local Vehicle row sync service.

Extracted from `app/api/v1/vehicles.py:list_vehicles` so the
upsert-from-Tesla loop is testable + reusable from non-HTTP entry
points (e.g. a daily reconciliation cron).

Public entry:
  - ``sync_vehicles(user, tesla_client, db)``: fetch the user's
    vehicles from Tesla, upsert each into the Vehicle table
    (preserving is_primary / display_name overrides on existing
    rows), return the list as ready-to-serialize dicts.

Tesla SDK exceptions propagate to the handler.
"""

from __future__ import annotations

import logging
from typing import List

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import User, Vehicle
from app.integrations.tesla import TeslaClient

logger = logging.getLogger(__name__)


def _parse_model(vin: str) -> str:
    """VIN char[3] is Tesla's model letter: S/3/X/Y. Defaults Tesla."""
    if not vin or len(vin) < 4:
        return "Tesla"
    return f"Model {vin[3]}" if vin[3] in "S3XY" else "Tesla"


async def sync_vehicles(
    user: User,
    tesla_client: TeslaClient,
    db: AsyncSession,
) -> List[dict]:
    """Pull vehicle list from Tesla, upsert each row.

    Returns one dict per vehicle in the shape:
      ``{id, vin, display_name, model, state, is_primary}``

    Caller wraps the list in VehicleResponse / VehicleListResponse.
    """
    async with tesla_client:
        response = await tesla_client.list_vehicles()
    vehicles_data = response.get("response", [])

    out: List[dict] = []
    for v in vehicles_data:
        vehicle_id = str(v.get("id"))
        existing = (await db.execute(
            select(Vehicle).where(
                Vehicle.user_id == user.id,
                Vehicle.vehicle_id == vehicle_id,
            )
        )).scalar_one_or_none()

        is_primary = existing.is_primary if existing is not None else False

        if existing is None:
            db.add(Vehicle(
                user_id=user.id,
                vehicle_id=vehicle_id,
                vin=v.get("vin"),
                display_name=v.get("display_name"),
                model=_parse_model(v.get("vin", "")),
            ))
        else:
            # Tesla key absent → keep existing DB value (might be the
            # legitimate name from a prior sync). Tesla key present
            # but null → overwrite with null so iOS sees the truth.
            if "display_name" in v:
                existing.display_name = v["display_name"]
            existing.vin = v.get("vin", existing.vin)

        out.append({
            "id": vehicle_id,
            "vin": v.get("vin"),
            "display_name": v.get("display_name"),
            "model": _parse_model(v.get("vin", "")),
            "state": v.get("state", "unknown"),
            "is_primary": is_primary,
        })

    await db.commit()
    return out
