import Foundation

/// Broad bucket a rule belongs to. Today only `.reminder` is shipped;
/// `.event` and `.scheduled` are placeholders for Phase 5.3+ (charging
/// complete, pre-trip preheat) so the settings UI can group rules
/// without re-touching the protocol.
public enum AutomationCategory: String, CaseIterable, Sendable {
    case reminder    // 状态遗忘类（露营 / 哨兵 / 过热）
    case event       // 状态变化触发（充电完成）
    case scheduled   // 时间触发（行前预热）
}

/// Concrete API call the engine should run when the user taps an
/// alert's primary button. Modeled as a value type so tests can assert
/// on the produced action without mocking the API surface.
public enum AutomationAction: Equatable, Sendable {
    case setClimateKeeperMode(vehicleId: String, mode: Int)
    case setSentryMode(vehicleId: String, on: Bool)
    case dismiss
}

/// Per-rule scratchpad. Rules use it to remember "first time I observed
/// this on" timestamps across polling ticks. Engine injects the same
/// instance into every `evaluate` call.
public protocol AutomationStateMemory: AnyObject {
    func get(_ key: String) -> Date?
    func set(_ key: String, value: Date?)
}

public final class InMemoryAutomationStateMemory: AutomationStateMemory {
    private var store: [String: Date] = [:]
    public init() {}
    public func get(_ key: String) -> Date? { store[key] }
    public func set(_ key: String, value: Date?) {
        if let value { store[key] = value } else { store.removeValue(forKey: key) }
    }
}

/// Snapshot the engine hands to each rule per evaluation tick.
public struct AutomationContext {
    public let vehicleState: VehicleState?
    public let vehicleId: String?
    public let now: Date
    public let settings: SettingsStore
    public let memory: AutomationStateMemory

    public init(
        vehicleState: VehicleState?,
        vehicleId: String?,
        now: Date,
        settings: SettingsStore,
        memory: AutomationStateMemory
    ) {
        self.vehicleState = vehicleState
        self.vehicleId = vehicleId
        self.now = now
        self.settings = settings
        self.memory = memory
    }
}

/// One rule. The engine keeps a registry of these and re-runs `evaluate`
/// on every tick. `evaluate` is allowed to write to `context.memory` —
/// e.g. to record the first-on timestamp the rule needs to compute
/// duration. Side-effect-free purity isn't required because the
/// alternative would be a separate observe/evaluate split that makes
/// every rule more boilerplate-heavy without buying real isolation.
public protocol Automation: Sendable {
    var kind: VehicleAlert.Kind { get }
    var displayName: String { get }
    var category: AutomationCategory { get }
    func evaluate(context: AutomationContext) -> VehicleAlert?
    func primaryAction(context: AutomationContext) -> AutomationAction?
    /// Called by the engine after a successful primary-action API call.
    /// The default does nothing; rules with a memory key (camp/sentry)
    /// override to clear it so the next tick doesn't immediately
    /// re-fire on stale state.
    func onActionSucceeded(memory: AutomationStateMemory)
}

extension Automation {
    public var id: String { kind.rawValue }
    public func onActionSucceeded(memory: AutomationStateMemory) {}
}
