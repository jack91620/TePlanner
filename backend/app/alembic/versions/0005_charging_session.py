"""A.4 — charging_session table

Revision ID: 0005_charging_session
Revises: 0004_scheduled_departure
Create Date: 2026-05-09
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0005_charging_session"
down_revision: Union[str, None] = "0004_scheduled_departure"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "charging_session",
        sa.Column("id", sa.Integer(), autoincrement=True, primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("vehicle_id", sa.String(64), nullable=True),
        sa.Column("client_session_id", sa.String(64), nullable=True),
        sa.Column("started_at", sa.DateTime(), nullable=False),
        sa.Column("ended_at", sa.DateTime(), nullable=True),
        sa.Column("start_soc", sa.Integer(), nullable=True),
        sa.Column("end_soc", sa.Integer(), nullable=True),
        sa.Column("start_range_km", sa.Float(), nullable=True),
        sa.Column("end_range_km", sa.Float(), nullable=True),
        sa.Column("energy_added_kwh", sa.Float(), nullable=True),
        sa.Column("location_name", sa.String(128), nullable=True),
        sa.Column("lat", sa.Float(), nullable=True),
        sa.Column("lng", sa.Float(), nullable=True),
        sa.Column("ended_as_complete", sa.Boolean(), nullable=True),
        sa.Column("source", sa.String(20), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("updated_at", sa.DateTime(), nullable=True),
        sa.UniqueConstraint("client_session_id", name="uq_charging_session_client_id"),
    )
    op.create_index("ix_charging_session_user_id", "charging_session", ["user_id"])
    op.create_index(
        "ix_charging_session_vehicle_id", "charging_session", ["vehicle_id"]
    )
    op.create_index(
        "ix_charging_session_client_session_id",
        "charging_session",
        ["client_session_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_charging_session_client_session_id", table_name="charging_session"
    )
    op.drop_index("ix_charging_session_vehicle_id", table_name="charging_session")
    op.drop_index("ix_charging_session_user_id", table_name="charging_session")
    op.drop_table("charging_session")
