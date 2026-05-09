"""A.2 — automation_rules.display_order column

Revision ID: 0003_automation_rules_display_order
Revises: 0002_automation_snooze
Create Date: 2026-05-09
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0003_automation_rules_display_order"
down_revision: Union[str, None] = "0002_automation_snooze"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table("automation_rules") as batch:
        batch.add_column(sa.Column("display_order", sa.Integer(), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table("automation_rules") as batch:
        batch.drop_column("display_order")
