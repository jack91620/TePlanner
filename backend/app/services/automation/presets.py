"""Preset rule definitions — the 4 hardcoded reminders shipped today.

Each preset is the body that goes into `automation_rules.spec_json`
plus a stable `preset_id` and a user-facing `name`. When a user is
seen for the first time by the polling loop we seed these into their
`automation_rules` rows; subsequent ticks just load them along with
any user-authored rules.

Wording / thresholds match the existing per-class rules byte-for-byte
to keep tests green and push notifications stable across the
migration.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class PresetDefinition:
    preset_id: str
    name: str
    spec: dict


CAMP_MODE = PresetDefinition(
    preset_id="camp_mode_overstay",
    name="露营模式超时提醒",
    spec={
        "kind": "campMode",
        "trigger": {
            "type": "state_duration",
            "entity": "vehicle.climate.keeper_mode",
            "equals": 3,
            "for_minutes": 120,
            "state_key": "campMode:startedAt",
        },
        "actions_below": [
            {
                "type": "notify",
                "title": "露营模式开启中",
                "body": "已开启 {duration_human}",
                "severity": "info",
            }
        ],
        "actions_above": [
            {
                "type": "notify_and_offer",
                "title": "露营模式开启中",
                "body": "已开启 {duration_human}，电池正在缓慢消耗",
                "severity": "critical",
                "primary_action_label": "关闭",
                "capability": "tesla.climate.set_keeper_mode",
                "params": {"mode": 0},
            }
        ],
    },
)

SENTRY_MODE = PresetDefinition(
    preset_id="sentry_mode_overstay",
    name="哨兵模式长时间开启",
    spec={
        "kind": "sentryMode",
        "trigger": {
            "type": "state_duration",
            "entity": "vehicle.sentry_mode_on",
            "equals": True,
            "for_minutes": 1440,
            "state_key": "sentryMode:startedAt",
        },
        "actions_below": [
            {
                "type": "notify",
                "title": "哨兵模式开启中",
                "body": "已开启 {duration_human}",
                "severity": "info",
            }
        ],
        "actions_above": [
            {
                "type": "notify_and_offer",
                "title": "哨兵模式开启中",
                "body": "已开启 {duration_human}，正在持续耗电",
                "severity": "critical",
                "primary_action_label": "关闭哨兵",
                "capability": "tesla.security.set_sentry",
                "params": {"on": False},
            }
        ],
    },
)

CABIN_OVERHEAT = PresetDefinition(
    preset_id="cabin_overheat_alert",
    name="座舱过热保护",
    spec={
        "kind": "cabinOverheat",
        "trigger": {
            "type": "state_duration",
            "entity": "vehicle.cabin_overheat_protection_on",
            "equals": True,
            "for_minutes": 60,
            "state_key": "cabinOverheat:startedAt",
        },
        "actions_below": [],
        "actions_above": [
            {
                "type": "notify",
                "title": "座舱过热保护已启动",
                "body": "已运行 {duration_human}，车辆正在自动通风/降温",
                "severity": "info",
            }
        ],
    },
)

CHARGE_COMPLETE = PresetDefinition(
    preset_id="charge_complete_reminder",
    name="充电完成提醒",
    spec={
        "kind": "chargeComplete",
        "trigger": {
            "type": "state_transition",
            "entity": "vehicle.charging.state",
            "to": "Complete",
            "first_seen_key": "chargeComplete:firstSeenAt",
            "dismissed_key": "chargeComplete:dismissedAt",
            "reset_when_not_to": True,
        },
        "actions": [
            {
                "type": "notify_and_offer",
                "title": "充电已完成",
                "body": "电量 {battery_level}%，可拔枪了",
                "severity": "critical",
                "primary_action_label": "我知道了",
                "capability": "automation.dismiss",
            }
        ],
    },
)


ALL_PRESETS: list[PresetDefinition] = [
    CAMP_MODE,
    SENTRY_MODE,
    CABIN_OVERHEAT,
    CHARGE_COMPLETE,
]
