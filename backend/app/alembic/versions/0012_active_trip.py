"""active_trip: sequential nav for multi-stop charging routes

Revision ID: 0012_active_trip
Revises: 0011_vehicle_config_cache
Create Date: 2026-05-13

Why:
- Tesla Fleet API's navigation_request only accepts ONE destination.
  Sending another replaces (does not append).
- TePlanner plans multi-stop routes that intentionally use non-Tesla
  charging stations + apply our own algorithm even at superchargers
  (cost/availability/user preference). Tesla's onboard reroute around
  superchargers would defeat the whole feature.
- Solution: persist the planned trip server-side and send stops to
  the car one at a time. When the car arrives at stop N, the
  backend cron (or user manual tap) advances to stop N+1.

Schema:
- stops_json: ordered JSON list of stops, each {lat, lng, address,
  kind, soc_target, station_id?}. First N-1 are charging stops; last
  is the final destination.
- current_segment: 0-based index of which stop is currently sent
  to the car. -1 means trip created but first stop not yet sent.
- status: "active" / "completed" / "cancelled".
- replan_count + last_replan_reason: diagnostic / surfaced in push.
- polyline_json: original route polyline for off-route detection
  (lateral distance from polyline > threshold → trigger replan).
- last_position_lat/lng/at: last known vehicle location while trip
  active (set by the cron monitor). Used by the "arrived at stop"
  detector + the off-route detector.

All TEXT/JSON for SQLite portability — Postgres would prefer JSONB
but the schema is small and we never query inside it.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0012_active_trip"
down_revision: Union[str, None] = "0011_vehicle_config_cache"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "active_trip",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False, index=True),
        sa.Column("vehicle_id", sa.String(64), nullable=False, index=True),
        sa.Column("stops_json", sa.Text(), nullable=False),
        sa.Column("polyline_json", sa.Text(), nullable=True),
        sa.Column("current_segment", sa.Integer(), nullable=False, default=-1),
        sa.Column("status", sa.String(16), nullable=False, default="active"),
        sa.Column("replan_count", sa.Integer(), nullable=False, default=0),
        sa.Column("last_replan_reason", sa.String(255), nullable=True),
        sa.Column("last_position_lat", sa.Float(), nullable=True),
        sa.Column("last_position_lng", sa.Float(), nullable=True),
        sa.Column("last_position_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )
    # One active trip per user — a second start_trip should replace
    # the existing one rather than running two in parallel.
    op.create_index(
        "ix_active_trip_user_status",
        "active_trip",
        ["user_id", "status"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_active_trip_user_status", table_name="active_trip")
    op.drop_table("active_trip")
