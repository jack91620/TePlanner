import Foundation

/// Static lookup tables that the rule builder uses when the user
/// picks a capability for a `notify_and_offer` action:
///
///   - `defaultParams[id]` — params dict that auto-populates so a
///     rule has sane behaviour without the user filling every
///     field. e.g. `tesla.charging.set_limit` defaults to
///     `{"percent": 80}`.
///
///   - `defaultButtonLabel[id]` — short verb (≤4 Chinese chars) for
///     the inline notification action button. iOS truncates lock-
///     screen action titles, so distinct from
///     `RuleDisplay.capabilityName` which is descriptive.
///
/// Same source-of-truth as the capability registry — when a new
/// capability is registered (backend `services/capabilities/tesla/*`,
/// iOS `CapabilityRegistry`), add a row here too.
public enum CapabilityDefaults {
    public static let params: [String: [String: JSONValue]] = [
        "tesla.climate.set_keeper_mode":           ["mode": .int(0)],
        "tesla.climate.set_temps":                 ["driver_temp": .double(22), "passenger_temp": .double(22)],
        "tesla.climate.set_preconditioning_max":   ["on": .bool(true)],
        "tesla.climate.set_cabin_overheat":        ["mode": .int(2)],
        "tesla.charging.set_limit":                ["percent": .int(80)],
        "tesla.charging.set_amps":                 ["amps": .int(16)],
        "tesla.security.set_sentry":               ["on": .bool(false)],
        "tesla.comfort.set_seat_heater":           ["seat": .int(0), "level": .int(2)],
        "tesla.comfort.set_steering_wheel_heater": ["on": .bool(true)],
        "tesla.media.set_volume":                  ["volume": .double(5)],
    ]

    public static let buttonLabel: [String: String] = [
        "tesla.climate.set_keeper_mode":           "空调保持",
        "tesla.climate.preheat":                   "预热",
        "tesla.climate.stop":                      "关空调",
        "tesla.climate.set_temps":                 "车内温度",
        "tesla.climate.set_preconditioning_max":   "最大预热",
        "tesla.climate.set_cabin_overheat":        "座舱过热",
        "tesla.charging.set_limit":                "充电限额",
        "tesla.charging.start":                    "开始充电",
        "tesla.charging.stop":                     "停止充电",
        "tesla.charging.port_open":                "充电口",
        "tesla.charging.port_close":               "关充电口",
        "tesla.charging.set_amps":                 "充电电流",
        "tesla.security.set_sentry":               "哨兵",
        "tesla.security.door_lock":                "锁车",
        "tesla.security.door_unlock":              "解锁",
        "tesla.security.actuate_frunk":            "前备箱",
        "tesla.security.actuate_trunk":            "后备箱",
        "tesla.closures.window_vent":              "车窗通风",
        "tesla.closures.window_close":             "关车窗",
        "tesla.comfort.set_seat_heater":           "座椅加热",
        "tesla.comfort.set_steering_wheel_heater": "方向盘加热",
        "tesla.media.toggle_playback":             "播放",
        "tesla.media.set_volume":                  "车机音量",
        "tesla.media.next_track":                  "下一首",
        "tesla.media.prev_track":                  "上一首",
        "tesla.navigation.send":                   "导航",
        "tesla.attention.flash_lights":            "闪灯",
        "tesla.attention.honk_horn":               "鸣笛",
        "tesla.attention.trigger_homelink":        "HomeLink",
    ]
}
