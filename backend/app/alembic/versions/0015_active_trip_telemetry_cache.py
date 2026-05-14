"""active_trip: cache speed + SOC for ETA / arrival-SOC display

Revision ID: 0015_active_trip_telemetry_cache
Revises: 0014_active_trip_off_route
Create Date: 2026-05-14

Why:
- The iOS Hub trip card wants to surface "距 7.2 km · 约 12 分钟 ·
  预计到达 35%" alongside the next-stop name. The first two need
  current speed; the third needs current SOC. Both are already
  available in the cron monitor (snapshot fields battery_level +
  speed_kmh), but only the position was persisted on the trip row.
- Caching them on active_trip lets `/trips/active` return derived
  ETA + projected SOC without re-reading telemetry on every poll.

Schema:
- last_speed_kmh          nullable Float
- last_battery_level_pct  nullable Integer

Both nullable; no backfill.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0015_active_trip_telemetry_cache"
down_revision: Union[str, None] = "0014_active_trip_off_route"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "active_trip",
        sa.Column("last_speed_kmh", sa.Float(), nullable=True),
    )
    op.add_column(
        "active_trip",
        sa.Column("last_battery_level_pct", sa.Integer(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("active_trip", "last_battery_level_pct")
    op.drop_column("active_trip", "last_speed_kmh")
