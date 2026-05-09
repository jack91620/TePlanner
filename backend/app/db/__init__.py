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
    run once), it's a no-op.

    BUG FIX (2026-05-10): the original implementation wrapped
    ``command.upgrade`` inside ``async with engine.begin()`` which held
    SQLite's write lock while alembic's env.py opened a *second*
    connection — that second connection then deadlocked waiting on
    the lock the outer transaction was holding. End-to-end symptom:
    every POST that wrote to the DB returned 500 because the lifespan
    startup never completed.

    Fix: alembic creates + manages its own engine via env.py
    ``run_migrations_online``. Just call ``command.upgrade`` directly
    in a worker thread (asyncio.to_thread) — no async transaction
    wrapper needed.
    """
    import asyncio

    from alembic import command
    from alembic.config import Config

    backend_root = Path(__file__).resolve().parents[2]
    cfg_path = backend_root / "alembic.ini"
    cfg = Config(str(cfg_path))
    cfg.set_main_option("script_location", str(backend_root / "app" / "alembic"))

    log.info("alembic upgrade head: starting")
    await asyncio.to_thread(command.upgrade, cfg, "head")
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
