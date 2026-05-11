import Foundation

/// A single piece of "the user forgot to clean this up" feedback shown
/// to the driver. Surfaces in the AlertPill on HomeView; mirror copy
/// lands in iOS Local Notifications when the same kind enters
/// `.critical` and the app isn't foregrounded.
public struct VehicleAlert: Identifiable, Equatable {
    public enum Kind: String, Hashable, Sendable {
        case campMode
        case sentryMode
        case cabinOverheat
        case chargeComplete
        // Slice A
        case leftUnlocked
        case closureLeftOpen
        // Slice B
        case lowBattery
        // Slice C
        case weekdayPreheat
        // Phase 8 — geofence + connectivity rules
        case geofenceEnter
        case geofenceExit
        case connectivity
        // Phase 11 — generic wait_for_state then-action result.
        case waitResolved
    }

    public enum Severity: String, Sendable {
        /// Status badge only — informational, no action button yet.
        case info
        /// Past the user's reminder threshold — pill turns critical
        /// + exposes the primary action (e.g. "关闭露营模式").
        case critical
    }

    public let kind: Kind
    public let title: String
    public let detail: String
    public let severity: Severity
    /// Localized label for the primary action button. `nil` when
    /// the alert is `.info` only.
    public let primaryActionLabel: String?

    public var id: Kind { kind }
}
