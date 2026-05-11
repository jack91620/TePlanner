import Foundation

/// One step inside a Hub Quick Action. Maps 1:1 to a Tesla capability
/// invocation: a registered `capability_id` + the params dict that
/// the capability's params_schema expects.
///
/// `delayMsAfter` is only used inside a multi-step action — the
/// runner waits this many milliseconds AFTER dispatching this step
/// before starting the next one. Useful for sequences like
/// "lock the car, wait 5s, then start sentry" where the second
/// command depends on the first having propagated to the vehicle.
/// nil = no delay (default, fire next step immediately).
public struct HubActionStep: Codable, Equatable {
    public let capability: String
    public let params: [String: JSONValue]
    public let delayMsAfter: Int?

    public init(
        capability: String,
        params: [String: JSONValue] = [:],
        delayMsAfter: Int? = nil
    ) {
        self.capability = capability
        self.params = params
        self.delayMsAfter = delayMsAfter
    }

    public enum CodingKeys: String, CodingKey {
        case capability, params
        case delayMsAfter = "delay_ms_after"
    }
}

/// Tint colour for a quick action tile. Five preset choices keep the
/// Hub visually coherent — open colour pickers in this surface lead
/// to 50 shades of red that look noisy together.
public enum HubActionTint: String, Codable, CaseIterable, Equatable {
    case blue, red, orange, green, gray

    /// Default tint for newly-created actions; same as the system
    /// accent so they blend in by default and users opt in to
    /// emphasis.
    public static let `default`: HubActionTint = .blue
}

/// A user-defined (or system-seeded) Hub Quick Action. The list of
/// all actions a user has is stored as a single JSON blob in
/// `user_settings["hub.actions"]`; the on-screen 8 slots reference
/// them by id (`user_settings["hub.slots"]`). Decoupled so a user
/// can swap which actions appear without losing definitions.
public struct HubAction: Codable, Identifiable, Equatable {
    public let id: String
    public let name: String
    /// SF Symbol from the curated 32-icon library. UI maps unknown
    /// values to a "questionmark.circle" fallback so a future
    /// removal from the library doesn't crash old clients.
    public let icon: String
    public let tint: HubActionTint
    /// Steps run in order. Empty array is treated as "no-op" by the
    /// runner — UI prevents save without at least one step.
    public let steps: [HubActionStep]
    /// When true, the runner shows an alert "确认执行 X?" before
    /// dispatching the first step. Capability-registry-required
    /// confirms (unlock / preheat / start_charging) force this on
    /// regardless of user choice — see HubActionsStore.run().
    public let confirmRequired: Bool
    /// Whether this is one of the built-in starter actions. System
    /// actions can be edited (rename / re-tint / change steps) but
    /// not deleted — they always exist in the action pool. Custom
    /// actions can be deleted; the slot reference becomes nil.
    public let isSystem: Bool
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        name: String,
        icon: String,
        tint: HubActionTint = .default,
        steps: [HubActionStep],
        confirmRequired: Bool = false,
        isSystem: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.tint = tint
        self.steps = steps
        self.confirmRequired = confirmRequired
        self.isSystem = isSystem
        self.createdAt = createdAt
    }

    public enum CodingKeys: String, CodingKey {
        case id, name, icon, tint, steps
        case confirmRequired = "confirm_required"
        case isSystem = "is_system"
        case createdAt = "created_at"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        icon = try c.decode(String.self, forKey: .icon)
        tint = (try c.decodeIfPresent(HubActionTint.self, forKey: .tint)) ?? .default
        steps = try c.decode([HubActionStep].self, forKey: .steps)
        confirmRequired = try c.decodeIfPresent(Bool.self, forKey: .confirmRequired) ?? false
        isSystem = try c.decodeIfPresent(Bool.self, forKey: .isSystem) ?? false
        createdAt = (try c.decodeIfPresent(Date.self, forKey: .createdAt)) ?? Date()
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(icon, forKey: .icon)
        try c.encode(tint, forKey: .tint)
        try c.encode(steps, forKey: .steps)
        try c.encode(confirmRequired, forKey: .confirmRequired)
        try c.encode(isSystem, forKey: .isSystem)
        try c.encode(createdAt, forKey: .createdAt)
    }
}

/// User's Hub-shown action assignments. Length 8 fixed (we render
/// a 2×4 grid). Element nil = empty slot; element holds an
/// `HubAction.id`. Decode is forgiving: shorter arrays pad with
/// nils, longer arrays truncate, unknown action ids become nil
/// (UI shows "+", user can re-assign).
public struct HubSlots: Codable, Equatable {
    public static let count: Int = 8
    public var slots: [String?]

    public init(slots: [String?] = Array(repeating: nil, count: HubSlots.count)) {
        self.slots = HubSlots.normalize(slots)
    }

    public enum CodingKeys: String, CodingKey {
        case slots
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try c.decodeIfPresent([String?].self, forKey: .slots) ?? []
        slots = HubSlots.normalize(raw)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(slots, forKey: .slots)
    }

    private static func normalize(_ raw: [String?]) -> [String?] {
        var out = raw.prefix(count).map { $0 }
        while out.count < count { out.append(nil) }
        return out
    }
}

/// SF Symbols curated for vehicle quick actions. Grouped so the
/// icon picker can show 6 sections with 4–8 icons each rather than
/// dumping 32 in a flat grid.
///
/// Add icons here when a new capability needs a fitting visual —
/// don't open the full 5000-icon SF Symbols catalog to the user.
public enum HubActionIconLibrary {
    public struct Group: Equatable {
        public let label: String
        public let icons: [String]
    }

    public static let groups: [Group] = [
        Group(label: "安全", icons: [
            "lock.fill", "lock.open.fill",
            "shield.lefthalf.filled", "light.beacon.max.fill",
            "megaphone.fill",
        ]),
        Group(label: "门窗", icons: [
            "door.left.hand.open", "suitcase.fill",
            "car.rear.fill", "rectangle.portrait.and.arrow.right.fill",
            "sun.haze.fill",
        ]),
        Group(label: "空调", icons: [
            "thermometer.medium", "snowflake",
            "moon.zzz.fill", "fan.fill",
            "flame.fill",
        ]),
        Group(label: "充电", icons: [
            "bolt.fill", "bolt.car.fill",
            "ev.charger", "battery.100",
            "hand.raised.slash.fill",
        ]),
        Group(label: "媒体", icons: [
            "play.fill", "pause.fill",
            "speaker.wave.2.fill", "speaker.slash.fill",
            "music.note",
        ]),
        Group(label: "其他", icons: [
            "location.fill", "paperplane.fill",
            "hand.tap.fill", "house.fill",
            "sparkles", "star.fill",
            "gearshape.fill",
        ]),
    ]

    /// Flat list of every icon offered, for tests / fallback search.
    public static var all: [String] {
        groups.flatMap { $0.icons }
    }

    /// True iff the symbol is offered in the picker. Used for round-
    /// trip validation when decoding a saved action.
    public static func contains(_ icon: String) -> Bool {
        all.contains(icon)
    }
}
