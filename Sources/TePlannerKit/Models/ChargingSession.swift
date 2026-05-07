import Foundation

/// One charging session captured by `ChargingSessionTracker` while
/// the iOS app's polling loop sees the vehicle in `chargingState ==
/// "Charging"`. Persisted client-side via `ChargingSessionStore`
/// (UserDefaults). Future server-side history can adopt the same
/// shape without renames.
public struct ChargingSession: Codable, Identifiable, Equatable {
    /// Stable id for ForEach + dedupe across in-flight saves.
    public let id: UUID
    public let vehicleId: String?
    public let startAt: Date
    /// `nil` while the session is still ongoing (we record start
    /// optimistically and finalize on the next state transition).
    public var endAt: Date?
    public let startSoc: Int?
    public var endSoc: Int?
    /// Range added in km — most actionable single number for users.
    /// Computed from `(endRangeKm - startRangeKm)`. `nil` if either
    /// reading was missing.
    public let startRangeKm: Double?
    public var endRangeKm: Double?
    /// Where the car was when charging started — informational only.
    public let locationName: String?
    /// Whether the session ended normally (`Complete`) or was cut
    /// short (unplugged before full).
    public var endedAsComplete: Bool?

    public init(
        id: UUID = UUID(),
        vehicleId: String?,
        startAt: Date,
        endAt: Date? = nil,
        startSoc: Int?,
        endSoc: Int? = nil,
        startRangeKm: Double?,
        endRangeKm: Double? = nil,
        locationName: String?,
        endedAsComplete: Bool? = nil
    ) {
        self.id = id
        self.vehicleId = vehicleId
        self.startAt = startAt
        self.endAt = endAt
        self.startSoc = startSoc
        self.endSoc = endSoc
        self.startRangeKm = startRangeKm
        self.endRangeKm = endRangeKm
        self.locationName = locationName
        self.endedAsComplete = endedAsComplete
    }

    public var isOngoing: Bool { endAt == nil }

    public var durationMinutes: Int? {
        guard let endAt else { return nil }
        return max(0, Int(endAt.timeIntervalSince(startAt) / 60))
    }

    public var rangeAddedKm: Double? {
        guard let startRangeKm, let endRangeKm else { return nil }
        return max(0, endRangeKm - startRangeKm)
    }

    public var socDelta: Int? {
        guard let startSoc, let endSoc else { return nil }
        return max(0, endSoc - startSoc)
    }
}
