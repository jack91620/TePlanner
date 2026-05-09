"""Database module."""

import logging
from pathlib import Path

from app.db.session import get_db, engine, async_session
from app.db.models import Base, User, TeslaToken, Vehicle, RoutePlan

log = logging.getLogger(__name__)


async def init_db():
    """Bring the schema up to alembic head.

    On a fresh DB this runs the baseline migration (which creates every
    table). On an already-bootstrapped DB (`alembic stamp head` has been
    run once), it's a no-op. The previous implementation called
    Base.metadata.create_all which silently skipped any column /
    constraint changes — that footgun is now gone.
    """
    from alembic import command
    from alembic.config import Config

    backend_root = Path(__file__).resolve().parents[2]
    cfg_path = backend_root / "alembic.ini"
    cfg = Config(str(cfg_path))
    cfg.set_main_option("script_location", str(backend_root / "app" / "alembic"))

    def _run(_):
        command.upgrade(cfg, "head")

    log.info("alembic upgrade head: starting")
    async with engine.begin() as conn:
        await conn.run_sync(_run)
    log.info("alembic upgrade head: done")


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
