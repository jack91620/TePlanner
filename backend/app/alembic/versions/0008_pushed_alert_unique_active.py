"""pushed_alerts: partial unique on active rows + automation_state unique

Revision ID: 0008_pushed_alert_unique_active
Revises: 0007_push_multiplex
Create Date: 2026-05-11

Why:
- 2026-05-11 incident: user 241 got 2 identical 车辆未锁 pushes
  136ms apart. Cause: cron tick + telemetry V record evaluated the
  same rule concurrently in separate DB sessions; both SELECTed,
  both saw "no recent PushedAlert in 15-min guard window", both
  INSERTed. Pre-commit isolation hid each session's INSERT from the
  other.
- Application-level INSERT...WHERE NOT EXISTS doesn't help across
  sessions either — each session reads its own snapshot.
- Fix: partial UNIQUE INDEX on (user_id, vehicle_id, kind) WHERE
  cleared_at IS NULL. The DB enforces "at most one active alert per
  kind". The second concurrent INSERT immediately raises
  IntegrityError; engine catches it as "race lost, no push".

Also pile on the long-pending AutomationState UNIQUE constraint that
caused the 2026-05-10 duplicate-row crash + lost telemetry off-events.
That same race produced duplicate :since rows; state_writer was
forced to self-heal at runtime. A real constraint prevents the
duplicates in the first place.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0008_pushed_alert_unique_active"
down_revision: Union[str, None] = "0007_push_multiplex"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Partial unique on PushedAlert. SQLite + Postgres both support
    # `WHERE` clause on CREATE UNIQUE INDEX. SQLAlchemy's op.create_index
    # supports `sqlite_where` for the partial predicate.
    op.create_index(
        "uq_pushed_alerts_active",
        "pushed_alerts",
        ["user_id", "vehicle_id", "kind"],
        unique=True,
        sqlite_where=sa.text("cleared_at IS NULL"),
        postgresql_where=sa.text("cleared_at IS NULL"),
    )
    # Full unique on AutomationState. No partial — every row is keyed.
    # The state_writer self-heal logic added 2026-05-10 stays as a belt
    # while the index migration is rolling; it's a noop once unique
    # holds.
    op.create_index(
        "uq_automation_state_key",
        "automation_state",
        ["user_id", "vehicle_id", "key"],
        unique=True,
    )


def downgrade() -> None:
    op.drop_index("uq_automation_state_key", table_name="automation_state")
    op.drop_index("uq_pushed_alerts_active", table_name="pushed_alerts")
