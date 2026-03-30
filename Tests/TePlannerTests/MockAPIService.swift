import Foundation
@testable import TePlannerKit // Import the library module

// The mock service that we will use in our tests.
// It conforms to the same protocol as our real APIService.
class MockAPIService: APIServiceProtocol {
    
    // We can control the mock's behavior from our tests by setting these properties.
    var mockRoutePlanResponse: Result<RoutePlanResponse, APIError>!
    var mockGeocodeResponse: Result<GeocodeResponse, APIError>!
    
    // Keep track of how many times functions were called.
    var geocodeCallCount = 0
    var planRouteCallCount = 0
    
    func planRoute(origin: LocationInput?, destination: LocationInput, currentSoc: Int?) async -> Result<RoutePlanResponse, APIError> {
        planRouteCallCount += 1
        // Return the pre-configured mock response.
        return mockRoutePlanResponse
    }
    
    func geocode(address: String) async -> Result<GeocodeResponse, APIError> {
        geocodeCallCount += 1
        // Return the pre-configured mock response.
        return mockGeocodeResponse
    }
}
