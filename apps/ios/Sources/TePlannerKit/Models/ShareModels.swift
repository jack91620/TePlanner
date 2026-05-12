import Foundation

/// Share wire types — match `backend/app/api/v1/shares.py`.
///
/// Two share kinds: `action` (a HubAction with semantic-icon ID
/// instead of SF Symbol name) and `rule` (an AutomationRule's
/// RuleRecord, sans server-side identifiers). The payload is
/// stored opaquely on the server; iOS / Android / Harmony each
/// decode it locally.

public enum ShareType: String, Codable, Sendable {
    case action
    case rule
}

/// Server response shape for POST /shares and GET /shares/{code}.
/// `payload` is the actual shared item, decoded as a generic
/// `[String: JSONValue]` — the caller projects it into a typed
/// `SharedActionPayload` / `SharedRulePayload` once it knows
/// `share_type`.
public struct ShareDetailResponse: Decodable, Sendable, Identifiable {
    public let code: String
    public let shareType: ShareType
    public let createdAt: Date
    public let expiresAt: Date
    public let viewCount: Int
    public let minAppVersion: String?
    public let payload: [String: JSONValue]
    public let revoked: Bool

    /// Codes are unique per the table PK constraint — fine to use
    /// as the SwiftUI identity for `.sheet(item:)`.
    public var id: String { code }

    enum CodingKeys: String, CodingKey {
        case code
        case shareType = "share_type"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case viewCount = "view_count"
        case minAppVersion = "min_app_version"
        case payload
        case revoked
    }
}

/// Lighter row used by `/shares/mine` (no payload echo).
public struct ShareSummary: Decodable, Sendable, Identifiable {
    public let code: String
    public let shareType: ShareType
    public let createdAt: Date
    public let expiresAt: Date
    public let viewCount: Int
    public let minAppVersion: String?
    public let revoked: Bool

    public var id: String { code }

    enum CodingKeys: String, CodingKey {
        case code
        case shareType = "share_type"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case viewCount = "view_count"
        case minAppVersion = "min_app_version"
        case revoked
    }
}

public struct ShareListResponse: Decodable, Sendable {
    public let shares: [ShareSummary]
}

/// Wire-format for a shared HubAction. The on-device HubAction has
/// extras we don't share (`id`, `isSystem`); this type captures
/// exactly what travels through the share code.
public struct SharedActionPayload: Codable, Sendable {
    public let name: String
    /// Semantic icon ID — see `SemanticIcon.symbolToSemantic`.
    /// iOS converts back to SF Symbol at import.
    public let icon: String
    public let tint: HubActionTint
    public let steps: [HubActionStep]
    public let confirmRequired: Bool

    enum CodingKeys: String, CodingKey {
        case name, icon, tint, steps
        case confirmRequired = "confirm_required"
    }

    public init(
        name: String,
        icon: String,
        tint: HubActionTint,
        steps: [HubActionStep],
        confirmRequired: Bool,
    ) {
        self.name = name
        self.icon = icon
        self.tint = tint
        self.steps = steps
        self.confirmRequired = confirmRequired
    }
}

/// Wire-format for a shared automation rule. We re-use the existing
/// RuleSpec for the body — that's already platform-neutral (entity
/// IDs, capability IDs, no client-specific fields).
public struct SharedRulePayload: Codable, Sendable {
    public let name: String
    public let enabled: Bool
    public let spec: RuleSpec

    public init(name: String, enabled: Bool, spec: RuleSpec) {
        self.name = name
        self.enabled = enabled
        self.spec = spec
    }
}

/// Encode a Codable share payload into the `[String: JSONValue]`
/// shape the backend POST /shares accepts. Returns nil if encoding
/// fails (shouldn't happen for our types — defended in case a
/// future field stops being JSON-encodable).
public func encodeShareablePayload<T: Encodable>(_ value: T) -> [String: JSONValue]? {
    do {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode([String: JSONValue].self, from: data)
    } catch {
        return nil
    }
}

extension SharedActionPayload {
    /// Project an on-device HubAction into the share wire format,
    /// converting SF Symbol → semantic icon ID.
    public static func from(_ action: HubAction) -> SharedActionPayload {
        SharedActionPayload(
            name: action.name,
            icon: SemanticIcon.semantic(for: action.icon),
            tint: action.tint,
            steps: action.steps,
            confirmRequired: action.confirmRequired,
        )
    }

    /// Materialize the imported payload into a new HubAction with a
    /// fresh UUID id. `isSystem` is forced false — imported actions
    /// are user-owned and can be edited / deleted.
    public func toHubAction() -> HubAction {
        HubAction(
            id: UUID().uuidString,
            name: name,
            icon: SemanticIcon.symbol(for: icon),
            tint: tint,
            steps: steps,
            confirmRequired: confirmRequired,
            isSystem: false,
        )
    }
}
