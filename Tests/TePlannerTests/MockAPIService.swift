import Foundation
@testable import TePlannerKit

/// Test mock — set the `mock*` properties before invoking. Each call site
/// records its invocation count for assertions.
final class MockAPIService: APIServiceProtocol {

    // Routes / geocoding
    var mockGeocodeResponse: Result<GeocodeResponse, APIError>!
    var mockReverseGeocodeResponse: Result<ReverseGeocodeResponse, APIError>!

    // Tesla OAuth
    var mockTeslaAuthUrlResponse: Result<TeslaAuthUrlResponse, APIError>!
    var mockTeslaStatusResponse: Result<TeslaStatusResponse, APIError>!
    var mockUnbindTeslaResponse: Result<BaseResponse, APIError>!

    // Auth
    var mockValidateTokenResponse: Result<AuthValidationResponse, APIError>!
    var mockRefreshTokenResponse: Result<AuthResponse, APIError>!

    // Vehicles
    var mockVehiclesResponse: Result<VehiclesResponse, APIError>!
    var mockVehicleStateResponse: Result<VehicleState, APIError>!
    /// If non-empty, each call to `getVehicleState` consumes the next entry
    /// (and the last entry sticks once the queue is exhausted). Useful for
    /// simulating "first probe fails, wake succeeds on Nth retry".
    var mockVehicleStateSequence: [Result<VehicleState, APIError>] = []
    var mockWakeVehicleResponse: Result<WakeResponse, APIError>!
    var mockSendNavigationResponse: Result<BaseResponse, APIError>!

    // Charging stations
    var mockStationDetailResponse: Result<ChargingStation, APIError>!
    var mockNearbyStationsResponse: Result<[ChargingStation], APIError>!
    var mockRecentRoutesResponse: Result<RecentRoutesResponse, APIError>!

    // Call counts
    var geocodeCallCount = 0
    var reverseGeocodeCallCount = 0
    var lastReverseGeocodeArgs: (lat: Double, lng: Double)?
    var teslaAuthUrlCallCount = 0
    var teslaStatusCallCount = 0
    var unbindTeslaCallCount = 0
    var validateTokenCallCount = 0
    var refreshTokenCallCount = 0
    var getVehiclesCallCount = 0
    var getVehicleStateCallCount = 0
    var wakeVehicleCallCount = 0
    var sendNavigationCallCount = 0
    var stationDetailCallCount = 0
    var nearbyStationsCallCount = 0
    var recentRoutesCallCount = 0

    // Last-args capture for arg-level assertions
    var lastNavigationRequest: NavigationRequest?
    var lastNearbyStationsArgs: (lat: Double, lng: Double, radius: Int, type: String?)?
    var lastRecentRoutesArgs: (limit: Int, offset: Int)?

    var mockRouteOnlyResponse: Result<RouteOnlyResponse, APIError>!
    var routeOnlyCallCount = 0
    func routeOnly(origin: LocationInput, destination: LocationInput) async -> Result<RouteOnlyResponse, APIError> {
        routeOnlyCallCount += 1
        return mockRouteOnlyResponse ?? .failure(.invalidResponse)
    }

    var mockChargingPlanResponse: Result<ChargingPlanResponse, APIError>!
    var chargingPlanCallCount = 0
    var lastChargingPlanRequest: ChargingPlanRequest?
    func chargingPlan(_ request: ChargingPlanRequest) async -> Result<ChargingPlanResponse, APIError> {
        chargingPlanCallCount += 1
        lastChargingPlanRequest = request
        return mockChargingPlanResponse ?? .failure(.invalidResponse)
    }

    func geocode(address: String) async -> Result<GeocodeResponse, APIError> {
        geocodeCallCount += 1
        return mockGeocodeResponse
    }

