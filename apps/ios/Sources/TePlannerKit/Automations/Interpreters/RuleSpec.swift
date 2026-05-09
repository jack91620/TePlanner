import Foundation

/// Declarative rule body — wire format the backend serves and iOS
/// caches. Mirrors the Python dict shape from
/// `backend/app/services/automation/interpreters.py` so a rule
/// authored in the visual builder (Phase 10.3) round-trips between
/// client and server with zero translation.
///
/// We store the spec as a typed dictionary (`[String: JSONValue]`)
/// rather than a tree of structs to avoid Codable explosion across
/// the trigger / action discriminator surface. The interpreter
/// (`evaluateRule`) reads the dict at evaluation time.
public typealias RuleSpec = [String: JSONValue]

/// One full rule entity from `GET /api/v1/automations`. Carries the
/// row identity (id / preset_id / name / enabled) plus the spec body.
public struct RuleRecord: Equatable, Sendable, Codable, Identifiable {
    public let id: String
    public let presetId: String?
    public let name: String
    public let enabled: Bool
    public let spec: RuleSpec
    public let version: Int
    /// Last time this rule's kind fired a push notification. Read
    /// from the server's PushedAlert ledger; nil if never fired.
    public let lastFiredAt: Date?
    /// Phase A.2 — user-overridden display position (server-authoritative
    /// after Phase D.2). NULL means "use canonical preset/created-at
    /// order"; the server has already sorted the list before sending,
    /// so iOS preserves order as-received and only writes back via
    /// `PUT /automations/order` on user drag/move.
    public let displayOrder: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case presetId = "preset_id"
        case name
        case enabled
        case spec
        case version
        case lastFiredAt = "last_fired_at"
        case displayOrder = "display_order"
    }

    public init(
        id: String,
        presetId: String?,
        name: String,
        enabled: Bool,
        spec: RuleSpec,
        version: Int = 1,
        lastFiredAt: Date? = nil,
        displayOrder: Int? = nil
    ) {
        self.id = id
        self.presetId = presetId
        self.name = name
        self.enabled = enabled
        self.spec = spec
        self.version = version
        self.lastFiredAt = lastFiredAt
        self.displayOrder = displayOrder
    }
}
