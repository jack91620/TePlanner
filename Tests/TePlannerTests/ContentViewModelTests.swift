import XCTest
@testable import TePlannerKit

@MainActor // Ensure the entire test class runs on the MainActor, like the ViewModel
final class ContentViewModelTests: XCTestCase {

    var viewModel: ContentViewModel!
    var mockAPIService: MockAPIService!

    override func setUp() {
        super.setUp()
        mockAPIService = MockAPIService()
        viewModel = ContentViewModel(apiService: mockAPIService)
    }

    override func tearDown() {
        viewModel = nil
        mockAPIService = nil
        super.tearDown()
    }

    func testPlanRoute_WithAddress_Success() async {
        viewModel.destination = "Shanghai"
        mockAPIService.mockGeocodeResponse = .success(GeocodeResponse(latitude: 31.2304, longitude: 121.4737, address: "Shanghai", formattedAddress: "Shanghai, China"))
        mockAPIService.mockRoutePlanResponse = .success(createMockRoutePlan())

        await viewModel.planRoute()

        XCTAssertNil(viewModel.errorMessage, "Error message should be nil on success")
        XCTAssertNotNil(viewModel.routePlan, "Route plan should not be nil on success")
        XCTAssertEqual(viewModel.routePlan?.destination.name, "Shanghai", "The destination name should match the mock data")
    }
    
    func testPlanRoute_WithAddress_GeocodingFails() async {
        viewModel.destination = "Invalid Address"
        mockAPIService.mockGeocodeResponse = .failure(.serverError(statusCode: 404, message: "Address not found"))
        
        await viewModel.planRoute()
        
        XCTAssertNotNil(viewModel.errorMessage, "Error message should not be nil on geocoding failure")
        XCTAssertNil(viewModel.routePlan, "Route plan should be nil on failure")
        XCTAssertTrue(viewModel.errorMessage?.contains("Address not found") ?? false, "Error message should indicate geocoding failed")
    }

    func testPlanRoute_WithAddress_PlanningFails() async {
        viewModel.destination = "Shanghai"
        mockAPIService.mockGeocodeResponse = .success(GeocodeResponse(latitude: 31.2304, longitude: 121.4737, address: "Shanghai", formattedAddress: "Shanghai, China"))
        mockAPIService.mockRoutePlanResponse = .failure(.serverError(statusCode: 500, message: "Internal planning error"))
        
        await viewModel.planRoute()
        
        XCTAssertNotNil(viewModel.errorMessage, "Error message should not be nil on planning failure")
        XCTAssertNil(viewModel.routePlan, "Route plan should be nil on failure")
        XCTAssertTrue(viewModel.errorMessage?.contains("Internal planning error") ?? false, "Error message should indicate planning failed")
    }
    
    func testPlanRoute_WithCoordinates_Success() async {
        viewModel.origin = "39.9042,116.4074" // Make sure origin is also coordinates to avoid geocoding
        viewModel.destination = "31.2304,121.4737"
        mockAPIService.mockRoutePlanResponse = .success(createMockRoutePlan())
        
        await viewModel.planRoute()

        XCTAssertEqual(mockAPIService.geocodeCallCount, 0, "Geocode should not be called when coordinates are provided")
        XCTAssertNotNil(viewModel.routePlan, "Route plan should be successful with coordinates")
        XCTAssertNil(viewModel.errorMessage, "There should be no error when using coordinates")
    }

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
