import Foundation

/// Backend's `Capability.describe()` shape — used by the iOS visual
/// builder to render action-block pickers without hardcoding what
/// each capability accepts. `params_schema` is a relaxed JSONSchema
/// (we read `properties[*].type / enum / minimum / maximum / description`).
public struct CapabilityInfo: Equatable, Sendable, Codable, Identifiable {
    public let id: String
    public let brand: String
    public let safetyClass: SafetyClass
    public let requiresUserConfirm: Bool
    public let costUnits: Int
    public let paramsSchema: JSONValue

    enum CodingKeys: String, CodingKey {
        case id, brand
        case safetyClass = "safety_class"
        case requiresUserConfirm = "requires_user_confirm"
        case costUnits = "cost_units"
        case paramsSchema = "params_schema"
    }

    public init(
        id: String,
        brand: String,
        safetyClass: SafetyClass,
        requiresUserConfirm: Bool,
        costUnits: Int,
        paramsSchema: JSONValue
    ) {
        self.id = id
        self.brand = brand
        self.safetyClass = safetyClass
        self.requiresUserConfirm = requiresUserConfirm
        self.costUnits = costUnits
        self.paramsSchema = paramsSchema
    }

    /// User-friendly label for picker rows. Capability ids look like
    /// `tesla.climate.set_keeper_mode`; the visible part is the last
    /// path segment with underscores → spaces.
    public var displayName: String {
        let last = id.split(separator: ".").last.map(String.init) ?? id
        return last.replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}
