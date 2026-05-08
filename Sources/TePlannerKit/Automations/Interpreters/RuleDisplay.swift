import Foundation

/// 把 declarative rule schema 里的 wire-format 字符串（entity 点路径、
/// trigger type、capability id 等）翻译成给用户看的中文。Source of truth
/// 暂时放 iOS 这边；后续如果矩阵变大就移到 backend 服务端 localization。
public enum RuleDisplay {
    /// 把观察项 entity 字符串翻译成用户友好的名字。
    public static func entityName(_ entity: String) -> String {
        switch entity {
        case "vehicle.climate.keeper_mode": return "空调保持模式"
        case "vehicle.sentry_mode_on": return "哨兵模式"
        case "vehicle.cabin_overheat_protection_on": return "座舱过热保护"
        case "vehicle.charging.state": return "充电状态"
        case "vehicle.battery_level": return "电量百分比"
        // Slice A — closure / lock virtual entities. Names embed
        // "停车后" because that's the precondition baked into the
        // virtual signal (filters out driving false-positives).
        case "vehicle.locked": return "车锁"
        case "vehicle.parked_unlocked": return "停车后未锁车"
        case "vehicle.parked_with_door_open": return "停车后车门开"
        case "vehicle.parked_with_window_open": return "停车后车窗开"
        case "vehicle.parked_with_frunk_open": return "停车后前备箱开"
        case "vehicle.parked_with_trunk_open": return "停车后后备箱开"
        default: return entity
        }
    }

    public static func triggerTypeName(_ type: String) -> String {
        switch type {
        case "state_duration": return "持续状态"
        case "state_transition": return "状态变化"
        case "cron": return "定时"
        case "geofence": return "地理围栏"
        default: return type
        }
    }

    /// 翻译 capability id 到操作名。空字符串 / "automation.dismiss" 视
    /// 为"仅关闭提醒"。
    public static func capabilityName(_ capabilityId: String) -> String {
        switch capabilityId {
        // Climate (climate.py + climate_extra.py)
        case "tesla.climate.set_keeper_mode":           return "调整空调保持模式"
        case "tesla.climate.preheat":                   return "启动预热"
        case "tesla.climate.stop":                      return "关闭空调"
        case "tesla.climate.set_temps":                 return "设置温度"
        case "tesla.climate.set_preconditioning_max":   return "切换最大预热"
        case "tesla.climate.set_cabin_overheat":        return "切换座舱过热保护"
        // Charging (charging.py + charging_extra.py)
        case "tesla.charging.set_limit":                return "调整充电限额"
        case "tesla.charging.start":                    return "开始充电"
        case "tesla.charging.stop":                     return "停止充电"
        case "tesla.charging.port_open":                return "打开充电口"
        case "tesla.charging.port_close":               return "关闭充电口"
        case "tesla.charging.set_amps":                 return "调整充电电流"
        // Security (security.py + closures.py)
        case "tesla.security.set_sentry":               return "切换哨兵模式"
        case "tesla.security.door_lock":                return "锁车"
        case "tesla.security.door_unlock":              return "解锁"
        case "tesla.security.actuate_frunk":            return "打开前备箱"
        case "tesla.security.actuate_trunk":            return "操作后备箱"
        // Closures (closures.py)
        case "tesla.closures.window_vent":              return "通风开窗"
        case "tesla.closures.window_close":             return "关闭车窗"
        case "tesla.closures.sun_roof_vent":            return "通风开天窗"
        case "tesla.closures.sun_roof_close":           return "关闭天窗"
        // Comfort (comfort.py)
        case "tesla.comfort.set_seat_heater":           return "设置座椅加热"
        case "tesla.comfort.set_steering_wheel_heater": return "切换方向盘加热"
        // Media (comfort.py + attention.py)
        case "tesla.media.toggle_playback":             return "切换车机播放"
        case "tesla.media.set_volume":                  return "设置车机音量"
        case "tesla.media.next_track":                  return "下一首"
        case "tesla.media.prev_track":                  return "上一首"
        // Navigation (navigation.py + attention.py)
        case "tesla.navigation.send":                   return "发送导航目的地"
        case "tesla.navigation.send_address":           return "发送地址到车"
        // Attention (attention.py)
        case "tesla.attention.flash_lights":            return "闪灯"
        case "tesla.attention.honk_horn":               return "鸣笛"
        case "tesla.attention.trigger_homelink":        return "触发 HomeLink"
        case "automation.dismiss", "":                  return "仅关闭提醒"
        default: return capabilityId
        }
    }

