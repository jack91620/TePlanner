"""User model."""

from typing import Optional

from sqlalchemy import String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class User(Base, TimestampMixin):
    """User database model."""

    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    wechat_openid: Mapped[str] = mapped_column(
        String(64), unique=True, index=True
    )
    wechat_unionid: Mapped[Optional[str]] = mapped_column(
        String(64), unique=True, nullable=True
    )
    nickname: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    avatar_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # Tesla OAuth tokens (encrypted)
    tesla_access_token: Mapped[Optional[str]] = mapped_column(
        Text, nullable=True
    )
    tesla_refresh_token: Mapped[Optional[str]] = mapped_column(
        Text, nullable=True
    )

    # Relationships
    vehicles: Mapped[list["Vehicle"]] = relationship(
        "Vehicle", back_populates="user"
    )
    trips: Mapped[list["Trip"]] = relationship("Trip", back_populates="user")
