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


LEFT_UNLOCKED = PresetDefinition(
    preset_id="left_unlocked_warning",
    name="停车后忘锁车提醒",
    spec={
        "kind": "leftUnlocked",
        "trigger": {
            "type": "state_duration",
            "entity": "vehicle.parked_unlocked",
            "equals": True,
            "for_minutes": 5,
            "state_key": "leftUnlocked:startedAt",
        },
        "actions_below": [],
        "actions_above": [
            {
                "type": "notify_and_offer",
                "title": "车辆未锁",
                "body": "停车 {duration_human}，车门仍处于未锁状态",
                "severity": "critical",
                "primary_action_label": "锁车",
                "capability": "tesla.security.door_lock",
            }
        ],
    },
)

WINDOW_OR_BOX_LEFT_OPEN = PresetDefinition(
    preset_id="closure_left_open_warning",
    name="车窗 / 后备箱忘关提醒",
    spec={
        "kind": "closureLeftOpen",
        "trigger": {
            "type": "state_duration",
            # Use the most-likely-actionable signal: window open while
            # parked. Door / trunk variants land as separate user-
            # authored rules until we add multi-condition support.
            "entity": "vehicle.parked_with_window_open",
            "equals": True,
            "for_minutes": 5,
            "state_key": "closureLeftOpen:startedAt",
        },
        "actions_below": [],
        "actions_above": [
            {
                "type": "notify_and_offer",
                "title": "车窗未关闭",
                "body": "已停车 {duration_human}，仍有车窗处于打开状态",
                "severity": "critical",
                "primary_action_label": "我知道了",
                "capability": "automation.dismiss",
            }
        ],
    },
)


LOW_BATTERY = PresetDefinition(
    preset_id="low_battery_warning",
    name="电量过低提醒",
    spec={
        "kind": "lowBattery",
        "trigger": {
            "type": "state_duration",
            "entity": "vehicle.battery_level",
            "op": "<",
            "value": 30,
            "for_minutes": 1,
            "state_key": "lowBattery:startedAt",
        },
        "actions_below": [],
        "actions_above": [
            {
                "type": "notify_and_offer",
                "title": "电量较低",
                "body": "电池电量已低于 30%，建议尽快充电",
                "severity": "critical",
                "primary_action_label": "我知道了",
                "capability": "automation.dismiss",
            }
        ],
    },
)


WEEKDAY_PREHEAT = PresetDefinition(
    preset_id="weekday_preheat",
    name="工作日早 7:30 自动预热",
    spec={
        "kind": "weekdayPreheat",
        "trigger": {
            "type": "cron",
            "expr": "30 7 * * 1-5",  # MON..FRI 07:30
            "tz": "Asia/Shanghai",
            "last_fired_key": "weekdayPreheat:lastFiredAt",
        },
        # state_transition shape's `actions` reused for cron; the
        # interpreter feeds facts={battery_level, expr}.
        "actions": [
            {
                "type": "notify_and_offer",
                "title": "出发前预热",
                "body": "已到工作日 7:30，自动预热即将开始",
                "severity": "info",
                "primary_action_label": "立即启动",
                "capability": "tesla.climate.preheat",
                "params": {},
            }
        ],
    },
)


# Phase 8 — geofence presets. Lat/lng are placeholders (0, 0); the
# iOS builder forces the user to set a real location via the map
# picker before save (isValid checks the lat is non-zero). Disabled
# by default so a fresh-seeded user doesn't fire on (0, 0).

GEOFENCE_ARRIVE_HOME = PresetDefinition(
    preset_id="geofence_arrive_home",
    name="到家提示",
    spec={
        "kind": "geofenceEnter",
        "enabled": False,
        "trigger": {
            "type": "geofence",
            "lat": 0.0,
            "lng": 0.0,
            "radius_m": 200,
            "event": "enter",
            "state_key": "geo:home_arrive",
        },
        "actions": [
            {
                "type": "notify",
                "title": "已到家",
                "body": "车辆进入「家」附近 {distance_m} 米",
                "severity": "info",
            }
        ],
    },
)


GEOFENCE_LEAVE_HOME_SENTRY = PresetDefinition(
    preset_id="geofence_leave_home_sentry",
    name="离家自动开哨兵",
    spec={
        "kind": "geofenceExit",
        "enabled": False,
        "trigger": {
            "type": "geofence",
            "lat": 0.0,
            "lng": 0.0,
            "radius_m": 200,
            "event": "exit",
            "state_key": "geo:home_leave_sentry",
        },
        "actions": [
            {
                "type": "notify_and_offer",
                "title": "已离开「家」",
                "body": "是否启动哨兵模式保护车辆？",
                "severity": "info",
                "primary_action_label": "启动哨兵",
                "capability": "tesla.security.set_sentry",
                "params": {"on": True},
            }
        ],
    },
)


GEOFENCE_ARRIVE_WORK_LOCK = PresetDefinition(
    preset_id="geofence_arrive_work_lock",
    name="到达公司锁车",
    spec={
        "kind": "geofenceEnter",
        "enabled": False,
        "trigger": {
            "type": "geofence",
            "lat": 0.0,
            "lng": 0.0,
            "radius_m": 100,
            "event": "enter",
            "state_key": "geo:work_arrive_lock",
        },
        "actions": [
            {
                "type": "notify_and_offer",
                "title": "到达「公司」",
                "body": "车辆已停妥，是否立即锁车？",
                "severity": "critical",
                "primary_action_label": "锁车",
                "capability": "tesla.security.door_lock",
            }
        ],
    },
)


ALL_PRESETS: list[PresetDefinition] = [
    CAMP_MODE,
    SENTRY_MODE,
    CABIN_OVERHEAT,
    CHARGE_COMPLETE,
    LEFT_UNLOCKED,
    WINDOW_OR_BOX_LEFT_OPEN,
    LOW_BATTERY,
    WEEKDAY_PREHEAT,
    GEOFENCE_ARRIVE_HOME,
    GEOFENCE_LEAVE_HOME_SENTRY,
    GEOFENCE_ARRIVE_WORK_LOCK,
]
