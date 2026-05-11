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


# SMART_CABIN_OVERHEAT (智能过热保护，自定义温度) 预设已移除 (2026-05-11)
# 原因：inside_temp_c 是易变字段，车睡眠 30 分钟后 telemetry 停推
# → staleness gate 把值视为 None → 触发器在车真正需要它的时候（停在
# 烈日下半小时）正好不工作。Tesla 原生 COP 三档 (Low 30 / Med 35 /
# High 40°C) 跑在车机本地，深度睡眠也兜底，是更可靠的选择。
# 后续如果加 departure-event trigger 可以做「下车时车内已经超过 X°C」
# 的一次性提醒，但「持续监控温度自动开 COP」用不了我们的架构。

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


# LOW_BATTERY 预设已移除 (2026-05-11)
# 原因：电量是易变字段（车 vampire drain 在睡眠中持续掉电），
# 而 Tesla Fleet Telemetry 在车睡眠时不推送。这意味着「电量低于
# X%」的触发器只在车醒着时有效，而真正需要预警的场景（停几天电
# 慢慢掉）正好是车睡着的时候。给用户一个永远在他需要的时候不工作
# 的功能比不给更糟糕。
# 待 departure-event trigger 上线后会以「下车时电量 < X」的形式
# 重新加回（一次性 snapshot，不依赖持续监控）。
# AlertKind.LOW_BATTERY 仍保留供未来 / 自定义规则使用。


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
    WEEKDAY_PREHEAT,
    GEOFENCE_ARRIVE_HOME,
    GEOFENCE_LEAVE_HOME_SENTRY,
    GEOFENCE_ARRIVE_WORK_LOCK,
]
