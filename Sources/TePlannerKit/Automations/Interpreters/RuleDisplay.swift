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
        case "tesla.climate.set_keeper_mode": return "调整空调保持模式"
        case "tesla.climate.preheat": return "启动预热"
        case "tesla.security.set_sentry": return "切换哨兵模式"
        case "tesla.charging.set_limit": return "调整充电限额"
        case "tesla.navigation.send": return "发送导航目的地"
        case "automation.dismiss", "": return "仅关闭提醒"
        default: return capabilityId
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
        default:
            return type
        }
    }
}
