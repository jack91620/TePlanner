import Foundation

/// Phase D.3 — wire shape returned by GET/PUT /user/scheduled-departure.
/// iOS converts to/from the in-app `ScheduledDeparture` value type.
public struct ScheduledDepartureResponse: Codable, Equatable, Sendable {
    public let id: Int
    public let departureAtUtc: Date
    public let leadMinutes: Int
    public let label: String?
    public let vehicleId: String?
    public let targetChargeSoc: Int?
    public let enabled: Bool
    public let fireAtUtc: Date
    public let createdAt: Date?
    public let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case departureAtUtc = "departure_at_utc"
        case leadMinutes = "lead_minutes"
        case label
        case vehicleId = "vehicle_id"
        case targetChargeSoc = "target_charge_soc"
        case enabled
        case fireAtUtc = "fire_at_utc"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public func toDomain() -> ScheduledDeparture? {
        guard enabled else { return nil }
        return ScheduledDeparture(
            label: label,
            departureAt: departureAtUtc,
            leadTimeMinutes: leadMinutes,
            vehicleId: vehicleId,
        )
    }
}

public struct ScheduledDepartureRequest: Codable, Equatable, Sendable {
    public let departureAtUtc: Date
    public let leadMinutes: Int
    public let label: String?
    public let vehicleId: String?
    public let targetChargeSoc: Int?
    public let enabled: Bool

    public init(
        _ departure: ScheduledDeparture,
        enabled: Bool = true,
        targetChargeSoc: Int? = nil
    ) {
        self.departureAtUtc = departure.departureAt
        self.leadMinutes = departure.leadTimeMinutes
        self.label = departure.label
        self.vehicleId = departure.vehicleId
        self.targetChargeSoc = targetChargeSoc
        self.enabled = enabled
    }

    enum CodingKeys: String, CodingKey {
        case departureAtUtc = "departure_at_utc"
        case leadMinutes = "lead_minutes"
        case label
        case vehicleId = "vehicle_id"
        case targetChargeSoc = "target_charge_soc"
        case enabled
    }
}


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
