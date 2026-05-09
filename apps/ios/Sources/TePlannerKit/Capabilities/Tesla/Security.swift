import Foundation

/// `tesla.security.set_sentry` — toggle sentry mode. Marked
/// `safetyClass = .security` because turning sentry off weakens the
/// parked-car security posture and any user-authored rule invoking it
/// needs an explicit acknowledge.
public struct SetSentryModeCapability: Capability {
    public let id = "tesla.security.set_sentry"
    public let safetyClass: SafetyClass = .security

    public init() {}

    public func invoke(
        ctx: CapabilityContext,
        params: [String: JSONValue],
        api: APIServiceProtocol
    ) async -> CapabilityResult {
        guard let on = params.bool("on") else {
            return CapabilityResult(success: false, error: "on must be boolean")
        }
        guard let vehicleId = ctx.vehicleId else {
            return CapabilityResult(success: false, error: "vehicleId required")
        }
        let result = await api.setSentryMode(vehicleId: vehicleId, on: on)
        switch result {
        case .success:
            return CapabilityResult(success: true)
        case .failure(let err):
            return CapabilityResult(success: false, error: err.localizedDescription)
        }
    }
}
