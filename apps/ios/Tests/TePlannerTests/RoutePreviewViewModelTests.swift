import XCTest
@testable import TePlannerKit

@MainActor
final class RoutePreviewViewModelTests: XCTestCase {

    private func makePOI() -> POIResult {
        POIResult(id: "p1", name: "故宫", address: "景山前街4号", latitude: 39.916, longitude: 116.397)
    }

    private func origin() -> LocationInput {
        LocationInput(latitude: 39.9, longitude: 116.3, address: nil)
    }

    /// 8.2 orchestration test fixture: stub /routes/route, the SDK
    /// alongby provider, and /routes/charging-plan in a single call
    /// so each test can opt into success/failure on each step.
    private func wireMock(
        mock: MockAPIService,
        routeStops: Int = 2,
        chargingStops: Int = 2,
        routeFails: Bool = false,
        chargingFails: Bool = false,
        chargingFailsMessage: String = ""
    ) {
        mock.mockRouteOnlyResponse = routeFails
            ? .failure(.serverError(statusCode: 503, message: "no network"))
            : .success(RouteOnlyResponse(
                origin: LocationDetail(lat: 39.9, lng: 116.3, name: "起点"),
                destination: LocationDetail(lat: 39.916, lng: 116.397, name: "故宫"),
                totalDistanceKm: 120,
                drivingDurationMinutes: 120,
                polyline: [
                    Coordinate(latitude: 39.9, longitude: 116.3),
                    Coordinate(latitude: 39.916, longitude: 116.397),
                ]
            ))

        let stops: [ChargingStop] = (0..<chargingStops).map {
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
        mock.mockChargingPlanResponse = chargingFails
            ? .failure(.serverError(statusCode: 500, message: chargingFailsMessage))
            : .success(ChargingPlanResponse(
                chargingStops: stops,
                numChargingStops: stops.count,
                chargingDurationMinutes: 30 * stops.count,
                arrivalSoc: 35,
                warnings: []
            ))
    }

    /// In-memory POI provider for tests — no SDK dependency.
    private final class StubPOIProvider: AlongRoutePOIProvider, @unchecked Sendable {
        var pois: [AlongRoutePOI]
        var error: Error?
        var callCount = 0
        init(pois: [AlongRoutePOI] = [], error: Error? = nil) {
            self.pois = pois
            self.error = error
        }
        func searchChargingStations(polyline: [Coordinate]) async throws -> [AlongRoutePOI] {
            callCount += 1
            if let error { throw error }
            return pois
        }
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
        wireMock(mock: mock)
        let stub = StubPOIProvider(pois: [
            AlongRoutePOI(id: "x1", name: "服务区充电站", latitude: 39.91, longitude: 116.35),
        ])
        let vm = RoutePreviewViewModel(
            apiService: mock,
            poiProvider: stub,
            destination: makePOI(),
            origin: origin(),
            currentSoc: 60,
            vehicleId: "v1"
        )

        await vm.load()

        if case .loaded(let plan) = vm.state {
            XCTAssertEqual(plan.numChargingStops, 2)
            XCTAssertEqual(plan.totalDistanceKm, 120)
        } else {
            XCTFail("expected .loaded, got \(vm.state)")
        }
        XCTAssertEqual(mock.routeOnlyCallCount, 1)
        XCTAssertEqual(stub.callCount, 1, "iOS SDK alongby must be called between route + charging-plan")
        XCTAssertEqual(mock.chargingPlanCallCount, 1)
    }

    func testOnPlanLoadedCallbackFiresOnSuccess() async {
        let mock = MockAPIService()
        wireMock(mock: mock, chargingStops: 1)
        var received: RoutePlanResponse?
        let vm = RoutePreviewViewModel(
            apiService: mock,
            poiProvider: StubPOIProvider(),
            destination: makePOI(),
            origin: origin(),
            currentSoc: 60,
            vehicleId: "v1",
            onPlanLoaded: { received = $0 }
        )

        await vm.load()

        XCTAssertEqual(received?.numChargingStops, 1)
    }

    func testOnPlanLoadedCallbackSkippedOnRouteFailure() async {
        let mock = MockAPIService()
        wireMock(mock: mock, routeFails: true)
        var fired = false
        let vm = RoutePreviewViewModel(
            apiService: mock,
            poiProvider: StubPOIProvider(),
            destination: makePOI(),
            origin: origin(),
            currentSoc: 60,
            vehicleId: "v1",
            onPlanLoaded: { _ in fired = true }
        )

        await vm.load()

        XCTAssertFalse(fired, "callback should not fire on failure")
        XCTAssertEqual(mock.chargingPlanCallCount, 0,
                       "charging-plan must not be called when /routes/route fails")
    }

    func testRouteFailureMapsToError() async {
        let mock = MockAPIService()
        wireMock(mock: mock, routeFails: true)
        let vm = RoutePreviewViewModel(
            apiService: mock,
            poiProvider: StubPOIProvider(),
            destination: makePOI(),
            origin: origin(),
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

    func testPOIProviderFailureMapsToError() async {
        // Phase 8.2 fail-fast: SDK alongby errors propagate to the
        // user instead of silently falling back to backend sampling.
        let mock = MockAPIService()
        wireMock(mock: mock)
        struct AlongbyFailure: Error, LocalizedError {
            var errorDescription: String? { "SDK timeout" }
        }
        let stub = StubPOIProvider(error: AlongbyFailure())
        let vm = RoutePreviewViewModel(
            apiService: mock,
            poiProvider: stub,
            destination: makePOI(),
            origin: origin(),
            currentSoc: 60,
            vehicleId: "v1"
        )

        await vm.load()

        if case .error(let msg) = vm.state {
            XCTAssertTrue(msg.contains("SDK timeout") || msg.contains("沿途"))
        } else {
            XCTFail("expected .error from SDK failure, got \(vm.state)")
        }
        XCTAssertEqual(mock.chargingPlanCallCount, 0, "charging-plan skipped on alongby fail")
    }

    func testNoOriginFailsFast() async {
        // No vehicle position → can't compute a route. Don't even hit
        // the API; surface a clear error.
        let mock = MockAPIService()
        wireMock(mock: mock)
        let vm = RoutePreviewViewModel(
            apiService: mock,
            poiProvider: StubPOIProvider(),
            destination: makePOI(),
            origin: nil,
            currentSoc: 60,
            vehicleId: "v1"
        )

        await vm.load()

        if case .error(let msg) = vm.state {
            XCTAssertTrue(msg.contains("车辆位置"))
        } else {
            XCTFail("expected .error, got \(vm.state)")
        }
        XCTAssertEqual(mock.routeOnlyCallCount, 0)
    }

    func testSendToVehicleHappyPath() async {
        let mock = MockAPIService()
        wireMock(mock: mock)
        mock.mockSendNavigationResponse = .success(BaseResponse(success: true, message: "ok"))
        let vm = RoutePreviewViewModel(
            apiService: mock,
            poiProvider: StubPOIProvider(),
            destination: makePOI(),
            origin: origin(),
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
        wireMock(mock: mock)
        let vm = RoutePreviewViewModel(
            apiService: mock,
            poiProvider: StubPOIProvider(),
            destination: makePOI(),
            origin: origin(),
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
        wireMock(mock: mock)
        mock.mockSendNavigationResponse = .failure(.serverError(statusCode: 503, message: "vehicle offline"))
        let vm = RoutePreviewViewModel(
            apiService: mock,
            poiProvider: StubPOIProvider(),
            destination: makePOI(),
            origin: origin(),
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

    // MARK: - Save-to-history on successful send
    //
    // Bug context: the 最近 tab was empty for every user because
    // nothing wrote route_plans server-side. iOS now fires a save
    // call right after sendNavigation succeeds. These tests pin
    // that contract so a future refactor can't silently drop it.

    func testSendSuccess_savesRouteToHistory() async {
        let mock = MockAPIService()
        wireMock(mock: mock)
        mock.mockSendNavigationResponse = .success(BaseResponse(success: true, message: "ok"))
        let vm = RoutePreviewViewModel(
            apiService: mock,
            poiProvider: StubPOIProvider(),
            destination: makePOI(),
            origin: origin(),
            currentSoc: 50,
            vehicleId: "v1"
        )
        await vm.load()
        await vm.sendToVehicle()

        // The save runs in a fire-and-forget Task. Yield long enough
        // for the awaited mock call to land.
        for _ in 0..<10 where mock.lastSaveRoutePlanRequest == nil {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertNotNil(mock.lastSaveRoutePlanRequest, "save not called after successful send")

        let saved = mock.lastSaveRoutePlanRequest!
        XCTAssertEqual(saved.destination.address, "故宫")
        // Origin lat/lng came from the loaded plan's origin block
        // (filled by /routes/route response), NOT the bare origin
        // input. Both should round to the mocked 39.9 / 116.3.
        XCTAssertEqual(saved.origin.latitude, 39.9, accuracy: 0.01)
        XCTAssertEqual(saved.origin.longitude, 116.3, accuracy: 0.01)
        XCTAssertEqual(saved.totalDistanceKm ?? -1, 120, accuracy: 0.01)
    }

    func testSendFailure_doesNotSaveRoute() async {
        let mock = MockAPIService()
        wireMock(mock: mock)
        mock.mockSendNavigationResponse = .failure(.serverError(statusCode: 503, message: "offline"))
        let vm = RoutePreviewViewModel(
            apiService: mock,
            poiProvider: StubPOIProvider(),
            destination: makePOI(),
            origin: origin(),
            currentSoc: 50,
            vehicleId: "v1"
        )
        await vm.load()
        await vm.sendToVehicle()

        // Give any spurious save task a chance to surface.
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertNil(mock.lastSaveRoutePlanRequest,
                     "save must not fire when the Tesla nav command itself failed — would leave a misleading row in 最近 that the car never actually navigated to")
    }
}
