"""A.5 — user_setting table

Revision ID: 0006_user_setting
Revises: 0005_charging_session
Create Date: 2026-05-09
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0006_user_setting"
down_revision: Union[str, None] = "0005_charging_session"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "user_setting",
        sa.Column("id", sa.Integer(), autoincrement=True, primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("key", sa.String(80), nullable=False),
        sa.Column("value_json", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("updated_at", sa.DateTime(), nullable=True),
        sa.UniqueConstraint("user_id", "key", name="uq_user_setting_user_key"),
    )
    op.create_index("ix_user_setting_user_id", "user_setting", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_user_setting_user_id", table_name="user_setting")
    op.drop_table("user_setting")
