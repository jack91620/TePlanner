import Foundation

/// Evaluates one declarative rule against vehicle state. Mirrors
/// `backend/app/services/automation/interpreters.py` byte-for-byte —
/// same trigger semantics, same template substitution, same wording.
/// Single source of truth for rule strings is the backend; iOS just
/// re-evaluates the same JSON it cached from the API for live UI.

private let entityMap: [String: WritableKeyPath<VehicleState, JSONValue>] = [:]
// Note: VehicleState is the iOS Tesla state model; we read from it via
// the function below rather than KeyPath since some attributes are
// computed properties.

private func readEntity(_ entity: String, from state: VehicleState?) -> JSONValue? {
    guard let state else { return nil }
    switch entity {
    case "vehicle.climate.keeper_mode":
        return state.climateKeeperMode.map { .int($0) } ?? .null
    case "vehicle.sentry_mode_on":
        return .bool(state.sentryModeOn ?? false)
    case "vehicle.cabin_overheat_protection_on":
        return .bool(state.cabinOverheatProtectionOn ?? false)
    case "vehicle.charging.state":
        return state.chargingState.map { .string($0) } ?? .null
    case "vehicle.battery_level":
        return state.batteryLevel.map { .int($0) } ?? .null
    // Slice A — closure / lock virtual entities. parked_* combine
    // shift_state with the raw signal so rules don't false-positive
    // while the user is sitting in the car with door open.
    case "vehicle.locked":
        return .bool(state.locked ?? false)
    case "vehicle.parked_unlocked":
        return .bool(state.parkedUnlocked)
    case "vehicle.parked_with_door_open":
        return .bool(state.parkedWithDoorOpen)
    case "vehicle.parked_with_window_open":
        return .bool(state.parkedWithWindowOpen)
    case "vehicle.parked_with_frunk_open":
        return .bool(state.parkedWithFrunkOpen)
    case "vehicle.parked_with_trunk_open":
        return .bool(state.parkedWithTrunkOpen)
    // Phase 7 — physical-state entities. iOS exposes these via the
    // existing VehicleState DTO (lat/lng/speed) plus a few new
    // optional fields synthesized from telemetry on the next refresh.
    case "vehicle.location.latitude":
        return state.latitude.map { .double($0) } ?? .null
    case "vehicle.location.longitude":
        return state.longitude.map { .double($0) } ?? .null
    case "vehicle.speed_kmh":
        return state.speed.map { .double(Double($0)) } ?? .null
    default:
        return nil
    }
}

private func formatMinutes(_ minutes: Int) -> String {
    // 0 分钟显示为「不到 1 分钟」更诚实——iOS 只能从首次观察到状态
    // 那一刻起算，触发评估的当下与首次观察是同一时刻，所以 0 是必然
    // 出现的瞬时值。直接显示 "0 分钟" 让用户以为坏了。
    if minutes < 1 { return "不到 1 分钟" }
    if minutes < 60 { return "\(minutes) 分钟" }
    let h = minutes / 60
    let m = minutes % 60
    return m == 0 ? "\(h) 小时" : "\(h) 小时 \(m) 分钟"
}

private func render(_ template: String, facts: [String: String]) -> String {
    var out = template
    for (k, v) in facts {
        out = out.replacingOccurrences(of: "{\(k)}", with: v)
    }
    return out
}

private func emitAction(
    _ action: [String: JSONValue],
    kind: VehicleAlert.Kind,
    facts: [String: String]
) -> VehicleAlert? {
    guard let type = action.string("type") else { return nil }
    let title = render(action.string("title") ?? "", facts: facts)
    let body = render(action.string("body") ?? "", facts: facts)
    let severityRaw = action.string("severity") ?? "info"
    let severity: VehicleAlert.Severity = (severityRaw == "critical") ? .critical : .info

    switch type {
    case "notify":
        return VehicleAlert(
            kind: kind,
            title: title,
            detail: body,
            severity: severity,
            primaryActionLabel: nil
        )
    case "notify_and_offer":
        return VehicleAlert(
            kind: kind,
            title: title,
            detail: body,
            severity: severity,
            primaryActionLabel: action.string("primary_action_label")
        )
    default:
        return nil
    }
}

private func valuesEqual(_ a: JSONValue, _ b: JSONValue) -> Bool {
    a == b
}

/// Slice B: state_duration may carry an `op` ("<", ">", "<=", ">=",
/// "==", "!="). Mirrors backend `_matches`. For numeric ops the
/// trigger's threshold lives under `value` (with fallback to `equals`
/// for compat).
private func matches(_ actual: JSONValue, op: String, trigger: [String: JSONValue]) -> Bool {
    if op == "==" {
        return trigger["equals"].map { valuesEqual(actual, $0) } ?? false
    }
    if op == "!=" {
        if let expected = trigger["equals"] {
            return !valuesEqual(actual, expected)
        }
        return false
    }
    let thresholdValue = trigger["value"] ?? trigger["equals"] ?? .null
    guard let a = actual.doubleValue, let t = thresholdValue.doubleValue else {
        return false
    }
    switch op {
    case "<":  return a < t
    case ">":  return a > t
    case "<=": return a <= t
    case ">=": return a >= t
    default:   return false
    }
}