    /// Group capabilities into user-facing categories so the rule
    /// builder can render a sectioned picker. Order in the returned
    /// `categories` array drives display order; categories with no
    /// matching capability are filtered out by the caller.
    public static func capabilityCategory(_ capabilityId: String) -> CapabilityCategory {
        switch capabilityId {
        case let id where id.hasPrefix("tesla.climate."):    return .climate
        case let id where id.hasPrefix("tesla.charging."):   return .charging
        case let id where id.hasPrefix("tesla.security."),
             let id where id.hasPrefix("tesla.closures."):   return .security
        case let id where id.hasPrefix("tesla.comfort."):    return .comfort
        case let id where id.hasPrefix("tesla.media."):      return .media
        case let id where id.hasPrefix("tesla.navigation."): return .navigation
        case let id where id.hasPrefix("tesla.attention."):  return .attention
        default:                                              return .other
        }
    }

    public enum CapabilityCategory: String, CaseIterable {
        case climate, charging, security, comfort, media, navigation, attention, other

        public var label: String {
            switch self {
            case .climate:    return "空调与温度"
            case .charging:   return "充电"
            case .security:   return "安全与门窗"
            case .comfort:    return "座椅与方向盘"
            case .media:      return "车机媒体"
            case .navigation: return "导航"
            case .attention:  return "提示与车辆控制"
            case .other:      return "其他"
            }
        }

        /// SF Symbol name for the category — surfaces the section
        /// visually on the picker even when expanded.
        public var symbol: String {
            switch self {
            case .climate:    return "thermometer.medium"
            case .charging:   return "bolt.fill"
            case .security:   return "lock.shield.fill"
            case .comfort:    return "carseat.left.fill"
            case .media:      return "play.rectangle.fill"
            case .navigation: return "location.fill"
            case .attention:  return "light.beacon.max.fill"
            case .other:      return "square.grid.2x2"
            }
        }
    }

    /// 把 trigger 的 equals/to 值渲染成对应 entity 语境下用户看得懂的
    /// 形式。布尔 → 开/关，keeper_mode int → 露营/保持/宠物/关闭，等。
    public static func describeValue(_ value: JSONValue, entity: String) -> String {
        switch value {
        case .bool(let b):
            return b ? "开" : "关"
        case .int(let i):
            if entity == "vehicle.climate.keeper_mode" {
                switch i {
                case 0: return "关闭"
                case 1: return "保持"
                case 2: return "宠物模式"
                case 3: return "露营模式"
                default: return "\(i)"
                }
            }
            return "\(i)"
        case .string(let s): return s
        case .double(let d): return "\(d)"
        case .null: return "(空)"
        default: return "?"
        }
    }

    /// 把简单的 5-字段 cron expr 翻译成中文。覆盖 v1 builder 生成的
    /// 形态："分 时 * * 周几"。复杂表达式 fall-through 显示原 expr。
    public static func cronSentence(_ expr: String) -> String {
        let parts = expr.split(separator: " ").map(String.init)
        guard parts.count == 5 else { return "定时：\(expr)" }
        let (minute, hour, dom, month, weekday) = (parts[0], parts[1], parts[2], parts[3], parts[4])
        guard dom == "*", month == "*",
              let h = Int(hour), let m = Int(minute) else {
            return "定时：\(expr)"
        }
        let timeText = String(format: "%02d:%02d", h, m)
        let dayText: String
        if weekday == "*" {
            dayText = "每天"
        } else if weekday == "1-5" {
            dayText = "每个工作日"
        } else if weekday == "0,6" || weekday == "6,0" {
            dayText = "每个周末"
        } else {
            // Try comma-separated digit list "1,3,5" → 周一/周三/周五
            let cnDays = ["周日","周一","周二","周三","周四","周五","周六"]
            let nums = weekday.split(separator: ",").compactMap { Int($0) }
            if !nums.isEmpty, nums.allSatisfy({ (0...6).contains($0) }) {
                dayText = nums.map { cnDays[$0] }.joined(separator: "、")
            } else {
                dayText = "定时（\(weekday)）"
            }
        }
        return "\(dayText) \(timeText)"
    }

