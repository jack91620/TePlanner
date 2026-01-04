"""Trip model."""

from typing import Optional

from sqlalchemy import ForeignKey, String, Float, Integer, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class Trip(Base, TimestampMixin):
    """Trip/route planning record."""

    __tablename__ = "trips"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    vehicle_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("vehicles.id"), nullable=True
    )

    # Route info
    origin_name: Mapped[str] = mapped_column(String(128))
    origin_lat: Mapped[float] = mapped_column(Float)
    origin_lng: Mapped[float] = mapped_column(Float)

    destination_name: Mapped[str] = mapped_column(String(128))
    destination_lat: Mapped[float] = mapped_column(Float)
    destination_lng: Mapped[float] = mapped_column(Float)

    # Planning parameters
    initial_soc: Mapped[int] = mapped_column(Integer)  # 0-100
    target_arrival_soc: Mapped[int] = mapped_column(Integer, default=20)

    # Results (stored as JSON)
    route_data: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    charging_stops: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)

    # Summary
    total_distance_km: Mapped[Optional[float]] = mapped_column(
        Float, nullable=True
    )
    total_duration_minutes: Mapped[Optional[int]] = mapped_column(
        Integer, nullable=True
    )
    total_charging_time_minutes: Mapped[Optional[int]] = mapped_column(
        Integer, nullable=True
    )

    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="trips")
