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
    default:
        return nil
    }
}

private func formatMinutes(_ minutes: Int) -> String {
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

private func evalStateDuration(
    _ spec: RuleSpec,
    ctx: AutomationContext,
    kind: VehicleAlert.Kind
) -> VehicleAlert? {
    guard let trigger = spec["trigger"]?.objectValue,
          let entity = trigger.string("entity"),
          let expected = trigger["equals"],
          let stateKey = trigger.string("state_key"),
          let threshold = trigger.int("for_minutes") else {
        return nil
    }
    let actual = readEntity(entity, from: ctx.vehicleState) ?? .null
    let isOn = valuesEqual(actual, expected)
    let recorded = ctx.memory.get(stateKey)

    // Memory bookkeeping for on/off transitions.
    if isOn && recorded == nil {
        ctx.memory.set(stateKey, value: ctx.now)
    } else if !isOn && recorded != nil {
        ctx.memory.set(stateKey, value: nil)
    }

    if !isOn { return nil }
    if threshold <= 0 { return nil }
    guard let onSince = ctx.memory.get(stateKey) else { return nil }

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
