import XCTest
@testable import TePlannerKit

@MainActor
final class RecentTripsViewModelTests: XCTestCase {

    private func endpoint(_ address: String) -> RouteEndpoint {
        RouteEndpoint(lat: 39.9, lng: 116.4, address: address)
    }

    private func trip(id: Int) -> RecentRoute {
        RecentRoute(
            id: id,
            origin: endpoint("起点 \(id)"),
            destination: endpoint("终点 \(id)"),
            totalDistanceKm: 120,
            totalDurationMinutes: 90,
            status: "completed",
            createdAt: "2026-05-06T10:00:00"
        )
    }

    func testLoadSuccessPopulatesTrips() async {
        let mock = MockAPIService()
        mock.mockRecentRoutesResponse = .success(RecentRoutesResponse(count: 2, routes: [trip(id: 1), trip(id: 2)]))
        let vm = RecentTripsViewModel(apiService: mock, pageSize: 5)

        await vm.load()

        if case .loaded(let trips) = vm.state {
            XCTAssertEqual(trips.count, 2)
            XCTAssertEqual(trips.first?.id, 1)
        } else {
            XCTFail("expected .loaded, got \(vm.state)")
        }
        XCTAssertEqual(mock.lastRecentRoutesArgs?.limit, 5)
        XCTAssertEqual(mock.lastRecentRoutesArgs?.offset, 0)
    }

    func testEmptyResponseMapsToEmpty() async {
        let mock = MockAPIService()
        mock.mockRecentRoutesResponse = .success(RecentRoutesResponse(count: 0, routes: []))
        let vm = RecentTripsViewModel(apiService: mock)

        await vm.load()

        XCTAssertEqual(vm.state, .empty)
    }

    func testFailureSurfacesError() async {
        let mock = MockAPIService()
        mock.mockRecentRoutesResponse = .failure(.serverError(statusCode: 401, message: "Not authenticated"))
        let vm = RecentTripsViewModel(apiService: mock)

        await vm.load()

        if case .error(let msg) = vm.state {
            XCTAssertTrue(msg.contains("401"))
        } else {
            XCTFail("expected .error, got \(vm.state)")
        }
    }
}
