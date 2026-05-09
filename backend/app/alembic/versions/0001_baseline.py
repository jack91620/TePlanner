"""baseline — current schema produced by Base.metadata.create_all

Reflects the live schema as of 2026-05-09 when Alembic was introduced.
Existing prod DBs are bootstrapped via `alembic stamp head` (no upgrade
runs); fresh dev DBs get the full schema by running `alembic upgrade
head` from empty.

Revision ID: 0001_baseline
Revises:
Create Date: 2026-05-09
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0001_baseline"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), autoincrement=True, primary_key=True),
        sa.Column("openid", sa.String(64), nullable=True),
        sa.Column("unionid", sa.String(64), nullable=True),
        sa.Column("email", sa.String(128), nullable=True),
        sa.Column("password_hash", sa.String(256), nullable=True),
        sa.Column("nickname", sa.String(64), nullable=True),
        sa.Column("avatar_url", sa.String(512), nullable=True),
        sa.Column("phone", sa.String(20), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("updated_at", sa.DateTime(), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=True),
        sa.UniqueConstraint("openid"),
        sa.UniqueConstraint("unionid"),
        sa.UniqueConstraint("email"),
    )
    op.create_index("ix_users_openid", "users", ["openid"])
    op.create_index("ix_users_email", "users", ["email"])

    op.create_table(
        "tesla_tokens",
        sa.Column("id", sa.Integer(), autoincrement=True, primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("access_token", sa.Text(), nullable=False),
        sa.Column("refresh_token", sa.Text(), nullable=False),
        sa.Column("expires_at", sa.DateTime(), nullable=False),
        sa.Column("token_type", sa.String(20), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("updated_at", sa.DateTime(), nullable=True),
    )

    op.create_table(
        "vehicles",
        sa.Column("id", sa.Integer(), autoincrement=True, primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("vehicle_id", sa.String(64), nullable=False),
        sa.Column("vin", sa.String(17), nullable=True),
        sa.Column("display_name", sa.String(64), nullable=True),
        sa.Column("model", sa.String(32), nullable=True),
        sa.Column("color", sa.String(32), nullable=True),
        sa.Column("battery_capacity_kwh", sa.Float(), nullable=True),
        sa.Column("is_primary", sa.Boolean(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("updated_at", sa.DateTime(), nullable=True),
    )
    op.create_index("ix_vehicles_vehicle_id", "vehicles", ["vehicle_id"])

    op.create_table(
        "automation_rules",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("preset_id", sa.String(64), nullable=True),
        sa.Column("name", sa.String(128), nullable=False),
        sa.Column("enabled", sa.Boolean(), nullable=False),
        sa.Column("spec_json", sa.Text(), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("updated_at", sa.DateTime(), nullable=True),
    )
    op.create_index("ix_automation_rules_user_id", "automation_rules", ["user_id"])

    op.create_table(
        "automation_state",
        sa.Column("id", sa.Integer(), autoincrement=True, primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("vehicle_id", sa.String(64), nullable=False),
        sa.Column("key", sa.String(80), nullable=False),
        sa.Column("value", sa.String(64), nullable=True),
        sa.Column("updated_at", sa.DateTime(), nullable=True),
    )
    op.create_index("ix_automation_state_user_id", "automation_state", ["user_id"])
    op.create_index("ix_automation_state_vehicle_id", "automation_state", ["vehicle_id"])

    op.create_table(
        "pushed_alerts",
        sa.Column("id", sa.Integer(), autoincrement=True, primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("vehicle_id", sa.String(64), nullable=False),
        sa.Column("kind", sa.String(40), nullable=False),
        sa.Column("pushed_at", sa.DateTime(), nullable=True),
        sa.Column("cleared_at", sa.DateTime(), nullable=True),
    )
    op.create_index("ix_pushed_alerts_user_id", "pushed_alerts", ["user_id"])
    op.create_index("ix_pushed_alerts_vehicle_id", "pushed_alerts", ["vehicle_id"])

    op.create_table(
        "device_tokens",
        sa.Column("id", sa.Integer(), autoincrement=True, primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("token", sa.String(200), nullable=False),
        sa.Column("platform", sa.String(20), nullable=True),
        sa.Column("bundle_id", sa.String(128), nullable=True),
        sa.Column("last_seen_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
    )
    op.create_index("ix_device_tokens_user_id", "device_tokens", ["user_id"])
    op.create_index("ix_device_tokens_token", "device_tokens", ["token"])

    op.create_table(
        "pending_wait",
        sa.Column("id", sa.Integer(), autoincrement=True, primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("vehicle_id", sa.String(64), nullable=False),
        sa.Column("rule_id", sa.String(64), nullable=True),
        sa.Column("predicate_json", sa.Text(), nullable=False),
        sa.Column("then_action_json", sa.Text(), nullable=False),
        sa.Column("deadline_at", sa.DateTime(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("resolved_at", sa.DateTime(), nullable=True),
        sa.Column("timed_out_at", sa.DateTime(), nullable=True),
    )
    op.create_index("ix_pending_wait_user_id", "pending_wait", ["user_id"])
    op.create_index("ix_pending_wait_vehicle_id", "pending_wait", ["vehicle_id"])
    op.create_index("ix_pending_wait_rule_id", "pending_wait", ["rule_id"])

    op.create_table(
        "command_queue",
        sa.Column("id", sa.Integer(), autoincrement=True, primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("vehicle_id", sa.String(64), nullable=False),
        sa.Column("capability", sa.String(80), nullable=False),
        sa.Column("params_json", sa.Text(), nullable=False),
        sa.Column("dispatch_policy", sa.String(32), nullable=False),
        sa.Column("ttl_seconds", sa.Integer(), nullable=False),
        sa.Column("queued_at", sa.DateTime(), nullable=False),
        sa.Column("sent_at", sa.DateTime(), nullable=True),
        sa.Column("dropped_at", sa.DateTime(), nullable=True),
        sa.Column("error", sa.String(256), nullable=True),
    )
    op.create_index("ix_command_queue_user_id", "command_queue", ["user_id"])
    op.create_index("ix_command_queue_vehicle_id", "command_queue", ["vehicle_id"])

    op.create_table(
        "command_pending",
        sa.Column("id", sa.Integer(), autoincrement=True, primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("vehicle_id", sa.String(64), nullable=False),
        sa.Column("capability", sa.String(80), nullable=False),
        sa.Column("expected_state_json", sa.Text(), nullable=False),
        sa.Column("dispatched_at", sa.DateTime(), nullable=False),
        sa.Column("confirmed_at", sa.DateTime(), nullable=True),
        sa.Column("timed_out_at", sa.DateTime(), nullable=True),
    )
    op.create_index("ix_command_pending_user_id", "command_pending", ["user_id"])
    op.create_index("ix_command_pending_vehicle_id", "command_pending", ["vehicle_id"])

    op.create_table(
        "route_plans",
        sa.Column("id", sa.Integer(), autoincrement=True, primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("vehicle_id", sa.Integer(), sa.ForeignKey("vehicles.id"), nullable=True),
        sa.Column("origin_lat", sa.Float(), nullable=False),
        sa.Column("origin_lng", sa.Float(), nullable=False),
        sa.Column("origin_address", sa.String(256), nullable=True),
        sa.Column("dest_lat", sa.Float(), nullable=False),
        sa.Column("dest_lng", sa.Float(), nullable=False),
        sa.Column("dest_address", sa.String(256), nullable=True),
        sa.Column("total_distance_km", sa.Float(), nullable=True),
        sa.Column("total_duration_minutes", sa.Integer(), nullable=True),
        sa.Column("charging_stops_json", sa.Text(), nullable=True),
        sa.Column("polyline_json", sa.Text(), nullable=True),
        sa.Column("status", sa.String(20), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("updated_at", sa.DateTime(), nullable=True),
    )


def downgrade() -> None:
    op.drop_table("route_plans")
    op.drop_index("ix_command_pending_vehicle_id", table_name="command_pending")
    op.drop_index("ix_command_pending_user_id", table_name="command_pending")
    op.drop_table("command_pending")
    op.drop_index("ix_command_queue_vehicle_id", table_name="command_queue")
    op.drop_index("ix_command_queue_user_id", table_name="command_queue")
    op.drop_table("command_queue")
    op.drop_index("ix_pending_wait_rule_id", table_name="pending_wait")
    op.drop_index("ix_pending_wait_vehicle_id", table_name="pending_wait")
    op.drop_index("ix_pending_wait_user_id", table_name="pending_wait")
    op.drop_table("pending_wait")
    op.drop_index("ix_device_tokens_token", table_name="device_tokens")
    op.drop_index("ix_device_tokens_user_id", table_name="device_tokens")
    op.drop_table("device_tokens")
    op.drop_index("ix_pushed_alerts_vehicle_id", table_name="pushed_alerts")
    op.drop_index("ix_pushed_alerts_user_id", table_name="pushed_alerts")
    op.drop_table("pushed_alerts")
    op.drop_index("ix_automation_state_vehicle_id", table_name="automation_state")
    op.drop_index("ix_automation_state_user_id", table_name="automation_state")
    op.drop_table("automation_state")
    op.drop_index("ix_automation_rules_user_id", table_name="automation_rules")
    op.drop_table("automation_rules")
    op.drop_index("ix_vehicles_vehicle_id", table_name="vehicles")
    op.drop_table("vehicles")
    op.drop_table("tesla_tokens")
    op.drop_index("ix_users_email", table_name="users")
    op.drop_index("ix_users_openid", table_name="users")
    op.drop_table("users")
