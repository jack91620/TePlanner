"""A.1 — automation_snooze table

Revision ID: 0002_automation_snooze
Revises: 0001_baseline
Create Date: 2026-05-09
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0002_automation_snooze"
down_revision: Union[str, None] = "0001_baseline"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "automation_snooze",
        sa.Column("id", sa.Integer(), autoincrement=True, primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("rule_id", sa.String(36), nullable=False),
        sa.Column("snoozed_until_utc", sa.DateTime(), nullable=False),
        sa.Column("reason", sa.String(128), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.UniqueConstraint("rule_id", name="uq_automation_snooze_rule_id"),
    )
    op.create_index("ix_automation_snooze_user_id", "automation_snooze", ["user_id"])
    op.create_index("ix_automation_snooze_rule_id", "automation_snooze", ["rule_id"])


def downgrade() -> None:
    op.drop_index("ix_automation_snooze_rule_id", table_name="automation_snooze")
    op.drop_index("ix_automation_snooze_user_id", table_name="automation_snooze")
    op.drop_table("automation_snooze")
