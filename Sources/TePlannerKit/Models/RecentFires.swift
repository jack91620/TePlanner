import Foundation

/// One entry in the recent rule-fire timeline.
public struct RecentFireEntry: Equatable, Sendable, Codable, Identifiable {
    /// AlertKind raw value (campMode / sentryMode / leftUnlocked /
    /// chargeComplete / etc.). Pair with VehicleAlert.Kind for icon
    /// + accent.
    public let kind: String
    public let pushedAt: Date
    public let clearedAt: Date?

    public var id: String { "\(kind)-\(pushedAt.timeIntervalSince1970)" }

    enum CodingKeys: String, CodingKey {
        case kind
        case pushedAt = "pushed_at"
        case clearedAt = "cleared_at"
    }

    public init(kind: String, pushedAt: Date, clearedAt: Date? = nil) {
        self.kind = kind
        self.pushedAt = pushedAt
        self.clearedAt = clearedAt
    }
}

public struct RecentFiresResponse: Equatable, Sendable, Codable {
    public let fires: [RecentFireEntry]

    public init(fires: [RecentFireEntry]) {
        self.fires = fires
    }
}
