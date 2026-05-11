"""oauth_state: persist Tesla OAuth CSRF state across uvicorn workers

Revision ID: 0009_oauth_state
Revises: 0008_pushed_alert_unique_active
Create Date: 2026-05-11

Why:
- 2026-05-11 incident: every Tesla OAuth login attempt 100% failed
  with "Invalid or expired authorization" when uvicorn ran with
  --workers 2. The OAuth state was kept in a module-level Python
  dict (`_oauth_states` in `backend/app/api/v1/auth.py`), which
  fork() copies per-worker. authorize() stored state on worker A;
  Tesla's redirect picked worker B; B's dict didn't have the state
  → 400 error → iOS "未能从登录回调中提取凭证".
- Quick fix was --workers 1 (no state sharing needed). This is the
  proper fix: a DB-backed pending-OAuth-state table that all
  workers can see.

Schema:
- state          PK, the URL-safe CSRF token Tesla echoes back
- code_verifier  PKCE verifier we keep server-side
- user_id        the requesting user (nullable; anon-pre-auth flows
                 pass None and dedup later)
- created_at     for TTL sweep (Tesla auth window is ~10 min)

The handler pops rows on first use, so accidental replay is a no-op.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0009_oauth_state"
down_revision: Union[str, None] = "0008_pushed_alert_unique_active"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "oauth_state",
        sa.Column("state", sa.String(length=128), primary_key=True),
        sa.Column("code_verifier", sa.String(length=128), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )
    op.create_index(
        "ix_oauth_state_created_at",
        "oauth_state",
        ["created_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_oauth_state_created_at", table_name="oauth_state")
    op.drop_table("oauth_state")
