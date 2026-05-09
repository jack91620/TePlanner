import Foundation

/// Mirrors the Python SafetyClass enum (backend/app/services/capabilities/base.py).
public enum SafetyClass: String, Sendable, Codable {
    case read       // state read, side-effect free
    case writable   // changes a setting (climate, charge limit)
    case security   // weakens car's security posture (sentry off, unlock)
    case movement   // could cause physical motion
}

/// Plumbing each capability needs. Built by the dispatcher (engine /
/// future user-rule executor) before invocation.
public struct CapabilityContext: Sendable {
    public let vehicleId: String?

    public init(vehicleId: String?) {
        self.vehicleId = vehicleId
    }
}

/// Outcome of invoking a capability. Mirrors Python CapabilityResult.
public struct CapabilityResult: Sendable {
    public let success: Bool
    public let error: String?

    public init(success: Bool, error: String? = nil) {
        self.success = success
        self.error = error
    }
}

/// One Tesla command/read. Stateless struct — instantiate once,
/// register in CapabilityRegistry.shared.
public protocol Capability: Sendable {
    var id: String { get }
    var brand: String { get }
    var safetyClass: SafetyClass { get }
    /// User-authored rules invoking this need an explicit "I understand"
    /// toggle before save. Default: true unless safetyClass == .read.
    var requiresUserConfirm: Bool { get }

    func invoke(
        ctx: CapabilityContext,
        params: [String: JSONValue],
        api: APIServiceProtocol
    ) async -> CapabilityResult
}

public extension Capability {
    var brand: String { "tesla" }
    var requiresUserConfirm: Bool { safetyClass != .read }
}

/// Singleton dispatch table. Static because iOS has no module-init
/// hooks; we just hardcode the registered capabilities list.
public final class CapabilityRegistry: @unchecked Sendable {
    public static let shared = CapabilityRegistry(capabilities: [
        SetClimateKeeperModeCapability(),
        PreheatCapability(),
        SetSentryModeCapability(),
        SetChargeLimitCapability(),
        SendNavigationCapability(),
    ])

    private let byId: [String: any Capability]

    public init(capabilities: [any Capability]) {
        var map: [String: any Capability] = [:]
        for c in capabilities {
            assert(map[c.id] == nil, "duplicate capability id: \(c.id)")
            map[c.id] = c
        }
        self.byId = map
    }

    public func get(_ id: String) -> (any Capability)? {
        byId[id]
    }

    public func all() -> [any Capability] {
        Array(byId.values)
    }

    /// Look up + invoke. Unknown ids fail in-band as CapabilityResult.
    /// Network errors propagate via the `error` string (APIService
    /// surfaces them as APIError.localizedDescription).
    public func dispatch(
        capabilityId: String,
        ctx: CapabilityContext,
        params: [String: JSONValue],
        api: APIServiceProtocol
    ) async -> CapabilityResult {
        guard let cap = byId[capabilityId] else {
            return CapabilityResult(
                success: false,
                error: "Unknown capability: \(capabilityId)"
            )
        }
        return await cap.invoke(ctx: ctx, params: params, api: api)
    }
}
