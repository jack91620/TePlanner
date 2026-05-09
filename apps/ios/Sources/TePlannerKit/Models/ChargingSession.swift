import Foundation

// MARK: - Phase D.4 wire shapes (POST/GET /vehicles/{vid}/sessions)

public struct ChargingSessionRequest: Codable, Equatable, Sendable {
    public let clientSessionId: String?
    public let startedAt: Date
    public let endedAt: Date?
    public let startSoc: Int?
    public let endSoc: Int?
    public let startRangeKm: Double?
    public let endRangeKm: Double?
    public let energyAddedKwh: Double?
    public let locationName: String?
    public let lat: Double?
    public let lng: Double?
    public let endedAsComplete: Bool?

    enum CodingKeys: String, CodingKey {
        case clientSessionId = "client_session_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case startSoc = "start_soc"
        case endSoc = "end_soc"
        case startRangeKm = "start_range_km"
        case endRangeKm = "end_range_km"
        case energyAddedKwh = "energy_added_kwh"
        case locationName = "location_name"
        case lat
        case lng
        case endedAsComplete = "ended_as_complete"
    }
}

public struct ChargingSessionResponse: Codable, Equatable, Sendable {
    public let id: Int
    public let vehicleId: String?
    public let clientSessionId: String?
    public let startedAt: Date
    public let endedAt: Date?
    public let startSoc: Int?
    public let endSoc: Int?
    public let startRangeKm: Double?
    public let endRangeKm: Double?
    public let energyAddedKwh: Double?
    public let locationName: String?
    public let lat: Double?
    public let lng: Double?
    public let endedAsComplete: Bool?
    public let source: String
    public let durationMinutes: Int?
    public let rangeAddedKm: Double?
    public let socDelta: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId = "vehicle_id"
        case clientSessionId = "client_session_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case startSoc = "start_soc"
        case endSoc = "end_soc"
        case startRangeKm = "start_range_km"
        case endRangeKm = "end_range_km"
        case energyAddedKwh = "energy_added_kwh"
        case locationName = "location_name"
        case lat, lng
        case endedAsComplete = "ended_as_complete"
        case source
        case durationMinutes = "duration_minutes"
        case rangeAddedKm = "range_added_km"
        case socDelta = "soc_delta"
    }

    /// Project onto the in-app value type. `localId` lets the round-
    /// trip path keep the client UUID stable across the optimistic
    /// insert and the server-acked response.
    public func toDomain(localId: UUID? = nil) -> ChargingSession {
        ChargingSession(
            id: localId ?? UUID(uuidString: clientSessionId ?? "") ?? UUID(),
            vehicleId: vehicleId,
            startAt: startedAt,
            endAt: endedAt,
            startSoc: startSoc,
            endSoc: endSoc,
            startRangeKm: startRangeKm,
            endRangeKm: endRangeKm,
            locationName: locationName,
            endedAsComplete: endedAsComplete,
        )
    }
}

public struct ChargingSessionListResponse: Codable, Equatable, Sendable {
    public let sessions: [ChargingSessionResponse]
}


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

    /// Phase D.4 — project this in-app session onto the wire shape.
    /// `client_session_id` stays the local UUID so the backend's
    /// UNIQUE(client_session_id) lets repeated upserts (plug-in then
    /// plug-out) round-trip to the same row.
    public func toAPIRequest() -> ChargingSessionRequest {
        ChargingSessionRequest(
            clientSessionId: id.uuidString,
            startedAt: startAt,
            endedAt: endAt,
            startSoc: startSoc,
            endSoc: endSoc,
            startRangeKm: startRangeKm,
            endRangeKm: endRangeKm,
            energyAddedKwh: nil,
            locationName: locationName,
            lat: nil,
            lng: nil,
            endedAsComplete: endedAsComplete,
        )
    }
}
