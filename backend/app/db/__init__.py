"""Database module."""

from app.db.session import get_db, engine, async_session
from app.db.models import Base, User, TeslaToken, Vehicle, RoutePlan


async def init_db():
    """Create all database tables."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


__all__ = [
    "get_db",
    "engine",
    "async_session",
    "Base",
    "User",
    "TeslaToken",
    "Vehicle",
    "RoutePlan",
    "init_db",
]
