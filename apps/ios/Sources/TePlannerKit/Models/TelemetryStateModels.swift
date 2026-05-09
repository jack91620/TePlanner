import Foundation

/// One telemetry-recorded entity state from
/// `GET /api/v1/automations/state`. Phase 5: gives iOS the true
/// "started at" timestamp the Fleet Telemetry consumer recorded
/// server-side, so the HubView pill can report the same elapsed
/// time the server reports in push notifications.
public struct TelemetryStateEntry: Equatable, Sendable, Codable {
    public let entity: String
    public let value: JSONValue
    public let since: Date

    public init(entity: String, value: JSONValue, since: Date) {
        self.entity = entity
        self.value = value
        self.since = since
    }
}

public struct TelemetryStateResponse: Equatable, Sendable, Codable {
    public let vehicleId: String?
    public let entries: [TelemetryStateEntry]

    enum CodingKeys: String, CodingKey {
        case vehicleId = "vehicle_id"
        case entries
    }

    public init(vehicleId: String?, entries: [TelemetryStateEntry]) {
        self.vehicleId = vehicleId
        self.entries = entries
    }
}
