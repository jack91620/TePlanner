"""LLM /configure endpoint — pin the parse + validate flow, with
the LLM client mocked to return canned responses. No actual network
or LLM provider call happens.
"""

from unittest.mock import AsyncMock, patch

import pytest

from app.services.llm.base import LLMConfigureResult, LLMError


@pytest.mark.asyncio
async def test_configure_quick_action_happy_path(client, db_session, monkeypatch):
    """Canned LLM picks 'create_quick_action' with a real capability —
    response surfaces it with validation_errors=None so iOS shows
    'confirm to save'."""
    from app.services.llm.deepseek import DeepSeekClient

    async def fake_complete_json(self, *, system, user, response_schema, max_tokens=1024):
        return {
            "intent": "create_quick_action",
            "summary": "一键锁车",
            "name": "锁车",
            "quick_action": {
                "name": "锁车",
                "icon": "lock.fill",
                "tint": "blue",
                "capability": "tesla.security.door_lock",
                "params": {},
            },
        }

    user_id = await _make_test_user(db_session)
    monkeypatch.setattr(DeepSeekClient, "complete_json", fake_complete_json)
    from app.config import settings
    monkeypatch.setattr(settings, "DEEPSEEK_API_KEY", "test-key")

    headers = await _auth_headers(user_id)
    resp = await client.post(
        "/api/v1/llm/configure",
        json={"message": "帮我做个一键锁车", "target": "quick_action"},
        headers=headers,
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["intent"] == "create_quick_action"
    assert body["quick_action"]["capability"] == "tesla.security.door_lock"
    assert body["validation_errors"] is None


@pytest.mark.asyncio
async def test_configure_hallucinated_capability_surfaces_error(
    client, db_session, monkeypatch,
):
    """LLM returns a capability id that isn't registered. We must
    surface validation_errors so iOS won't show 'confirm to save'."""
    from app.services.llm.deepseek import DeepSeekClient

    async def fake(self, *, system, user, response_schema, max_tokens=1024):
        return {
            "intent": "create_quick_action",
            "summary": "暖座椅",
            "quick_action": {
                "name": "暖座椅",
                "capability": "tesla.fake.heat_seat",  # hallucinated
                "params": {},
            },
        }

    user_id = await _make_test_user(db_session)
    monkeypatch.setattr(DeepSeekClient, "complete_json", fake)
    from app.config import settings
    monkeypatch.setattr(settings, "DEEPSEEK_API_KEY", "test-key")

    headers = await _auth_headers(user_id)
    resp = await client.post(
        "/api/v1/llm/configure",
        json={"message": "暖座椅"},
        headers=headers,
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["validation_errors"] is not None
    assert any("heat_seat" in e for e in body["validation_errors"])


@pytest.mark.asyncio
async def test_configure_ask_clarification_no_validation(
    client, db_session, monkeypatch,
):
    """LLM punted with a clarification question — no spec to validate."""
    from app.services.llm.deepseek import DeepSeekClient

    async def fake(self, *, system, user, response_schema, max_tokens=1024):
        return {
            "intent": "ask_clarification",
            "summary": "需要更多信息",
            "clarification": "去哪个机场？首都还是大兴？",
        }

    user_id = await _make_test_user(db_session)
    monkeypatch.setattr(DeepSeekClient, "complete_json", fake)
    from app.config import settings
    monkeypatch.setattr(settings, "DEEPSEEK_API_KEY", "test-key")

    headers = await _auth_headers(user_id)
    resp = await client.post(
        "/api/v1/llm/configure",
        json={"message": "提前 30 分钟出发去机场"},
        headers=headers,
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["intent"] == "ask_clarification"
    assert "机场" in body["clarification"]
    assert body["validation_errors"] is None


@pytest.mark.asyncio
async def test_configure_no_llm_key_returns_503(client, db_session, monkeypatch):
    """Server default unconfigured + no BYOK → 503 so iOS routes
    to the LLM settings page."""
    user_id = await _make_test_user(db_session)
    monkeypatch.setenv("DEEPSEEK_API_KEY", "")
    # Also re-import settings so the env-var change takes effect for
    # this single test — simpler than patching the singleton.
    from app.config import settings
    monkeypatch.setattr(settings, "DEEPSEEK_API_KEY", "")

    headers = await _auth_headers(user_id)
    resp = await client.post(
        "/api/v1/llm/configure",
        json={"message": "锁车"},
        headers=headers,
    )
    assert resp.status_code == 503


# ---- helpers ------------------------------------------------------


async def _make_test_user(db_session) -> int:
    from app.db.models import User
    user = User(email="llm@test.local", is_active=True, password_hash="x")
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user.id


async def _auth_headers(user_id: int) -> dict:
    from datetime import timedelta
    from app.core.security import create_access_token
    token = create_access_token(
        data={"sub": str(user_id)},
        expires_delta=timedelta(minutes=10),
    )
    return {"Authorization": f"Bearer {token}"}
