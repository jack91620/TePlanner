"""active_trip: off-route detection state

Revision ID: 0014_active_trip_off_route
Revises: 0013_active_trip_soc_warning
Create Date: 2026-05-14

Why:
- Phase 4 of the active-trip monitor: detect when the car has
  deviated from the planned polyline and warn the user so they can
  decide whether to replan. We need two pieces of state on the row:

  - ``off_route_since``: when the user first crossed the deviation
    threshold. Used for debouncing — we want N consecutive ticks
    off-route before claiming "they meant it" (parking-lot detours
    shouldn't fire). When the car returns within threshold we clear
    this so the counter restarts cleanly.
  - ``last_off_route_warning_at``: most-recent push. 5-min debounce
    prevents spam if the user stays off-route long after the
    warning was acknowledged.

Both nullable; no backfill.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0014_active_trip_off_route"
down_revision: Union[str, None] = "0013_active_trip_soc_warning"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "active_trip",
        sa.Column("off_route_since", sa.DateTime(), nullable=True),
    )
    op.add_column(
        "active_trip",
        sa.Column("last_off_route_warning_at", sa.DateTime(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("active_trip", "last_off_route_warning_at")
    op.drop_column("active_trip", "off_route_since")
