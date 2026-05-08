"""Pytest configuration and fixtures."""

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker

from app.main import app
from app.models.base import Base as ModelsBase
from app.db.models import Base as DbModelsBase
from app.db.session import get_db


# Test database URL (SQLite for testing)
TEST_DATABASE_URL = "sqlite+aiosqlite:///./test.db"

# Create test engine
test_engine = create_async_engine(TEST_DATABASE_URL, echo=False)
test_async_session = async_sessionmaker(
    test_engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


@pytest.fixture(scope="session")
def anyio_backend():
    """Use asyncio for async tests."""
    return "asyncio"


@pytest.fixture(scope="function")
async def db_session():
    """Create a fresh database session for each test."""
    async with test_engine.begin() as conn:
        # The codebase has two declarative bases — `app.models.base.Base`
        # (used by the route-planning tests) and `app.db.models.Base`
        # (User, Vehicle, AutomationState, etc — used by Phase-4 telemetry
        # and polling state). Both define a `users` table with different
        # column sets. Create the richer (DbModelsBase) one first; when
        # ModelsBase.create_all runs it sees the tables already exist
        # and skips, leaving the superset schema in place.
        await conn.run_sync(DbModelsBase.metadata.create_all)
        await conn.run_sync(ModelsBase.metadata.create_all)

    async with test_async_session() as session:
        yield session

    async with test_engine.begin() as conn:
        await conn.run_sync(DbModelsBase.metadata.drop_all)
        await conn.run_sync(ModelsBase.metadata.drop_all)


@pytest.fixture(scope="function")
async def client(db_session):
    """Create test client with overridden dependencies."""

    async def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db

    async with AsyncClient(app=app, base_url="http://test") as ac:
        yield ac

    app.dependency_overrides.clear()
