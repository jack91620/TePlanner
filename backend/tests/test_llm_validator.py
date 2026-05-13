"""Pin the LLM-output sanity checks. Real LLM calls are NOT made
here — these tests only exercise the validator's rules against
fabricated specs to catch the hallucination patterns we've already
seen in prompt-tuning (made-up capability ids, missing trigger).
"""

from app.services.llm import validator


def test_valid_quick_action_passes():
    payload = {
        "name": "锁车",
        "icon": "lock.fill",
        "tint": "blue",
        "capability": "tesla.security.door_lock",
        "params": {},
    }
    assert validator.validate_quick_action(payload) == []


def test_quick_action_unknown_capability_rejected():
    payload = {
        "name": "暖座椅",
        "capability": "tesla.comfort.set_heat",  # hallucinated; doesn't exist
        "params": {},
    }
    errors = validator.validate_quick_action(payload)
    assert any("set_heat" in e for e in errors)


def test_quick_action_long_name_rejected():
    payload = {
        "name": "这是一个非常非常长的快捷操作名字超过十二字了",
        "capability": "tesla.security.door_lock",
    }
    errors = validator.validate_quick_action(payload)
    assert any("过长" in e for e in errors)


def test_quick_action_missing_name_rejected():
    payload = {
        "capability": "tesla.security.door_lock",
        "params": {},
    }
    errors = validator.validate_quick_action(payload)
    assert any("name" in e for e in errors)


def test_valid_automation_passes():
    spec = {
        "trigger": {
            "type": "state_duration",
            "entity": "vehicle.climate.keeper_mode",
            "equals": 3,
            "for_minutes": 120,
        },
        "actions": [
            {"capability": "tesla.climate.set_keeper_mode", "params": {"mode": 0}},
        ],
    }
    assert validator.validate_automation_spec(spec) == []


def test_automation_missing_trigger_rejected():
    spec = {"actions": [{"capability": "tesla.climate.preheat", "params": {}}]}
    errors = validator.validate_automation_spec(spec)
    assert any("trigger" in e for e in errors)


def test_automation_unknown_trigger_type_rejected():
    spec = {
        "trigger": {"type": "magic"},
        "actions": [{"capability": "tesla.climate.preheat", "params": {}}],
    }
    errors = validator.validate_automation_spec(spec)
    assert any("trigger.type" in e for e in errors)


def test_automation_empty_actions_rejected():
    spec = {
        "trigger": {"type": "cron", "cron": "0 7 * * 1-5"},
        "actions": [],
    }
    errors = validator.validate_automation_spec(spec)
    assert any("actions" in e for e in errors)


def test_automation_action_with_unknown_cap_rejected():
    spec = {
        "trigger": {"type": "cron", "cron": "0 7 * * 1-5"},
        "actions": [
            {"capability": "tesla.security.door_lock", "params": {}},
            {"capability": "tesla.fake.does_not_exist", "params": {}},
        ],
    }
    errors = validator.validate_automation_spec(spec)
    assert any("does_not_exist" in e for e in errors)
    # Only the bad one should error — door_lock is valid.
    assert all("door_lock" not in e for e in errors)


def test_known_capability_ids_includes_tesla_lock():
    ids = validator.known_capability_ids()
    assert "tesla.security.door_lock" in ids
    assert "tesla.climate.preheat" in ids
    # No hallucinated ids in the registry.
    assert "tesla.fake.anything" not in ids