    func reverseGeocode(latitude: Double, longitude: Double) async -> Result<ReverseGeocodeResponse, APIError> {
        reverseGeocodeCallCount += 1
        lastReverseGeocodeArgs = (latitude, longitude)
        // Default to a benign empty response so tests that don't
        // care about reverse geocoding don't crash. Tests that
        // need a specific response set `mockReverseGeocodeResponse`.
        return mockReverseGeocodeResponse ?? .success(ReverseGeocodeResponse(
            latitude: latitude, longitude: longitude,
            address: nil, formattedAddress: nil
        ))
    }

    func getTeslaAuthUrl() async -> Result<TeslaAuthUrlResponse, APIError> {
        teslaAuthUrlCallCount += 1
        return mockTeslaAuthUrlResponse
    }

    func checkTeslaStatus(userId: String) async -> Result<TeslaStatusResponse, APIError> {
        teslaStatusCallCount += 1
        return mockTeslaStatusResponse
    }

    func unbindTesla(userId: String) async -> Result<BaseResponse, APIError> {
        unbindTeslaCallCount += 1
        return mockUnbindTeslaResponse
    }

    func validateToken() async -> Result<AuthValidationResponse, APIError> {
        validateTokenCallCount += 1
        return mockValidateTokenResponse
    }

    func refreshToken(_ refreshToken: String) async -> Result<AuthResponse, APIError> {
        refreshTokenCallCount += 1
        return mockRefreshTokenResponse
    }

    func getVehicles(userId: String) async -> Result<VehiclesResponse, APIError> {
        getVehiclesCallCount += 1
        return mockVehiclesResponse
    }

    func getVehicleState(vehicleId: String, userId: String) async -> Result<VehicleState, APIError> {
        getVehicleStateCallCount += 1
        if !mockVehicleStateSequence.isEmpty {
            let result = mockVehicleStateSequence.first!
            if mockVehicleStateSequence.count > 1 {
                mockVehicleStateSequence.removeFirst()
            }
            return result
        }
        return mockVehicleStateResponse
    }

    func wakeVehicle(vehicleId: String, userId: String) async -> Result<WakeResponse, APIError> {
        wakeVehicleCallCount += 1
        return mockWakeVehicleResponse
    }

    func sendNavigation(vehicleId: String, request: NavigationRequest) async -> Result<BaseResponse, APIError> {
        sendNavigationCallCount += 1
        lastNavigationRequest = request
        return mockSendNavigationResponse
    }

    var mockSetClimateKeeperModeResponse: Result<BaseResponse, APIError>!
    var setClimateKeeperModeCallCount = 0
    var lastSetClimateKeeperModeArgs: (vehicleId: String, mode: Int)?

    func setClimateKeeperMode(vehicleId: String, mode: Int) async -> Result<BaseResponse, APIError> {
        setClimateKeeperModeCallCount += 1
        lastSetClimateKeeperModeArgs = (vehicleId, mode)
        return mockSetClimateKeeperModeResponse ?? .success(BaseResponse(success: true, message: "ok"))
    }

    var mockSetSentryModeResponse: Result<BaseResponse, APIError>!
    var setSentryModeCallCount = 0
    var lastSetSentryModeArgs: (vehicleId: String, on: Bool)?

    func setSentryMode(vehicleId: String, on: Bool) async -> Result<BaseResponse, APIError> {
        setSentryModeCallCount += 1
        lastSetSentryModeArgs = (vehicleId, on)
        return mockSetSentryModeResponse ?? .success(BaseResponse(success: true, message: "ok"))
    }

    var mockPreheatResponse: Result<BaseResponse, APIError>!
    var preheatCallCount = 0
    var lastPreheatVehicleId: String?

    func preheat(vehicleId: String) async -> Result<BaseResponse, APIError> {
        preheatCallCount += 1
        lastPreheatVehicleId = vehicleId
        return mockPreheatResponse ?? .success(BaseResponse(success: true, message: "ok"))
    }

    var mockSetChargeLimitResponse: Result<BaseResponse, APIError>!
    var setChargeLimitCallCount = 0
    var lastSetChargeLimitArgs: (vehicleId: String, percent: Int)?

