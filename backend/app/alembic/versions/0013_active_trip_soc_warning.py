"""active_trip: last_soc_warning_at column for SOC-aware monitoring

Revision ID: 0013_active_trip_soc_warning
Revises: 0012_active_trip
Create Date: 2026-05-14

Why:
- Phase 3a of the active-trip monitor: estimate projected SOC at the
  next planned charging stop based on current battery level + km
  remaining + a typical consumption rate. When the projection drops
  below a safety threshold (5% by default), push a warning to the
  user so they can pull over and find a closer station manually.
- Without rate-limiting we'd push every 30s while the user is still
  on the road. last_soc_warning_at lets the monitor remember "I
  already warned you" and back off (5 min default debounce).

Schema:
- last_soc_warning_at  nullable DateTime — most recent SOC-warning
                       push timestamp on this trip. NULL = never warned.

Single nullable column; no backfill needed.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0013_active_trip_soc_warning"
down_revision: Union[str, None] = "0012_active_trip"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "active_trip",
        sa.Column("last_soc_warning_at", sa.DateTime(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("active_trip", "last_soc_warning_at")
