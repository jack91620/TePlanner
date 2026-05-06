import XCTest
@testable import TePlannerKit

@MainActor
final class RoutePreviewViewModelTests: XCTestCase {

    private func makePOI() -> POIResult {
        POIResult(id: "p1", name: "故宫", address: "景山前街4号", latitude: 39.916, longitude: 116.397)
    }

    private func makePlan(stops: Int = 1) -> RoutePlanResponse {
        let chargingStops: [ChargingStop] = (0..<stops).map {
            ChargingStop(
                stationId: "s\($0)",
                name: "充电站\($0)",
                latitude: 39.9 + Double($0) * 0.01,
                longitude: 116.4 + Double($0) * 0.01,
                address: "addr\($0)",
                operatorName: "Tesla",
                distanceFromStartKm: 50 * Double($0 + 1),
                arrivalSoc: 25,
                departureSoc: 80,
                chargingDurationMinutes: 30
            )
        }
        return RoutePlanResponse(
            routeId: 42,
            origin: LocationDetail(lat: 39.9, lng: 116.3, name: "起点"),
            destination: LocationDetail(lat: 39.916, lng: 116.397, name: "故宫"),
            totalDistanceKm: 120.0,
            totalDurationMinutes: 150,
            drivingDurationMinutes: 120,
            chargingDurationMinutes: 30,
            chargingStops: chargingStops,
            numChargingStops: stops,
            initialSoc: 60,
            arrivalSoc: 35,
            polyline: [Coordinate(latitude: 39.9, longitude: 116.3),
                       Coordinate(latitude: 39.916, longitude: 116.397)],
            warnings: []
        )
    }

    func testInitialStateIsLoading() {
        let mock = MockAPIService()
        let vm = RoutePreviewViewModel(
            apiService: mock,
            destination: makePOI(),
            origin: nil,
            currentSoc: 50,
            vehicleId: "v1"
        )
        XCTAssertEqual(vm.state, .loading)
        XCTAssertEqual(vm.sendState, .idle)
    }

    func testLoadSuccessPopulatesPlan() async {
        let mock = MockAPIService()
        mock.mockRoutePlanResponse = .success(makePlan(stops: 2))
        let vm = RoutePreviewViewModel(
            apiService: mock,
            destination: makePOI(),
            origin: LocationInput(latitude: 39.9, longitude: 116.3, address: nil),
            currentSoc: 60,
            vehicleId: "v1"
        )

        await vm.load()

        if case .loaded(let plan) = vm.state {
            XCTAssertEqual(plan.routeId, 42)
            XCTAssertEqual(plan.numChargingStops, 2)
        } else {
            XCTFail("expected .loaded, got \(vm.state)")
        }
        XCTAssertEqual(mock.planRouteCallCount, 1)
    }

    func testOnPlanLoadedCallbackFiresOnSuccess() async {
        let mock = MockAPIService()
        mock.mockRoutePlanResponse = .success(makePlan(stops: 1))
        var received: RoutePlanResponse?
        let vm = RoutePreviewViewModel(
            apiService: mock,
            destination: makePOI(),
            origin: nil,
            currentSoc: 60,
            vehicleId: "v1",
            onPlanLoaded: { received = $0 }
        )

        await vm.load()

        XCTAssertEqual(received?.routeId, 42)
        XCTAssertEqual(received?.numChargingStops, 1)
    }

    func testOnPlanLoadedCallbackSkippedOnFailure() async {
        let mock = MockAPIService()
        mock.mockRoutePlanResponse = .failure(.serverError(statusCode: 500, message: "boom"))
        var fired = false
        let vm = RoutePreviewViewModel(
            apiService: mock,
            destination: makePOI(),
            origin: nil,
            currentSoc: 60,
            vehicleId: "v1",
            onPlanLoaded: { _ in fired = true }
        )

        await vm.load()

        XCTAssertFalse(fired, "callback should not fire on failure")
    }

    func testLoadFailureMapsToError() async {
        let mock = MockAPIService()
        mock.mockRoutePlanResponse = .failure(.serverError(statusCode: 503, message: "no network"))
        let vm = RoutePreviewViewModel(
            apiService: mock,
            destination: makePOI(),
            origin: nil,
            currentSoc: 80,
            vehicleId: nil
        )

        await vm.load()

        if case .error(let msg) = vm.state {
            XCTAssertTrue(msg.contains("network"))
        } else {
            XCTFail("expected .error, got \(vm.state)")
        }
    }

    func testSendToVehicleHappyPath() async {
        let mock = MockAPIService()
        mock.mockRoutePlanResponse = .success(makePlan())
        mock.mockSendNavigationResponse = .success(BaseResponse(success: true, message: "ok"))
        let vm = RoutePreviewViewModel(
            apiService: mock,
            destination: makePOI(),
            origin: nil,
            currentSoc: 50,
            vehicleId: "366691338664104"
        )
        await vm.load()
        await vm.sendToVehicle()

        XCTAssertEqual(vm.sendState, .sent)
        XCTAssertEqual(mock.sendNavigationCallCount, 1)
    }

    func testSendToVehicleWithoutVehicleIdFails() async {
        let mock = MockAPIService()
        mock.mockRoutePlanResponse = .success(makePlan())
        let vm = RoutePreviewViewModel(
            apiService: mock,
            destination: makePOI(),
            origin: nil,
            currentSoc: 50,
            vehicleId: nil
        )
        await vm.sendToVehicle()

        if case .failed(let msg) = vm.sendState {
            XCTAssertEqual(msg, "未选择车辆")
        } else {
            XCTFail("expected .failed, got \(vm.sendState)")
        }
        XCTAssertEqual(mock.sendNavigationCallCount, 0)
    }

    func testSendFailureSurfacesMessage() async {
        let mock = MockAPIService()
        mock.mockRoutePlanResponse = .success(makePlan())
        mock.mockSendNavigationResponse = .failure(.serverError(statusCode: 503, message: "vehicle offline"))
        let vm = RoutePreviewViewModel(
            apiService: mock,
            destination: makePOI(),
            origin: nil,
            currentSoc: 50,
            vehicleId: "v1"
        )
        await vm.sendToVehicle()

        if case .failed(let msg) = vm.sendState {
            XCTAssertTrue(msg.contains("offline"))
        } else {
            XCTFail("expected .failed, got \(vm.sendState)")
        }
    }
}
