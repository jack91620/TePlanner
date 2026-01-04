"""Vehicle model."""

from typing import Optional

from sqlalchemy import ForeignKey, String, Float, Integer
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class Vehicle(Base, TimestampMixin):
    """Vehicle database model."""

    __tablename__ = "vehicles"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)

    # Tesla identifiers
    tesla_id: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    tesla_vehicle_id: Mapped[int] = mapped_column(Integer)
    vin: Mapped[str] = mapped_column(String(17), unique=True, index=True)

    # Vehicle info
    display_name: Mapped[Optional[str]] = mapped_column(
        String(64), nullable=True
    )
    car_type: Mapped[Optional[str]] = mapped_column(
        String(32), nullable=True
    )  # model3, modely, etc.

    # Battery specs (from vehicle_models.json or API)
    battery_capacity_kwh: Mapped[Optional[float]] = mapped_column(
        Float, nullable=True
    )
    efficiency_wh_per_km: Mapped[Optional[float]] = mapped_column(
        Float, nullable=True
    )

    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="vehicles")
