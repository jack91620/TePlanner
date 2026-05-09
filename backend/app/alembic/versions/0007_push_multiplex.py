"""E — push multiplex: device_tokens.provider_token + back-fill platform

Revision ID: 0007_push_multiplex
Revises: 0006_user_setting
Create Date: 2026-05-09
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0007_push_multiplex"
down_revision: Union[str, None] = "0006_user_setting"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table("device_tokens") as batch:
        batch.add_column(sa.Column("provider_token", sa.String(255), nullable=True))
    # Back-fill the legacy "ios" platform value to "apns". From now on
    # the dispatcher routes by platform; "ios" was meaningful only when
    # APNs was the sole channel.
    op.execute(
        "UPDATE device_tokens SET platform = 'apns' WHERE platform = 'ios'"
    )


def downgrade() -> None:
    op.execute(
        "UPDATE device_tokens SET platform = 'ios' WHERE platform = 'apns'"
    )
    with op.batch_alter_table("device_tokens") as batch:
        batch.drop_column("provider_token")
