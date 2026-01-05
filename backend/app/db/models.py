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
    openid = Column(String(64), unique=True, nullable=False, index=True)
    unionid = Column(String(64), unique=True, nullable=True)
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
