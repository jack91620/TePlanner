import Foundation
@testable import TePlannerKit

/// Test mock — set the `mock*` properties before invoking. Each call site
/// records its invocation count for assertions.
final class MockAPIService: APIServiceProtocol {

    // Routes / geocoding (existing)
    var mockRoutePlanResponse: Result<RoutePlanResponse, APIError>!
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
    var planRouteCallCount = 0
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

    func planRoute(origin: LocationInput?, destination: LocationInput, currentSoc: Int?) async -> Result<RoutePlanResponse, APIError> {
        planRouteCallCount += 1
        return mockRoutePlanResponse
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
}
