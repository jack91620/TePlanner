import Foundation

/// `tesla.charging.set_limit` — daily charge limit SOC (50..100). Tesla
/// rejects values outside that range; we validate in-band so the
/// engine and HTTP layer get a clean error rather than a bare 400.
public struct SetChargeLimitCapability: Capability {
    public let id = "tesla.charging.set_limit"
    public let safetyClass: SafetyClass = .writable

    public init() {}

    public func invoke(
        ctx: CapabilityContext,
        params: [String: JSONValue],
        api: APIServiceProtocol
    ) async -> CapabilityResult {
        guard let percent = params.int("percent"), (50...100).contains(percent) else {
            return CapabilityResult(success: false, error: "percent must be 50..100")
        }
        guard let vehicleId = ctx.vehicleId else {
            return CapabilityResult(success: false, error: "vehicleId required")
        }
        let result = await api.setChargeLimit(vehicleId: vehicleId, percent: percent)
        switch result {
        case .success:
            return CapabilityResult(success: true)
        case .failure(let err):
            return CapabilityResult(success: false, error: err.localizedDescription)
        }
    }
}
