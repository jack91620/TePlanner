import Foundation

/// Phase 5.2 rule: surface that 座舱过热保护 (cabin overheat
/// protection) is currently engaged. The car already auto-vents and
/// runs the AC when configured, so this is informational only —
/// no primary action button. The point is to nudge the user that
/// it's running so they remember to disable it before driving in
/// cold weather where it's a no-op.
///
/// Threshold semantics: `cabinOverheatReminderMinutes == 0` disables
/// the rule. Any positive value emits an info-level alert as soon as
/// `cabin_overheat_protection_on` flips true; we don't currently
/// upgrade to `.critical` because the car is already mitigating the
/// situation autonomously.
public struct CabinOverheatAutomation: Automation {
    public let kind: VehicleAlert.Kind = .cabinOverheat
    public let displayName = "座舱过热保护"
    public let category: AutomationCategory = .reminder

    private let stateKey = "cabinOverheat:startedAt"

    public init() {}

    public func evaluate(context: AutomationContext) -> VehicleAlert? {
        let isOn = context.vehicleState?.cabinOverheatProtectionOn ?? false
        let recordedStart = context.memory.get(stateKey)

        if isOn && recordedStart == nil {
            context.memory.set(stateKey, value: context.now)
        } else if !isOn && recordedStart != nil {
            context.memory.set(stateKey, value: nil)
        }

        guard isOn, let onSince = context.memory.get(stateKey) else { return nil }
        let threshold = context.settings.cabinOverheatReminderMinutes
        guard threshold > 0 else { return nil }

        let minutes = max(0, Int(context.now.timeIntervalSince(onSince) / 60))
        guard minutes >= threshold else { return nil }

        return VehicleAlert(
            kind: kind,
            title: "座舱过热保护已启动",
            detail: "已运行 \(formatDuration(minutes))，车辆正在自动通风/降温",
            severity: .info,
            primaryActionLabel: nil
        )
    }

    public func primaryAction(context: AutomationContext) -> AutomationAction? { nil }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) 分钟" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h) 小时" : "\(h) 小时 \(m) 分钟"
    }
}
