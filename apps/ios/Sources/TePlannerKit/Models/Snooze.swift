import Foundation

/// Phase D.1 — server-canonical snooze record. iOS stopped owning the
/// snooze map (UserDefaults `rule_snooze_until`) and now relies on the
/// backend `automation_snooze` table; this struct is the wire shape
/// returned by `GET /automations/snoozes` and `POST/DELETE
/// /automations/{rule_id}/snooze`.
public struct SnoozeRecord: Codable, Equatable, Sendable, Identifiable {
    public let ruleId: String
    public let snoozedUntilUtc: Date
    public let reason: String?
    public let createdAt: Date

    public var id: String { ruleId }

    public init(ruleId: String, snoozedUntilUtc: Date, reason: String? = nil, createdAt: Date) {
        self.ruleId = ruleId
        self.snoozedUntilUtc = snoozedUntilUtc
        self.reason = reason
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case ruleId = "rule_id"
        case snoozedUntilUtc = "snoozed_until_utc"
        case reason
        case createdAt = "created_at"
    }
}

public struct SnoozeListResponse: Codable, Equatable, Sendable {
    public let snoozes: [SnoozeRecord]

    public init(snoozes: [SnoozeRecord]) {
        self.snoozes = snoozes
    }
}
