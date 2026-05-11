"""Tests for OAuth state DB persistence — replaces the old
module-level `_oauth_states` dict that didn't survive uvicorn fork.

Failure mode this prevents:
  - 2026-05-11: 5 consecutive login attempts all 400'd because
    authorize() saved state in worker A's dict and Tesla's callback
    landed on worker B. DB-backed state would have made all 5 pass.
"""

from datetime import datetime, timedelta

import pytest
from sqlalchemy import select

from app.api.v1.auth import (
    OAUTH_STATE_TTL_MINUTES,
    _pop_oauth_state,
    _save_oauth_state,
)
from app.db.models import OAuthState


@pytest.mark.asyncio
async def test_save_then_pop_round_trips(db_session):
    """Single-shot: save → pop returns the same code_verifier + user_id.
    Catches a refactor that breaks the most-common happy path."""
    await _save_oauth_state(
        db=db_session,
        state="csrf-token-1",
        code_verifier="verifier-1",
        user_id=42,
    )

    result = await _pop_oauth_state(db_session, "csrf-token-1")

    assert result is not None
    assert result["code_verifier"] == "verifier-1"
    assert result["user_id"] == 42


@pytest.mark.asyncio
async def test_pop_consumes_row_one_shot(db_session):
    """The state row is removed on first pop — replay returns None.
    Tesla shouldn't redirect twice; if it does we want a clean 400."""
    await _save_oauth_state(
        db=db_session,
        state="csrf-token-2",
        code_verifier="verifier-2",
        user_id=43,
    )

    first = await _pop_oauth_state(db_session, "csrf-token-2")
    second = await _pop_oauth_state(db_session, "csrf-token-2")

    assert first is not None
    assert second is None


@pytest.mark.asyncio
async def test_pop_unknown_state_returns_none(db_session):
    """Looking up a state that was never saved. Pre-2026-05-11 this
    was the failure path in the broken worker-fork case."""
    result = await _pop_oauth_state(db_session, "never-existed")
    assert result is None


@pytest.mark.asyncio
async def test_expired_state_is_rejected_and_cleaned(db_session):
    """A row older than TTL is treated as missing AND deleted, so the
    sweep happens implicitly each time we hit an expired token."""
    state = "expired-token"
    db_session.add(OAuthState(
        state=state,
        code_verifier="vexp",
        user_id=44,
        # 1 minute past TTL.
        created_at=datetime.utcnow() - timedelta(
            minutes=OAUTH_STATE_TTL_MINUTES + 1
        ),
    ))
    await db_session.commit()

    result = await _pop_oauth_state(db_session, state)

    assert result is None
    # The expired row should have been deleted too — otherwise expired
    # rows would pile up until we add a cron sweep.
    row = (await db_session.execute(
        select(OAuthState).where(OAuthState.state == state)
    )).scalar_one_or_none()
    assert row is None


@pytest.mark.asyncio
async def test_anonymous_state_user_id_nullable(db_session):
    """Backend creates an anon user when authorize() is called with
    no `user_id` — saved as a real int. But some flows (Mini Program
    historical) may pass None. Schema must accept it."""
    await _save_oauth_state(
        db=db_session,
        state="csrf-anon",
        code_verifier="v-anon",
        user_id=None,
    )

    result = await _pop_oauth_state(db_session, "csrf-anon")
    assert result is not None
    assert result["user_id"] is None
