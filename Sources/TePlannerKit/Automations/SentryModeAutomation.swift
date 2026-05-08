import Foundation

/// Phase 5.2 rule: warn when 哨兵模式 (sentry mode) has been on past
/// the user's threshold. Sentry burns ~1% battery per hour while
/// active so the long-tail "left it on for days" case is the actual
/// pain point we're solving.
///
/// Default threshold (in `SettingsStore.sentryReminderMinutes`) is 12h
/// — long enough to skip the routine "parked at the mall for an hour"
/// case, short enough to surface multi-day forgets.
///
/// `primaryAction` produces `.setSentryMode(on: false)` which the
/// engine routes to `POST /vehicles/{id}/sentry-mode`. The endpoint
/// is gated on a confirmation dialog in the host (HomeView), since
/// disabling sentry weakens the parked-car security posture and the
/// user should opt in on each tap.
public struct SentryModeAutomation: Automation {
    public let kind: VehicleAlert.Kind = .sentryMode
    public let displayName = "哨兵模式长时间开启"
    public let category: AutomationCategory = .reminder

    private let stateKey = "sentryMode:startedAt"

    public init() {}

    public func evaluate(context: AutomationContext) -> VehicleAlert? {
        let isOn = context.vehicleState?.sentryModeOn ?? false
        let recordedStart = context.memory.get(stateKey)

        if isOn && recordedStart == nil {
            context.memory.set(stateKey, value: context.now)
            Log.vehicle.notice("sentry mode detected on")
        } else if !isOn && recordedStart != nil {
            context.memory.set(stateKey, value: nil)
            Log.vehicle.notice("sentry mode cleared")
        }

        guard isOn, let onSince = context.memory.get(stateKey) else { return nil }
        let threshold = context.settings.sentryReminderMinutes
        guard threshold > 0 else { return nil }

        let minutes = max(0, Int(context.now.timeIntervalSince(onSince) / 60))
        let critical = minutes >= threshold
        return VehicleAlert(
            kind: kind,
            title: "哨兵模式开启中",
            detail: critical
                ? "已开启 \(formatDuration(minutes))，正在持续耗电"
                : "已开启 \(formatDuration(minutes))",
            severity: critical ? .critical : .info,
            primaryActionLabel: critical ? "关闭哨兵" : nil
        )
    }

    public func primaryAction(context: AutomationContext) -> AutomationAction? {
        guard let vehicleId = context.vehicleId else { return nil }
        return .capability(
            id: "tesla.security.set_sentry",
            params: ["on": .bool(false)],
            vehicleId: vehicleId
        )
    }

    public func onActionSucceeded(memory: AutomationStateMemory) {
        memory.set(stateKey, value: nil)
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) 分钟" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h) 小时" : "\(h) 小时 \(m) 分钟"
    }
}
