import Foundation

/// Phase 5.3 rule: notify the user when the car has finished
/// charging so they can come unplug. Different shape from the
/// duration-based reminders — this one is **event-triggered**, so
/// the rule fires on the `Charging → Complete` transition rather
/// than after a timer.
///
/// State machine, encoded in two date entries on the engine's memory:
///
/// - `firstSeenAt`  — set on the first tick we observe `Complete`,
///                    cleared whenever the chargingState leaves
///                    `Complete` (user unplugs / starts a new
///                    session). Drives "is the alert active?".
/// - `dismissedAt`  — set when the user taps "我知道了". Suppresses
///                    re-firing for the rest of this session, but
///                    is cleared at the same time as `firstSeenAt`,
///                    so plugging in again re-arms the alert.
///
/// `chargeCompleteReminderEnabled` (Bool) toggles the whole rule.
/// Threshold-based rules don't apply here — there's no "for X
/// minutes" knob to tune; it either fires on Complete or it doesn't.
public struct ChargeCompleteAutomation: Automation {
    public let kind: VehicleAlert.Kind = .chargeComplete
    public let displayName = "充电完成提醒"
    public let category: AutomationCategory = .event

    private let firstSeenKey = "chargeComplete:firstSeenAt"
    private let dismissedKey = "chargeComplete:dismissedAt"

    public init() {}

    public func evaluate(context: AutomationContext) -> VehicleAlert? {
        guard context.settings.chargeCompleteReminderEnabled else { return nil }

        let isComplete = (context.vehicleState?.chargingState == "Complete")

        if !isComplete {
            // Plugged out / new session — wipe both flags so the
            // next Complete transition fires fresh.
            if context.memory.get(firstSeenKey) != nil {
                context.memory.set(firstSeenKey, value: nil)
                Log.vehicle.notice("charge-complete cleared: state left Complete")
            }
            context.memory.set(dismissedKey, value: nil)
            return nil
        }

        if context.memory.get(dismissedKey) != nil { return nil }

        if context.memory.get(firstSeenKey) == nil {
            context.memory.set(firstSeenKey, value: context.now)
            Log.vehicle.notice("charge-complete detected")
        }

        let soc = context.vehicleState?.batteryLevel ?? 0
        return VehicleAlert(
            kind: kind,
            title: "充电已完成",
            detail: "电量 \(soc)%，可拔枪了",
            severity: .critical,
            primaryActionLabel: "我知道了"
        )
    }

    public func primaryAction(context: AutomationContext) -> AutomationAction? {
        .dismiss
    }

    public func onActionSucceeded(memory: AutomationStateMemory) {
        memory.set(dismissedKey, value: Date())
    }
}
