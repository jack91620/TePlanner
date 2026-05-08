"""Database models."""

from datetime import datetime
from typing import Optional

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
)
from sqlalchemy.ext.asyncio import AsyncAttrs
from sqlalchemy.orm import DeclarativeBase, relationship


class Base(AsyncAttrs, DeclarativeBase):
    """Base class for all models."""

    pass


class User(Base):
    """User model."""

    __tablename__ = "users"

    id = Column(Integer, primary_key=True, autoincrement=True)
    # WeChat login fields
    openid = Column(String(64), unique=True, nullable=True, index=True)
    unionid = Column(String(64), unique=True, nullable=True)
    # Email/password login fields (for Android)
    email = Column(String(128), unique=True, nullable=True, index=True)
    password_hash = Column(String(256), nullable=True)
    # Common fields
    nickname = Column(String(64), nullable=True)
    avatar_url = Column(String(512), nullable=True)
    phone = Column(String(20), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    is_active = Column(Boolean, default=True)

    # Relationships
    tesla_tokens = relationship("TeslaToken", back_populates="user", lazy="selectin")
    vehicles = relationship("Vehicle", back_populates="user", lazy="selectin")


class TeslaToken(Base):
    """Tesla OAuth tokens."""

    __tablename__ = "tesla_tokens"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    access_token = Column(Text, nullable=False)  # Encrypted
    refresh_token = Column(Text, nullable=False)  # Encrypted
    expires_at = Column(DateTime, nullable=False)
    token_type = Column(String(20), default="Bearer")
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    user = relationship("User", back_populates="tesla_tokens")


class Vehicle(Base):
    """Tesla vehicle linked to user."""

    __tablename__ = "vehicles"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    vehicle_id = Column(String(64), nullable=False, index=True)  # Tesla vehicle ID
    vin = Column(String(17), nullable=True)
    display_name = Column(String(64), nullable=True)
    model = Column(String(32), nullable=True)  # e.g., "Model Y", "Model 3"
    color = Column(String(32), nullable=True)
    battery_capacity_kwh = Column(Float, nullable=True)
    is_primary = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    user = relationship("User", back_populates="vehicles")


class AutomationRule(Base):
    """Declarative automation rule — Phase 10.2 replaces the hardcoded
    Python rule classes. `spec_json` is the rule body (trigger /
    conditions / actions); `preset_id` is non-null for the 4 seeded
    presets (camp / sentry / cabin / charge complete). User-authored
    rules added in Phase 10.3 have `preset_id = NULL`.
    """

    __tablename__ = "automation_rules"

    id = Column(String(36), primary_key=True)  # uuid
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    preset_id = Column(String(64), nullable=True)
    name = Column(String(128), nullable=False)
    enabled = Column(Boolean, default=True, nullable=False)
    spec_json = Column(Text, nullable=False)
    version = Column(Integer, default=1, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class AutomationState(Base):
    """Per-rule scratchpad keyed by (user_id, vehicle_id, key). Used by
    automation rules to remember "first time I observed X on" timestamps
    across polling ticks. Stored as ISO date strings for portability;
    rules treat None as absent. Mirrors iOS InMemoryAutomationStateMemory
    but persisted so engine state survives backend restarts.
    """

    __tablename__ = "automation_state"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    vehicle_id = Column(String(64), nullable=False, index=True)
    key = Column(String(80), nullable=False)
    value = Column(String(64), nullable=True)  # ISO 8601 datetime string
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class PushedAlert(Base):
    """De-duplication ledger: tracks which (user, vehicle, kind) alerts
    have been pushed at critical severity, so the polling tick only
    fires APNs on the not-critical → critical transition (matching the
    iOS LocalNotificationScheduler.applyAlerts behaviour).
    """

    __tablename__ = "pushed_alerts"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    vehicle_id = Column(String(64), nullable=False, index=True)
    kind = Column(String(40), nullable=False)
    pushed_at = Column(DateTime, default=datetime.utcnow)
    cleared_at = Column(DateTime, nullable=True)


class DeviceToken(Base):
    """APNs device push token registered by an iOS device.

    One user can have multiple devices (iPhone + iPad). On each app
    launch the iOS client posts its current token; we upsert by
    (user_id, token) so reinstalls / token rotations get a fresh row
    while keeping the user's other active devices intact.
    """

    __tablename__ = "device_tokens"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    token = Column(String(200), nullable=False, index=True)
    platform = Column(String(20), default="ios")
    bundle_id = Column(String(128), nullable=True)
    last_seen_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    created_at = Column(DateTime, default=datetime.utcnow)


class CommandPending(Base):
    """Phase 9 — closed-loop VCP confirmation ledger.

    Every successful capability dispatch with observable telemetry
    writes one row here. The Telemetry-driven pending_resolver checks
    on each engine tick whether the snapshot now matches the
    capability's ``expected_state``; on match it stamps ``confirmed_at``,
    on timeout it stamps ``timed_out_at``. iOS polls
    ``/api/v1/commands/pending`` to flip the action button from
    "执行中…" → "已关闭" / "超时".

    Capabilities without observable telemetry (preheat, navigation,
    charge_limit until we add a tel:* entity for it) skip writing a
    row entirely — the iOS UI confirms on HTTP 2xx alone.
    """

    __tablename__ = "command_pending"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    vehicle_id = Column(String(64), nullable=False, index=True)  # VIN
    capability = Column(String(80), nullable=False)
    # JSON: {"vehicle.climate.keeper_mode": 0}.  pending_resolver loops
    # this dict and matches each entry against the snapshot.
    expected_state_json = Column(Text, nullable=False)
    dispatched_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    confirmed_at = Column(DateTime, nullable=True)
    timed_out_at = Column(DateTime, nullable=True)


class RoutePlan(Base):
    """Saved route plans."""

    __tablename__ = "route_plans"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    vehicle_id = Column(Integer, ForeignKey("vehicles.id"), nullable=True)

    # Route details
    origin_lat = Column(Float, nullable=False)
    origin_lng = Column(Float, nullable=False)
    origin_address = Column(String(256), nullable=True)
    dest_lat = Column(Float, nullable=False)
    dest_lng = Column(Float, nullable=False)
    dest_address = Column(String(256), nullable=True)

    # Results
    total_distance_km = Column(Float, nullable=True)
    total_duration_minutes = Column(Integer, nullable=True)
    charging_stops_json = Column(Text, nullable=True)  # JSON string
    polyline_json = Column(Text, nullable=True)  # JSON string

    # Status
    status = Column(String(20), default="pending")  # pending, completed, sent_to_car
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
