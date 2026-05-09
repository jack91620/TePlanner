"""A.3 — scheduled_departure table

Revision ID: 0004_scheduled_departure
Revises: 0003_automation_rules_display_order
Create Date: 2026-05-09
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0004_scheduled_departure"
down_revision: Union[str, None] = "0003_automation_rules_display_order"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "scheduled_departure",
        sa.Column("id", sa.Integer(), autoincrement=True, primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("vehicle_id", sa.String(64), nullable=True),
        sa.Column("label", sa.String(64), nullable=True),
        sa.Column("departure_at_utc", sa.DateTime(), nullable=False),
        sa.Column("lead_minutes", sa.Integer(), nullable=False),
        sa.Column("target_charge_soc", sa.Integer(), nullable=True),
        sa.Column("enabled", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("updated_at", sa.DateTime(), nullable=True),
        sa.UniqueConstraint("user_id", name="uq_scheduled_departure_user_id"),
    )
    op.create_index(
        "ix_scheduled_departure_user_id", "scheduled_departure", ["user_id"]
    )


def downgrade() -> None:
    op.drop_index("ix_scheduled_departure_user_id", table_name="scheduled_departure")
    op.drop_table("scheduled_departure")