    /// Returns the next time a cron-triggered rule will fire, or nil
    /// for non-cron rules / unsupported expressions. Supports the v1
    /// 5-field shapes the iOS builder emits: 'M H * * W' where W ∈
    /// {*, '1-5', '0,6', comma-separated digits 0..6}. Walks forward
    /// up to 8 days from `referenceDate`. Asia/Shanghai time zone.
    public static func nextCronFire(
        spec: RuleSpec,
        referenceDate: Date = Date(),
        timeZone: TimeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
    ) -> Date? {
        guard let trigger = spec["trigger"]?.objectValue,
              trigger.string("type") == "cron",
              let expr = trigger.string("expr") else { return nil }
        let parts = expr.split(separator: " ").map(String.init)
        guard parts.count == 5,
              let minute = Int(parts[0]),
              let hour = Int(parts[1]),
              parts[2] == "*", parts[3] == "*" else { return nil }
        let allowedWeekdays: Set<Int>
        switch parts[4] {
        case "*":
            allowedWeekdays = Set(0...6)
        case "1-5":
            allowedWeekdays = [1, 2, 3, 4, 5]
        case "0,6", "6,0":
            allowedWeekdays = [0, 6]
        default:
            let nums = parts[4].split(separator: ",").compactMap { Int($0) }
            guard !nums.isEmpty, nums.allSatisfy({ (0...6).contains($0) }) else { return nil }
            allowedWeekdays = Set(nums)
        }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        for offset in 0...8 {
            guard let day = cal.date(byAdding: .day, value: offset, to: referenceDate) else { continue }
            let cronWeekday = (cal.component(.weekday, from: day) + 6) % 7
            guard allowedWeekdays.contains(cronWeekday) else { continue }
            var components = cal.dateComponents([.year, .month, .day], from: day)
            components.hour = hour
            components.minute = minute
            guard let target = cal.date(from: components) else { continue }
            if target > referenceDate { return target }
        }
        return nil
    }

    public static func formatDurationMinutes(_ minutes: Int) -> String {
        if minutes < 1 { return "不到 1 分钟" }
        if minutes < 60 { return "\(minutes) 分钟" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h) 小时" : "\(h) 小时 \(m) 分钟"
    }

    /// Detail 视图预览动作正文用 —— 把模板里的 {duration_human} 等占
    /// 位符填上 representative 值（duration 用规则自己的阈值，
    /// battery_level 用 80% 作 sample）。运行时实际推送会填真实数值。
    public static func previewTemplate(_ template: String, spec: RuleSpec) -> String {
        var out = template
        if let trigger = spec["trigger"]?.objectValue {
            if let mins = trigger.int("for_minutes") {
                out = out.replacingOccurrences(of: "{duration_human}", with: formatDurationMinutes(mins))
                out = out.replacingOccurrences(of: "{duration_minutes}", with: "\(mins)")
            }
        }
        out = out.replacingOccurrences(of: "{battery_level}", with: "80")
        return out
    }

    /// Translate `state_transition` target values from their wire form
    /// (Tesla-side enum strings) to user-facing Chinese.
    public static func transitionTargetName(entity: String, target: String) -> String {
        switch entity {
        case "vehicle.charging.state":
            switch target {
            case "Complete":     return "充电完成"
            case "Charging":     return "充电中"
            case "Disconnected": return "未连接"
            case "Stopped":      return "已停止"
            case "Starting":     return "开始充电"
            case "NoPower":      return "无电源"
            default:             return target
            }
        case "vehicle.connectivity":
            switch target {
            case "CONNECTED":    return "在线"
            case "DISCONNECTED": return "离线"
            default:             return target
            }
        default:
            return target
        }
    }

    /// SF Symbol name for the rule's trigger type — used in list
    /// cards so each automation has the kind of glanceable visual
    /// vocabulary iOS 快捷指令 uses (different category = different
    /// icon and accent).
    public static func triggerSymbol(_ spec: RuleSpec) -> String {
        guard let trigger = spec["trigger"]?.objectValue,
              let type = trigger.string("type") else {
            return "bell.badge.fill"
        }
        switch type {
        case "cron":              return "clock.fill"
        case "geofence":          return "location.fill"
        case "state_transition":  return "arrow.right.arrow.left.circle.fill"
        case "state_duration":
            // Sub-classify by the entity to pick a meaningful glyph,
            // matching iOS 快捷指令's habit of changing icon by
            // category (time / location / device / battery / …).
            let entity = trigger.string("entity") ?? ""
            switch entity {
            case "vehicle.battery_level":               return "battery.25"
            case "vehicle.climate.keeper_mode":         return "moon.zzz.fill"
            case "vehicle.sentry_mode_on":              return "shield.lefthalf.filled"
            case "vehicle.cabin_overheat_protection_on": return "thermometer.sun.fill"
            case "vehicle.parked_unlocked":             return "lock.open.fill"
            case "vehicle.parked_with_door_open",
                 "vehicle.parked_with_window_open",
                 "vehicle.parked_with_frunk_open",
                 "vehicle.parked_with_trunk_open":      return "door.left.hand.open"
            case "vehicle.connectivity":                return "antenna.radiowaves.left.and.right"
            default:                                    return "bell.badge.fill"
            }
        default:                  return "bell.badge.fill"
        }
    }

