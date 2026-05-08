import Foundation

/// Runs a registry of `Automation` rules against a stream of vehicle
/// state snapshots and exposes the resulting alerts. Replaces the
/// hard-coded camp-mode logic that previously lived in
/// `AlertsViewModel`.
@MainActor
public final class AutomationEngine: ObservableObject {
    @Published public private(set) var alerts: [VehicleAlert] = []

    private let registry: [any Automation]
    private let apiService: APIServiceProtocol
    private let settings: SettingsStore
    private let memory: AutomationStateMemory
    private let now: () -> Date
    private var lastState: VehicleState?

    public init(
        registry: [any Automation],
        apiService: APIServiceProtocol,
        settings: SettingsStore,
        memory: AutomationStateMemory = InMemoryAutomationStateMemory(),
        now: @escaping () -> Date = Date.init
    ) {
        self.registry = registry
        self.apiService = apiService
        self.settings = settings
        self.memory = memory
        self.now = now
    }

    /// Feed in the latest VehicleState. Each registered rule is
    /// evaluated; the union of its outputs becomes the new alert list,
    /// sorted critical-first.
    public func observe(_ state: VehicleState?, vehicleId: String? = nil) {
        lastState = state
        recompute(vehicleId: vehicleId ?? state?.vehicleId)
    }

    /// Re-evaluate all rules against the most recent observed state.
    /// Useful in tests and after an action succeeds.
    public func recompute(vehicleId: String? = nil) {
        let ctx = AutomationContext(
            vehicleState: lastState,
            vehicleId: vehicleId ?? lastState?.vehicleId,
            now: now(),
            settings: settings,
            memory: memory
        )
        var emitted: [VehicleAlert] = []
        for rule in registry {
            if let alert = rule.evaluate(context: ctx) {
                emitted.append(alert)
            }
        }
        alerts = emitted.sorted { $0.severity.priority > $1.severity.priority }
    }

    public var registeredRules: [any Automation] { registry }

    /// Looks up the rule that produced `alert`, asks it for the action
    /// to run, executes it via `APIServiceProtocol`, and on success
    /// notifies the rule so it can clear its memory entries.
    public func performPrimaryAction(
        for alert: VehicleAlert,
        vehicleId: String?
    ) async -> Result<BaseResponse, APIError> {
        guard let rule = registry.first(where: { $0.kind == alert.kind }) else {
            Log.vehicle.error("automation primary action: no rule for \(alert.kind.rawValue, privacy: .public)")
            return .failure(.invalidResponse)
        }
        let ctx = AutomationContext(
            vehicleState: lastState,
            vehicleId: vehicleId ?? lastState?.vehicleId,
            now: now(),
            settings: settings,
            memory: memory
        )
        guard let action = rule.primaryAction(context: ctx) else {
            return .success(BaseResponse(success: true, message: nil))
        }

        let result: Result<BaseResponse, APIError>
        switch action {
        case .capability(let id, let params, let vid):
            Log.vehicle.notice("automation \(rule.id, privacy: .public) → \(id, privacy: .public)")
            let capCtx = CapabilityContext(vehicleId: vid)
            let cap = await CapabilityRegistry.shared.dispatch(
                capabilityId: id,
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
        case .dismiss:
            result = .success(BaseResponse(success: true, message: nil))
        }

        if case .success = result {
            rule.onActionSucceeded(memory: memory)
            // Optimistically drop the alert. We deliberately do NOT
            // `recompute` from `lastState` here — the cached state still
            // shows the trigger (e.g. camp_keeper_mode=3) until the next
            // poll lands, and re-evaluating would just re-record a fresh
            // start timestamp and re-emit the alert. The next observe()
            // tick refreshes truthfully.
            alerts = alerts.filter { $0.kind != alert.kind }
        }
        return result
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
