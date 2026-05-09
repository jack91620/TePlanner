import Foundation

/// `tesla.climate.set_keeper_mode` — sets climate keeper to off / keep
/// / dog / camp (0..3). Used by the camp-mode automation's "关闭"
/// action to dial the keeper back to off.
public struct SetClimateKeeperModeCapability: Capability {
    public let id = "tesla.climate.set_keeper_mode"
    public let safetyClass: SafetyClass = .writable

    public init() {}

    public func invoke(
        ctx: CapabilityContext,
        params: [String: JSONValue],
        api: APIServiceProtocol
    ) async -> CapabilityResult {
        guard let mode = params.int("mode"), (0...3).contains(mode) else {
            return CapabilityResult(success: false, error: "mode must be 0..3")
        }
        guard let vehicleId = ctx.vehicleId else {
            return CapabilityResult(success: false, error: "vehicleId required")
        }
        let result = await api.setClimateKeeperMode(vehicleId: vehicleId, mode: mode)
        switch result {
        case .success:
            return CapabilityResult(success: true)
        case .failure(let err):
            return CapabilityResult(success: false, error: err.localizedDescription)
        }
    }
}

/// `tesla.climate.preheat` — start HVAC (auto_conditioning_start) so
/// the cabin is at temperature on arrival.
public struct PreheatCapability: Capability {
    public let id = "tesla.climate.preheat"
    public let safetyClass: SafetyClass = .writable

    public init() {}

    public func invoke(
        ctx: CapabilityContext,
        params: [String: JSONValue],
        api: APIServiceProtocol
    ) async -> CapabilityResult {
        guard let vehicleId = ctx.vehicleId else {
            return CapabilityResult(success: false, error: "vehicleId required")
        }
        let result = await api.preheat(vehicleId: vehicleId)
        switch result {
        case .success:
            return CapabilityResult(success: true)
        case .failure(let err):
            return CapabilityResult(success: false, error: err.localizedDescription)
        }
    }
}
