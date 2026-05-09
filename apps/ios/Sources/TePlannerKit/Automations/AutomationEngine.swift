import Combine
import Foundation

/// Runs a registry of declarative rule specs (`RuleRecord`) against a
/// stream of vehicle state snapshots and exposes the resulting alerts.
///
/// Phase 10.2: rules are JSON specs evaluated by `evaluateRule(...)`.
/// The engine no longer holds typed rule classes — it just iterates
/// `[RuleRecord]`, calls the interpreter, and dispatches the primary
/// action on user tap by reading the spec's `actions_above[0]`
/// (state_duration) or `actions[0]` (state_transition).
///
/// Same alert wording as before; backend (when Phase 10.3 lands the
/// CRUD API) and iOS evaluate the same JSON spec so APNs and live UI
/// stay in sync. Until then iOS uses `PresetSpecs.allPresets` for
/// the registry and backend continues to push from its own copy.
@MainActor
public final class AutomationEngine: ObservableObject {
    @Published public private(set) var alerts: [VehicleAlert] = []

    private var registry: [RuleRecord]
    private let apiService: APIServiceProtocol
    private let settings: SettingsStore
    private let snoozes: SnoozeStore
    private let memory: AutomationStateMemory
    private let now: () -> Date
    private var lastState: VehicleState?
    private var snoozeSubscription: AnyCancellable?

    public init(
        registry: [RuleRecord],
        apiService: APIServiceProtocol,
        settings: SettingsStore,
        snoozes: SnoozeStore,
        memory: AutomationStateMemory = InMemoryAutomationStateMemory(),
        now: @escaping () -> Date = Date.init
    ) {
        self.registry = registry
        self.apiService = apiService
        self.settings = settings
        self.snoozes = snoozes
        self.memory = memory
        self.now = now
        snoozeSubscription = snoozes.changesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                self.recompute()
            }
    }

    /// Replace the rule registry — used after a /api/v1/automations
    /// fetch (Phase 10.3+) or when user toggles a rule on/off.
    public func updateRegistry(_ records: [RuleRecord]) {
        registry = records
        recompute()
    }

    /// Phase 5: seed engine memory with the server's telemetry-derived
    /// `since` timestamps. The interpreter prefers these over the
    /// locally-observed `state_key` start time when computing duration,
    /// so the HubView pill reports the same elapsed time the server
    /// reports in push notifications. Caller (HubView) fetches via
    /// `apiService.fetchAutomationState()` and applies the entries
    /// before/after each `observe(...)`.
    public func applyServerTelemetryState(_ entries: [TelemetryStateEntry]) {
        for entry in entries {
            memory.set("tel:\(entry.entity):since", value: entry.since)
        }
        recompute()
    }

    /// Feed in the latest VehicleState. Each registered rule is
    /// evaluated; the union of its outputs becomes the new alert list,
    /// sorted critical-first.
    public func observe(_ state: VehicleState?, vehicleId: String? = nil) {
        lastState = state
        recompute(vehicleId: vehicleId ?? state?.vehicleId)
    }

    /// Re-evaluate all rules against the most recent observed state.
    public func recompute(vehicleId: String? = nil) {
        let ctx = AutomationContext(
            vehicleState: lastState,
            vehicleId: vehicleId ?? lastState?.vehicleId,
            now: now(),
            settings: settings,
            memory: memory
        )
        var emitted: [VehicleAlert] = []
        let active = snoozes.activeUntil
        for record in registry where record.enabled {
            if active[record.id] != nil { continue }
            if let alert = evaluateRule(record.spec, context: ctx) {
                emitted.append(alert)
            }
        }
        alerts = emitted.sorted { $0.severity.priority > $1.severity.priority }
    }

    public var registeredRules: [RuleRecord] { registry }

    /// On primary-button tap: find the rule that produced this alert
    /// (matched by kind), pull the matching action block from the
    /// spec, dispatch its capability via the registry. Mirrors the
    /// state-machine semantics of the old per-class `onActionSucceeded`.
    public func performPrimaryAction(
        for alert: VehicleAlert,
        vehicleId: String?
    ) async -> Result<BaseResponse, APIError> {
        guard let record = registry.first(where: { matches(record: $0, kind: alert.kind) }) else {
            Log.vehicle.error("automation primary action: no rule for \(alert.kind.rawValue, privacy: .public)")
            return .failure(.invalidResponse)
        }
        guard let action = primaryActionDict(in: record.spec, severity: alert.severity) else {
            return .success(BaseResponse(success: true, message: nil))
        }

        let vid = vehicleId ?? lastState?.vehicleId
        let result: Result<BaseResponse, APIError>
        if let capabilityId = action.string("capability"), capabilityId != "automation.dismiss" {
            Log.vehicle.notice("automation \(record.id, privacy: .public) → \(capabilityId, privacy: .public)")
            let capCtx = CapabilityContext(vehicleId: vid)
            let params = action["params"]?.objectValue ?? [:]
            let cap = await CapabilityRegistry.shared.dispatch(
                capabilityId: capabilityId,
                ctx: capCtx,
                params: params,
                api: apiService
            )
            if cap.success {
                result = .success(BaseResponse(success: true, message: nil))
            } else {
                result = .failure(.serverError(
                    statusCode: 500,
                    message: cap.error ?? "Capability dispatch failed"
                ))
            }
        } else {
            // automation.dismiss capability or no capability → no-op
            result = .success(BaseResponse(success: true, message: nil))
        }

        if case .success = result {
            applyOnSuccessSideEffects(record: record, alertKind: alert.kind)
            // Optimistically drop the alert. We deliberately do NOT
            // recompute from lastState — the cached state still shows
            // the trigger (e.g. keeper_mode=3) until the next poll
            // lands, and re-evaluating would record a fresh timestamp.
            alerts = alerts.filter { $0.kind != alert.kind }
        }
        return result
    }

    // MARK: - Helpers

    private func matches(record: RuleRecord, kind: VehicleAlert.Kind) -> Bool {
        record.spec.string("kind") == kind.rawValue
    }

    /// Locates the action dictionary that produced an alert at the
    /// given severity. For state_duration rules: actions_above[0] for
    /// .critical, actions_below[0] for .info. For state_transition
    /// rules: actions[0].
    private func primaryActionDict(
        in spec: RuleSpec,
        severity: VehicleAlert.Severity
    ) -> [String: JSONValue]? {
        if let actions = spec["actions"]?.objectValue {
            return actions
        }
        if case .array(let arr) = spec["actions"] ?? .null, let first = arr.first?.objectValue {
            return first
        }
        let bucketKey = (severity == .critical) ? "actions_above" : "actions_below"
        if case .array(let arr) = spec[bucketKey] ?? .null, let first = arr.first?.objectValue {
            return first
        }
        return nil
    }

    /// After a successful primary action, clear the rule's state
    /// memory keys so the next poll starts fresh. Mirrors the old
    /// per-rule `onActionSucceeded` overrides.
    private func applyOnSuccessSideEffects(record: RuleRecord, alertKind: VehicleAlert.Kind) {
        guard let trigger = record.spec["trigger"]?.objectValue else { return }
        if let stateKey = trigger.string("state_key") {
            // state_duration: clear startedAt
            memory.set(stateKey, value: nil)
        }
        if let dismissedKey = trigger.string("dismissed_key") {
            // state_transition: set dismissedAt to suppress re-fire
            memory.set(dismissedKey, value: now())
        }
    }
}

extension VehicleAlert.Severity {
    var priority: Int {
        switch self {
        case .critical: return 2
        case .info: return 1
        }
    }
}

