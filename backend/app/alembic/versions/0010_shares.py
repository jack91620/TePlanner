"""shares: cross-platform share codes for automations + quick actions

Revision ID: 0010_shares
Revises: 0009_oauth_state
Create Date: 2026-05-12

Schema:
- code            PK, 6-char base32-friendly string (no 0/O/1/I/l).
                  ~1.07B combinations; INSERT retries on collision.
- share_type      'action' | 'rule' — drives import-side routing.
- payload_json    The shared item, with user-specific fields stripped
                  (no user_id, no vehicle_id, no source action_id —
                  importer mints fresh ids).
- owner_user_id   FK to users; nullable for system-shared content
                  later. Listed in /shares (owner-only).
- created_at      UTC timestamp.
- expires_at      UTC; 410 Gone past this point. 30 days default.
- revoked_at      Nullable. Set when owner explicitly revokes —
                  treated like expired but distinguished for logging.
- view_count      Incremented on each successful GET. For owner
                  analytics ("how many people imported my action").
- min_app_version Build number the share was authored against
                  (e.g. "39"). Importer sends its own version in a
                  header; server returns 412 Precondition Failed
                  when importer < this version (capability could
                  not exist yet).
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0010_shares"
down_revision: Union[str, None] = "0009_oauth_state"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "shares",
        sa.Column("code", sa.String(length=16), primary_key=True),
        sa.Column("share_type", sa.String(length=16), nullable=False),
        sa.Column("payload_json", sa.Text(), nullable=False),
        sa.Column(
            "owner_user_id",
            sa.Integer(),
            sa.ForeignKey("users.id"),
            nullable=True,
        ),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("expires_at", sa.DateTime(), nullable=False),
        sa.Column("revoked_at", sa.DateTime(), nullable=True),
        sa.Column(
            "view_count", sa.Integer(), nullable=False, server_default="0",
        ),
        sa.Column("min_app_version", sa.String(length=32), nullable=True),
    )
    op.create_index(
        "ix_shares_owner_user_id",
        "shares",
        ["owner_user_id", "created_at"],
        unique=False,
    )
    op.create_index(
        "ix_shares_expires_at",
        "shares",
        ["expires_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_shares_expires_at", table_name="shares")
    op.drop_index("ix_shares_owner_user_id", table_name="shares")
    op.drop_table("shares")
