"""Health check endpoint tests."""

import pytest


@pytest.mark.anyio
async def test_health_check(client):
    """Test health check endpoint returns OK."""
    response = await client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "version" in data
