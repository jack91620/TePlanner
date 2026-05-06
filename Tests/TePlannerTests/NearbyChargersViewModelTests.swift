import XCTest
@testable import TePlannerKit

@MainActor
final class NearbyChargersViewModelTests: XCTestCase {

    private func station(_ id: String, type: ChargingStationType = .supercharger) -> ChargingStation {
        ChargingStation(id: id, name: "Station \(id)", latitude: 39.9, longitude: 116.4, type: type)
    }

    func testLoadSuccessPopulatesList() async {
        let mock = MockAPIService()
        mock.mockNearbyStationsResponse = .success([station("1"), station("2")])
        let vm = NearbyChargersViewModel(apiService: mock)

        await vm.load(near: (39.9, 116.4))

        if case .loaded(let stations) = vm.state {
            XCTAssertEqual(stations.count, 2)
        } else {
            XCTFail("expected .loaded, got \(vm.state)")
        }
        XCTAssertEqual(mock.lastNearbyStationsArgs?.lat, 39.9)
        XCTAssertEqual(mock.lastNearbyStationsArgs?.radius, 30)
    }

    func testEmptyResponseMapsToEmpty() async {
        let mock = MockAPIService()
        mock.mockNearbyStationsResponse = .success([])
        let vm = NearbyChargersViewModel(apiService: mock)

        await vm.load(near: (39.9, 116.4))

        XCTAssertEqual(vm.state, .empty)
    }

    func testTypeFilterIsForwardedToAPI() async {
        let mock = MockAPIService()
        mock.mockNearbyStationsResponse = .success([])
        let vm = NearbyChargersViewModel(apiService: mock)
        vm.selectedType = .supercharger

        await vm.load(near: (39.9, 116.4))

        XCTAssertEqual(mock.lastNearbyStationsArgs?.type, "supercharger")
    }

    func testNoCoordinateFailsFast() async {
        let mock = MockAPIService()
        let vm = NearbyChargersViewModel(apiService: mock)

        await vm.load(near: nil)

        if case .error(let msg) = vm.state {
            XCTAssertTrue(msg.contains("位置"))
        } else {
            XCTFail("expected .error, got \(vm.state)")
        }
        XCTAssertEqual(mock.nearbyStationsCallCount, 0)
    }
}
