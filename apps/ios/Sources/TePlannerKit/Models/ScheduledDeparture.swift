import Foundation

/// A user-set "I plan to leave at <time>, remind me to start preheat
/// N minutes before" entry. There's only ever one active at a time —
/// new schedules overwrite old ones to keep the model simple. If we
/// ever want recurring departures (work commute / pickup runs) we
/// promote this to an array on the store side.
public struct ScheduledDeparture: Codable, Equatable {
    /// User-supplied label for the departure (e.g. "上班 / 接小孩").
    /// Optional — we never block save on missing label.
    public let label: String?
    /// When the user intends to drive off.
    public let departureAt: Date
    /// Minutes before departure to fire the preheat reminder.
    /// Stored separately so we can change defaults without re-prompting.
    public let leadTimeMinutes: Int
    /// Vehicle ID at the time of scheduling — used to target the
    /// preheat API call and to skip notifications if the user
    /// rebinds to a different car.
    public let vehicleId: String?

    public init(
        label: String? = nil,
        departureAt: Date,
        leadTimeMinutes: Int = 15,
        vehicleId: String?
    ) {
        self.label = label
        self.departureAt = departureAt
        self.leadTimeMinutes = max(1, leadTimeMinutes)
        self.vehicleId = vehicleId
    }

    /// When the local notification should fire.
    public var fireAt: Date {
        departureAt.addingTimeInterval(-Double(leadTimeMinutes) * 60)
    }

    public func isInFuture(now: Date = Date()) -> Bool {
        departureAt > now
    }
}
