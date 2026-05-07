import Foundation

/// Phase 5.1 rule: warn when 露营模式 (camp mode) has been on past the
/// user's threshold. Below threshold: info-only pill. At/above
/// threshold: critical pill with a "关闭" button that calls
/// `set_climate_keeper_mode(0)`.
public struct CampModeAutomation: Automation {
    public let kind: VehicleAlert.Kind = .campMode
    public let displayName = "露营模式超时提醒"
    public let category: AutomationCategory = .reminder

    private let stateKey = "campMode:startedAt"

    public init() {}

    public func evaluate(context: AutomationContext) -> VehicleAlert? {
        let isOn = context.vehicleState?.isCampModeOn ?? false
        let recordedStart = context.memory.get(stateKey)

        if isOn && recordedStart == nil {
            context.memory.set(stateKey, value: context.now)
            Log.vehicle.notice("camp mode detected on")
        } else if !isOn && recordedStart != nil {
            context.memory.set(stateKey, value: nil)
            Log.vehicle.notice("camp mode cleared")
        }

        guard isOn, let onSince = context.memory.get(stateKey) else { return nil }
        let threshold = context.settings.campModeReminderMinutes
        guard threshold > 0 else { return nil }

        let minutes = max(0, Int(context.now.timeIntervalSince(onSince) / 60))
        let critical = minutes >= threshold
        return VehicleAlert(
            kind: kind,
            title: "露营模式开启中",
            detail: critical
                ? "已开启 \(formatMinutes(minutes))，电池正在缓慢消耗"
                : "已开启 \(formatMinutes(minutes))",
            severity: critical ? .critical : .info,
            primaryActionLabel: critical ? "关闭" : nil
        )
    }

    public func primaryAction(context: AutomationContext) -> AutomationAction? {
        guard let vehicleId = context.vehicleId else { return nil }
        return .setClimateKeeperMode(vehicleId: vehicleId, mode: 0)
    }

    public func onActionSucceeded(memory: AutomationStateMemory) {
        memory.set(stateKey, value: nil)
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) 分钟" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h) 小时" : "\(h) 小时 \(m) 分钟"
    }
}
