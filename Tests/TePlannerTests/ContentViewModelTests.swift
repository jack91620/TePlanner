import XCTest
@testable import TePlannerKit // Import the new library module to access its code

// Unit Tests for the ContentViewModel
final class ContentViewModelTests: XCTestCase {

    var viewModel: ContentViewModel!
    var mockAPIService: MockAPIService!

    override func setUp() {
        super.setUp()
        // This method is called before each test.
        // We create a fresh ViewModel and a mock service for each test to ensure they are isolated.
        mockAPIService = MockAPIService()
        viewModel = ContentViewModel(apiService: mockAPIService)
    }

    override func tearDown() {
        // This method is called after each test.
        viewModel = nil
        mockAPIService = nil
        super.tearDown()
    }

    // Test case 1: Successful route planning with a text address
    func testPlanRoute_WithAddress_Success() async {
        // Given: A destination address and a successful mock response
        viewModel.destination = "Shanghai"
        mockAPIService.mockGeocodeResponse = .success(GeocodeResponse(latitude: 31.2304, longitude: 121.4737, address: "Shanghai", formattedAddress: "Shanghai, China"))
        mockAPIService.mockRoutePlanResponse = .success(createMockRoutePlan())

        // When: The planRoute function is called
        await viewModel.planRoute()

        // Then: The ViewModel should not have an error message and should contain the route plan
        XCTAssertNil(viewModel.errorMessage, "Error message should be nil on success")
        XCTAssertNotNil(viewModel.routePlan, "Route plan should not be nil on success")
        XCTAssertEqual(viewModel.routePlan?.destination.name, "Shanghai", "The destination name should match the mock data")
    }
    
    // Test case 2: Route planning fails during geocoding
    func testPlanRoute_WithAddress_GeocodingFails() async {
        // Given: An address that will cause a geocoding failure
        viewModel.destination = "Invalid Address"
        mockAPIService.mockGeocodeResponse = .failure(.serverError(statusCode: 404, message: "Address not found"))
        
        // When: The planRoute function is called
        await viewModel.planRoute()
        
        // Then: The ViewModel should have an error message and no route plan
        XCTAssertNotNil(viewModel.errorMessage, "Error message should not be nil on geocoding failure")
        XCTAssertNil(viewModel.routePlan, "Route plan should be nil on failure")
        XCTAssertTrue(viewModel.errorMessage?.contains("Address not found") ?? false, "Error message should indicate geocoding failed")
    }

    // Test case 3: Route planning fails at the planning stage (after successful geocoding)
    func testPlanRoute_WithAddress_PlanningFails() async {
        // Given: A valid address but the route planning itself will fail
        viewModel.destination = "Shanghai"
        mockAPIService.mockGeocodeResponse = .success(GeocodeResponse(latitude: 31.2304, longitude: 121.4737, address: "Shanghai", formattedAddress: "Shanghai, China"))
        mockAPIService.mockRoutePlanResponse = .failure(.serverError(statusCode: 500, message: "Internal planning error"))
        
        // When: The planRoute function is called
        await viewModel.planRoute()
        
        // Then: The ViewModel should have an error message and no route plan
        XCTAssertNotNil(viewModel.errorMessage, "Error message should not be nil on planning failure")
        XCTAssertNil(viewModel.routePlan, "Route plan should be nil on failure")
        XCTAssertTrue(viewModel.errorMessage?.contains("Internal planning error") ?? false, "Error message should indicate planning failed")
    }
    
    // Test case 4: Successful route planning with coordinates
    func testPlanRoute_WithCoordinates_Success() async {
        // Given: A destination as coordinates
        viewModel.destination = "31.2304,121.4737"
        mockAPIService.mockRoutePlanResponse = .success(createMockRoutePlan())
        
        // When: The planRoute function is called
        await viewModel.planRoute()

        // Then: The geocode function should not have been called, and the plan should be successful
        XCTAssertEqual(mockAPIService.geocodeCallCount, 0, "Geocode should not be called when coordinates are provided")
        XCTAssertNotNil(viewModel.routePlan, "Route plan should be successful with coordinates")
        XCTAssertNil(viewModel.errorMessage, "There should be no error when using coordinates")
    }

    // Helper function to create mock data for a successful route plan
    private func createMockRoutePlan() -> RoutePlanResponse {
        return RoutePlanResponse(
            routeId: 1,
            origin: LocationDetail(lat: 39.9042, lng: 116.4074, name: "Beijing"),
            destination: LocationDetail(lat: 31.2304, lng: 121.4737, name: "Shanghai"),
            totalDistanceKm: 1200, totalDurationMinutes: 960, drivingDurationMinutes: 840, chargingDurationMinutes: 120,
            chargingStops: [], numChargingStops: 0, initialSoc: 80, arrivalSoc: 20, polyline: [], warnings: []
        )
    }
}
