"""
Backend Tests for Multilingual Communication Bridge
Run: pytest tests/ -v
"""

import pytest
from httpx import AsyncClient, ASGITransport
import os

os.environ["NVIDIA_API_KEY"] = "test-key-for-testing"


@pytest.fixture
def anyio_backend():
    return "asyncio"


@pytest.fixture
async def client():
    from app.main import app
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.mark.anyio
async def test_root(client):
    response = await client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["version"] == "1.0.0"
    assert "features" in data


@pytest.mark.anyio
async def test_health(client):
    response = await client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "services" in data


@pytest.mark.anyio
async def test_get_languages(client):
    response = await client.get("/api/paste-reply/languages")
    assert response.status_code == 200
    data = response.json()
    assert "languages" in data
    # Should have all 10 Indian languages
    assert len(data["languages"]) >= 10


@pytest.mark.anyio
async def test_docs_accessible(client):
    response = await client.get("/docs")
    assert response.status_code == 200


@pytest.mark.anyio
async def test_openapi_schema(client):
    response = await client.get("/openapi.json")
    assert response.status_code == 200
    schema = response.json()
    assert schema["info"]["title"] == "Multilingual Communication Bridge API"
    # Check all 5 route groups are present
    paths = schema.get("paths", {})
    assert any("/api/voice" in p for p in paths)
    assert any("/api/translate" in p for p in paths)
    assert any("/api/paste-reply" in p for p in paths)
    assert any("/api/image" in p for p in paths)
    assert any("/api/conversation" in p for p in paths)
