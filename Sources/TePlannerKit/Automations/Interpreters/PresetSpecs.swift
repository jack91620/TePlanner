import Foundation

/// Swift mirror of `backend/app/services/automation/presets.py` —
/// same wording, same thresholds, same trigger/action shape.
///
/// Used by iOS until Phase 10.3 ships the `GET /api/v1/automations`
/// endpoint, after which iOS pulls rules from backend and these
/// hardcoded specs go away. The duplication is temporary; tests
/// guarantee the Swift specs match Python byte-for-byte while it
/// exists.
public enum PresetSpecs {
    public static let campMode: RuleSpec = [
        "kind": .string("campMode"),
        "trigger": .object([
            "type": .string("state_duration"),
            "entity": .string("vehicle.climate.keeper_mode"),
            "equals": .int(3),
            "for_minutes": .int(120),
            "state_key": .string("campMode:startedAt"),
        ]),
        "actions_below": .array([
            .object([
                "type": .string("notify"),
                "title": .string("露营模式开启中"),
                "body": .string("已开启 {duration_human}"),
                "severity": .string("info"),
            ]),
        ]),
        "actions_above": .array([
            .object([
                "type": .string("notify_and_offer"),
                "title": .string("露营模式开启中"),
                "body": .string("已开启 {duration_human}，电池正在缓慢消耗"),
                "severity": .string("critical"),
                "primary_action_label": .string("关闭"),
                "capability": .string("tesla.climate.set_keeper_mode"),
                "params": .object(["mode": .int(0)]),
            ]),
        ]),
    ]

    public static let sentryMode: RuleSpec = [
        "kind": .string("sentryMode"),
        "trigger": .object([
            "type": .string("state_duration"),
            "entity": .string("vehicle.sentry_mode_on"),
            "equals": .bool(true),
            "for_minutes": .int(1440),
            "state_key": .string("sentryMode:startedAt"),
        ]),
        "actions_below": .array([
            .object([
                "type": .string("notify"),
                "title": .string("哨兵模式开启中"),
                "body": .string("已开启 {duration_human}"),
                "severity": .string("info"),
            ]),
        ]),
        "actions_above": .array([
            .object([
                "type": .string("notify_and_offer"),
                "title": .string("哨兵模式开启中"),
                "body": .string("已开启 {duration_human}，正在持续耗电"),
                "severity": .string("critical"),
                "primary_action_label": .string("关闭哨兵"),
                "capability": .string("tesla.security.set_sentry"),
                "params": .object(["on": .bool(false)]),
            ]),
        ]),
    ]

    public static let cabinOverheat: RuleSpec = [
        "kind": .string("cabinOverheat"),
        "trigger": .object([
            "type": .string("state_duration"),
            "entity": .string("vehicle.cabin_overheat_protection_on"),
            "equals": .bool(true),
            "for_minutes": .int(60),
            "state_key": .string("cabinOverheat:startedAt"),
        ]),
        "actions_below": .array([]),
        "actions_above": .array([
            .object([
                "type": .string("notify"),
                "title": .string("座舱过热保护已启动"),
                "body": .string("已运行 {duration_human}，车辆正在自动通风/降温"),
                "severity": .string("info"),
            ]),
        ]),
    ]

    public static let chargeComplete: RuleSpec = [
        "kind": .string("chargeComplete"),
        "trigger": .object([
            "type": .string("state_transition"),
            "entity": .string("vehicle.charging.state"),
            "to": .string("Complete"),
            "first_seen_key": .string("chargeComplete:firstSeenAt"),
            "dismissed_key": .string("chargeComplete:dismissedAt"),
            "reset_when_not_to": .bool(true),
        ]),
        "actions": .array([
            .object([
                "type": .string("notify_and_offer"),
                "title": .string("充电已完成"),
                "body": .string("电量 {battery_level}%，可拔枪了"),
                "severity": .string("critical"),
                "primary_action_label": .string("我知道了"),
                "capability": .string("automation.dismiss"),
            ]),
        ]),
    ]

    public static let leftUnlocked: RuleSpec = [
        "kind": .string("leftUnlocked"),
        "trigger": .object([
            "type": .string("state_duration"),
            "entity": .string("vehicle.parked_unlocked"),
            "equals": .bool(true),
            "for_minutes": .int(5),
            "state_key": .string("leftUnlocked:startedAt"),
        ]),
        "actions_below": .array([]),
        "actions_above": .array([
            .object([
                "type": .string("notify_and_offer"),
                "title": .string("车辆未锁"),
                "body": .string("停车 {duration_human}，车门仍处于未锁状态"),
                "severity": .string("critical"),
                "primary_action_label": .string("我知道了"),
                "capability": .string("automation.dismiss"),
            ]),
        ]),
    ]

    public static let closureLeftOpen: RuleSpec = [
        "kind": .string("closureLeftOpen"),
        "trigger": .object([
            "type": .string("state_duration"),
            "entity": .string("vehicle.parked_with_window_open"),
            "equals": .bool(true),
            "for_minutes": .int(5),
            "state_key": .string("closureLeftOpen:startedAt"),
        ]),
        "actions_below": .array([]),
        "actions_above": .array([
            .object([
                "type": .string("notify_and_offer"),
                "title": .string("车窗未关闭"),
                "body": .string("已停车 {duration_human}，仍有车窗处于打开状态"),
                "severity": .string("critical"),
                "primary_action_label": .string("我知道了"),
                "capability": .string("automation.dismiss"),
            ]),
        ]),
    ]

    /// Records ready to seed into the engine. Each carries the same
    /// `preset_id` and `name` strings as `presets.py`.
    public static let allPresets: [RuleRecord] = [
        RuleRecord(
            id: "preset:camp_mode_overstay",
            presetId: "camp_mode_overstay",
            name: "露营模式超时提醒",
            enabled: true,
            spec: campMode
        ),
        RuleRecord(
            id: "preset:sentry_mode_overstay",
            presetId: "sentry_mode_overstay",
            name: "哨兵模式长时间开启",
            enabled: true,
            spec: sentryMode
        ),
        RuleRecord(
            id: "preset:cabin_overheat_alert",
            presetId: "cabin_overheat_alert",
            name: "座舱过热保护",
            enabled: true,
            spec: cabinOverheat
        ),
        RuleRecord(
            id: "preset:charge_complete_reminder",
            presetId: "charge_complete_reminder",
            name: "充电完成提醒",
            enabled: true,
            spec: chargeComplete
        ),
        RuleRecord(
            id: "preset:left_unlocked_warning",
            presetId: "left_unlocked_warning",
            name: "停车后忘锁车提醒",
            enabled: true,
            spec: leftUnlocked
        ),
        RuleRecord(
            id: "preset:closure_left_open_warning",
            presetId: "closure_left_open_warning",
            name: "车窗 / 后备箱忘关提醒",
            enabled: true,
            spec: closureLeftOpen
        ),
    ]
}
