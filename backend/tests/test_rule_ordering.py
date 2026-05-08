"""Phase 11.x — `_sort_rules_canonically` orders presets in their
ALL_PRESETS declaration order, then user-authored rules by created_at.

The bug this guards against: ``AutomationRule.id`` is a UUID string,
so ``.order_by(AutomationRule.id)`` was a lexicographic sort that
surfaced rules in different order across sessions and across users.
"""

from datetime import datetime, timedelta

import pytest

from app.db.models import AutomationRule, User
from app.services.automation.engine import _sort_rules_canonically
from app.services.automation.presets import ALL_PRESETS


@pytest.fixture
async def user(db_session):
    u = User(email="t@t.com", password_hash="x", is_active=True)
    db_session.add(u)
    await db_session.flush()
    return u


def _rule(**kwargs) -> AutomationRule:
    return AutomationRule(
        id=kwargs.get("id", "stub"),
        user_id=kwargs.get("user_id", 1),
        preset_id=kwargs.get("preset_id"),
        name=kwargs.get("name", ""),
        enabled=kwargs.get("enabled", True),
        spec_json=kwargs.get("spec_json", "{}"),
        version=kwargs.get("version", 1),
        created_at=kwargs.get("created_at", datetime.utcnow()),
    )


def test_presets_sort_in_declaration_order():
    # Seed in random ID order; after sort, presets should match
    # ALL_PRESETS declaration order regardless of UUIDs.
    rows = [
        _rule(id="zzz-id", preset_id=ALL_PRESETS[-1].preset_id),
        _rule(id="aaa-id", preset_id=ALL_PRESETS[0].preset_id),
        _rule(id="mmm-id", preset_id=ALL_PRESETS[2].preset_id),
    ]
    sorted_rows = _sort_rules_canonically(rows)
    preset_ids = [r.preset_id for r in sorted_rows]
    expected = [
        ALL_PRESETS[0].preset_id,
        ALL_PRESETS[2].preset_id,
        ALL_PRESETS[-1].preset_id,
    ]
    assert preset_ids == expected


def test_user_rules_after_presets_by_created_at():
    t0 = datetime(2026, 5, 1, 8, 0, 0)
    rows = [
        _rule(id="user-late", preset_id=None, created_at=t0 + timedelta(hours=2)),
        _rule(id="user-early", preset_id=None, created_at=t0),
        _rule(id="preset", preset_id=ALL_PRESETS[0].preset_id, created_at=t0 + timedelta(hours=5)),
    ]
    sorted_rows = _sort_rules_canonically(rows)
    assert sorted_rows[0].preset_id == ALL_PRESETS[0].preset_id
    assert sorted_rows[1].id == "user-early"
    assert sorted_rows[2].id == "user-late"


def test_unknown_preset_id_treated_like_user_rule():
    # If preset_id is set but not in ALL_PRESETS (e.g. retired
    # preset), the row should still surface — sorted with user rules.
    rows = [
        _rule(id="legacy", preset_id="retired-preset"),
        _rule(id="known", preset_id=ALL_PRESETS[0].preset_id),
    ]
    sorted_rows = _sort_rules_canonically(rows)
    assert sorted_rows[0].id == "known"


def test_idempotent_repeated_sort():
    rows = [
        _rule(id="a", preset_id=ALL_PRESETS[0].preset_id),
        _rule(id="b", preset_id=ALL_PRESETS[1].preset_id),
        _rule(id="c", preset_id=None, created_at=datetime(2026, 5, 1)),
    ]
    once = _sort_rules_canonically(rows)
    twice = _sort_rules_canonically(once)
    assert [r.id for r in once] == [r.id for r in twice]