    /// 把规则的"动作"翻译成一句简短描述，配合 triggerSentence 形成
    /// "当 X 持续 Y，那么 Z" 的快捷指令风格描述。
    public static func actionSentence(_ spec: RuleSpec) -> String {
        // Pick the action that would actually fire — for state_duration
        // rules that's actions_above[0] (the threshold-crossed alert);
        // for everything else it's actions[0]. Empty action list → "".
        let bucketKey: String
        if spec["actions"]?.arrayValue != nil {
            bucketKey = "actions"
        } else if spec["actions_above"]?.arrayValue != nil {
            bucketKey = "actions_above"
        } else if spec["actions_below"]?.arrayValue != nil {
            bucketKey = "actions_below"
        } else {
            return ""
        }
        guard let arr = spec[bucketKey]?.arrayValue, let first = arr.first?.objectValue else {
            return ""
        }
        let aType = first.string("type") ?? ""
        let title = first.string("title") ?? ""
        switch aType {
        case "notify":
            return title.isEmpty ? "推送通知" : "通知「\(title)」"
        case "notify_and_offer":
            let label = first.string("primary_action_label") ?? ""
            if title.isEmpty {
                return label.isEmpty ? "推送通知" : "通知 + \(label)"
            }
            return label.isEmpty ? "通知「\(title)」" : "通知「\(title)」+ \(label)"
        case "invoke":
            let cap = first.string("capability") ?? ""
            return capabilityName(cap)
        case "wait_for_state":
            let then = first["then"]?.objectValue
            let thenTitle = then?.string("title") ?? ""
            return thenTitle.isEmpty ? "条件满足后通知" : "条件满足后通知「\(thenTitle)」"
        default:
            return aType
        }
    }

    /// 触发条件一句话总结。Detail 视图 / Home 视图都用。
    public static func triggerSentence(_ spec: RuleSpec) -> String {
        guard let trigger = spec["trigger"]?.objectValue,
              let type = trigger.string("type") else {
            return ""
        }
        switch type {
        case "state_duration":
            let entityRaw = trigger.string("entity") ?? ""
            let entity = entityName(entityRaw)
            let mins = trigger.int("for_minutes") ?? 0
            let op = trigger.string("op") ?? "=="
            switch op {
            case "<":
                let v = trigger["value"]?.intValue ?? 0
                return "「\(entity)」低于 \(v)% 持续 \(formatDurationMinutes(mins))"
            case "<=":
                let v = trigger["value"]?.intValue ?? 0
                return "「\(entity)」不超过 \(v)% 持续 \(formatDurationMinutes(mins))"
            case ">":
                let v = trigger["value"]?.intValue ?? 0
                return "「\(entity)」高于 \(v)% 持续 \(formatDurationMinutes(mins))"
            case ">=":
                let v = trigger["value"]?.intValue ?? 0
                return "「\(entity)」不低于 \(v)% 持续 \(formatDurationMinutes(mins))"
            default:
                // For boolean-true 虚拟实体（停车后未锁车 / 哨兵模式 等）
                // a "处于「开」状态" framing reads awkwardly. Prefer a
                // shorter form when the entity name itself describes
                // the active condition.
                let equals = trigger["equals"]
                if case .bool(let b) = equals ?? .null, b {
                    return "「\(entity)」持续 \(formatDurationMinutes(mins))"
                }
                let value = equals.flatMap { describeValue($0, entity: entityRaw) } ?? "?"
                return "「\(entity)」=「\(value)」 持续 \(formatDurationMinutes(mins))"
            }
        case "state_transition":
            let entity = entityName(trigger.string("entity") ?? "")
            let target = trigger.string("to") ?? "?"
            return "「\(entity)」变为「\(transitionTargetName(entity: trigger.string("entity") ?? "", target: target))」"
        case "cron":
            return cronSentence(trigger.string("expr") ?? "")
        case "geofence":
            let event = trigger.string("event") ?? "enter"
            let radius = trigger.int("radius_m") ?? 0
            let verb = event == "enter" ? "进入" : "离开"
            let lat = trigger.double("lat") ?? 0
            let lng = trigger.double("lng") ?? 0
            // 0,0 is the placeholder for unconfigured presets — call
            // out the user-action needed instead of leaking coords.
            if abs(lat) < 0.0001 && abs(lng) < 0.0001 {
                return "\(verb)某个区域 · \(radius)m（待选择地点）"
            }
            return "\(verb)区域 \(radius)m 范围"
        default:
            return type
        }
    }
}
