import Foundation

/// `tesla.navigation.send` — push GPS coordinates to the car's nav.
/// Note: backend uses numeric vehicle_id (not VIN) for this one since
/// `navigation_gps_request` is one of the few endpoints not on the
/// VCP-signed path.
public struct SendNavigationCapability: Capability {
    public let id = "tesla.navigation.send"
    public let safetyClass: SafetyClass = .writable

    public init() {}

    public func invoke(
        ctx: CapabilityContext,
        params: [String: JSONValue],
        api: APIServiceProtocol
    ) async -> CapabilityResult {
        guard let lat = params.double("latitude"),
              let lng = params.double("longitude") else {
            return CapabilityResult(success: false, error: "latitude / longitude required")
        }
        let name = params.string("name") ?? ""
        guard let vehicleId = ctx.vehicleId else {
            return CapabilityResult(success: false, error: "vehicleId required")
        }
        let request = NavigationRequest(latitude: lat, longitude: lng, name: name)
        let result = await api.sendNavigation(vehicleId: vehicleId, request: request)
        switch result {
        case .success:
            return CapabilityResult(success: true)
        case .failure(let err):
            return CapabilityResult(success: false, error: err.localizedDescription)
        }
    }
}