    func setChargeLimit(vehicleId: String, percent: Int) async -> Result<BaseResponse, APIError> {
        setChargeLimitCallCount += 1
        lastSetChargeLimitArgs = (vehicleId, percent)
        return mockSetChargeLimitResponse ?? .success(BaseResponse(success: true, message: "ok"))
    }

    func getStationDetail(stationId: String) async -> Result<ChargingStation, APIError> {
        stationDetailCallCount += 1
        return mockStationDetailResponse
    }

    func getNearbyStations(latitude: Double, longitude: Double, radiusKm: Int, type: String?) async -> Result<[ChargingStation], APIError> {
        nearbyStationsCallCount += 1
        lastNearbyStationsArgs = (latitude, longitude, radiusKm, type)
        return mockNearbyStationsResponse
    }

    func getRecentRoutes(limit: Int, offset: Int) async -> Result<RecentRoutesResponse, APIError> {
        recentRoutesCallCount += 1
        lastRecentRoutesArgs = (limit, offset)
        return mockRecentRoutesResponse
    }

    func registerDeviceToken(_ token: String, bundleId: String?) async -> Result<BaseResponse, APIError> {
        return .success(BaseResponse(success: true, message: "ok"))
    }

    var mockListAutomationsResponse: Result<[RuleRecord], APIError> = .success([])
    var listAutomationsCallCount = 0
    func listAutomations() async -> Result<[RuleRecord], APIError> {
        listAutomationsCallCount += 1
        return mockListAutomationsResponse
    }

    var lastCreateAutomationArgs: (name: String, enabled: Bool, spec: RuleSpec)?
    func createAutomation(name: String, enabled: Bool, spec: RuleSpec) async -> Result<RuleRecord, APIError> {
        lastCreateAutomationArgs = (name, enabled, spec)
        return .success(RuleRecord(id: "new-id", presetId: nil, name: name, enabled: enabled, spec: spec))
    }

    var lastUpdateAutomationArgs: (id: String, name: String?, enabled: Bool?, spec: RuleSpec?)?
    func updateAutomation(id: String, name: String?, enabled: Bool?, spec: RuleSpec?) async -> Result<RuleRecord, APIError> {
        lastUpdateAutomationArgs = (id, name, enabled, spec)
        return .success(RuleRecord(id: id, presetId: nil, name: name ?? "", enabled: enabled ?? true, spec: spec ?? [:]))
    }

    var lastDeleteAutomationId: String?
    func deleteAutomation(id: String) async -> Result<BaseResponse, APIError> {
        lastDeleteAutomationId = id
        return .success(BaseResponse(success: true, message: "deleted"))
    }

    var mockListCapabilitiesResponse: Result<[CapabilityInfo], APIError> = .success([])
    func listCapabilities() async -> Result<[CapabilityInfo], APIError> {
        mockListCapabilitiesResponse
    }

    var mockFetchAutomationStateResponse: Result<TelemetryStateResponse, APIError> =
        .success(TelemetryStateResponse(vehicleId: nil, entries: []))
    func fetchAutomationState() async -> Result<TelemetryStateResponse, APIError> {
        mockFetchAutomationStateResponse
    }

    var mockPendingCommands: Result<PendingCommandListResponse, APIError> =
        .success(PendingCommandListResponse(pending: []))
    func fetchPendingCommands() async -> Result<PendingCommandListResponse, APIError> {
        mockPendingCommands
    }

    var mockQueuedCommands: Result<QueuedCommandListResponse, APIError> =
        .success(QueuedCommandListResponse(queued: []))
    func fetchQueuedCommands() async -> Result<QueuedCommandListResponse, APIError> {
        mockQueuedCommands
    }

    var lastCancelQueuedId: Int?
    func cancelQueuedCommand(id: Int) async -> Result<BaseResponse, APIError> {
        lastCancelQueuedId = id
        return .success(BaseResponse(success: true, message: "cancelled"))
    }
}
