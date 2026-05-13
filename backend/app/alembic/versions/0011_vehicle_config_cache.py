"""vehicle_config_cache: persist static Tesla hardware facts on vehicles row

Revision ID: 0011_vehicle_config_cache
Revises: 0010_shares
Create Date: 2026-05-13

Why:
- Capability picker hides 天窗 (sun_roof_*) on Model 3/Y owners
  via the vehicle_config block returned from Tesla's /vehicle_data.
- Fetching that requires the car to be **online** — if the car is
  asleep, /vehicle_data returns 408 and we'd have to wake it
  (5-30 s). Blocking login on that is unacceptable.
- These fields (car_type, roof_color, motorized_charge_port) are
  **factory-set and never change**. Cache them on first successful
  read, then every subsequent /state call returns them from local
  DB with zero Tesla round-trips and zero blocking.

Schema:
- car_type             string — "modely" / "model3" / "models" / "modelx"
- roof_color           string — "Glass" / "Sunroof" / "None" / ...
- motorized_charge_port bool — True when port can be commanded
- config_fetched_at    nullable DateTime — last successful fetch.
                       Used by the picker / background refresher to
                       decide "is this fresh enough?". For static
                       facts the answer is always yes; we keep the
                       timestamp for diagnostics.

All columns nullable so existing rows survive without backfill.
First /state hit for each vehicle will populate them.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0011_vehicle_config_cache"
down_revision: Union[str, None] = "0010_shares"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "vehicles",
        sa.Column("car_type", sa.String(length=32), nullable=True),
    )
    op.add_column(
        "vehicles",
        sa.Column("roof_color", sa.String(length=32), nullable=True),
    )
    op.add_column(
        "vehicles",
        sa.Column("motorized_charge_port", sa.Boolean(), nullable=True),
    )
    op.add_column(
        "vehicles",
        sa.Column("config_fetched_at", sa.DateTime(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("vehicles", "config_fetched_at")
    op.drop_column("vehicles", "motorized_charge_port")
    op.drop_column("vehicles", "roof_color")
    op.drop_column("vehicles", "car_type")