private func evalStateDuration(
    _ spec: RuleSpec,
    ctx: AutomationContext,
    kind: VehicleAlert.Kind
) -> VehicleAlert? {
    guard let trigger = spec["trigger"]?.objectValue,
          let entity = trigger.string("entity"),
          let stateKey = trigger.string("state_key"),
          let threshold = trigger.int("for_minutes") else {
        return nil
    }
    let op = trigger.string("op") ?? "=="
    let actual = readEntity(entity, from: ctx.vehicleState) ?? .null
    let isOn = matches(actual, op: op, trigger: trigger)
    let recorded = ctx.memory.get(stateKey)

    // Memory bookkeeping for on/off transitions.
    if isOn && recorded == nil {
        ctx.memory.set(stateKey, value: ctx.now)
    } else if !isOn && recorded != nil {
        ctx.memory.set(stateKey, value: nil)
    }

    if !isOn { return nil }
    if threshold <= 0 { return nil }
    guard var onSince = ctx.memory.get(stateKey) else { return nil }

    // Phase 5: prefer the server-recorded telemetry transition time
    // when it's earlier than what we observed locally. Fleet Telemetry
    // pushes within seconds of the actual state change; iOS observation
    // happens at most once per polling cycle and can be much later
    // (especially after a fresh login or app cold start).
    if let telSince = ctx.memory.get("tel:\(entity):since"),
       telSince < onSince {
        onSince = telSince
    }

    let minutes = max(0, Int(ctx.now.timeIntervalSince(onSince) / 60))
    let above = minutes >= threshold
    let bucketKey = above ? "actions_above" : "actions_below"
    guard let bucket = spec[bucketKey]?.arrayValue, !bucket.isEmpty else {
        return nil
    }
    guard let actionDict = bucket.first?.objectValue else { return nil }
    let facts: [String: String] = [
        "duration_human": formatMinutes(minutes),
        "duration_minutes": "\(minutes)",
    ]
    return emitAction(actionDict, kind: kind, facts: facts)
}

private func evalStateTransition(
    _ spec: RuleSpec,
    ctx: AutomationContext,
    kind: VehicleAlert.Kind
) -> VehicleAlert? {
    guard let trigger = spec["trigger"]?.objectValue,
          let entity = trigger.string("entity"),
          let target = trigger["to"],
          let firstSeenKey = trigger.string("first_seen_key"),
          let dismissedKey = trigger.string("dismissed_key") else {
        return nil
    }
    let resetWhenNotTo = trigger.bool("reset_when_not_to") ?? true
    let actual = readEntity(entity, from: ctx.vehicleState) ?? .null
    let isTarget = valuesEqual(actual, target)

    if !isTarget {
        if resetWhenNotTo {
            if ctx.memory.get(firstSeenKey) != nil {
                ctx.memory.set(firstSeenKey, value: nil)
            }
            ctx.memory.set(dismissedKey, value: nil)
        }
        return nil
    }

    if ctx.memory.get(dismissedKey) != nil { return nil }
    if ctx.memory.get(firstSeenKey) == nil {
        ctx.memory.set(firstSeenKey, value: ctx.now)
    }

    let battery = readEntity("vehicle.battery_level", from: ctx.vehicleState)?.intValue ?? 0
    let facts: [String: String] = [
        "battery_level": "\(battery)",
    ]
    guard let actions = spec["actions"]?.arrayValue,
          let actionDict = actions.first?.objectValue else {
        return nil
    }
    return emitAction(actionDict, kind: kind, facts: facts)
}

/// Top-level entry: evaluate a single rule body against a context.
/// Returns nil if the rule is disabled or doesn't fire.
public func evaluateRule(
    _ spec: RuleSpec,
    context ctx: AutomationContext
) -> VehicleAlert? {
    if let enabled = spec.bool("enabled"), !enabled { return nil }
    guard let kindRaw = spec.string("kind"),
          let kind = VehicleAlert.Kind(rawValue: kindRaw),
          let triggerType = spec["trigger"]?.objectValue?.string("type") else {
        return nil
    }
    switch triggerType {
    case "state_duration":
        return evalStateDuration(spec, ctx: ctx, kind: kind)
    case "state_transition":
        return evalStateTransition(spec, ctx: ctx, kind: kind)
    default:
        return nil
    }
}

// MARK: - Helpers on JSONValue arrays

private extension JSONValue {
    var arrayValue: [JSONValue]? {
        if case .array(let v) = self { return v }
        return nil
    }
}
