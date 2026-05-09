import XCTest
@testable import TePlannerKit

@MainActor
final class HomeViewModelTests: XCTestCase {
    private var api: MockAPIService!
    private var storage: InMemorySecureStorage!
    private var settings: InMemorySettingsStore!
    private var session: AuthSession!

    override func setUp() async throws {
        api = MockAPIService()
        storage = InMemorySecureStorage()
        settings = InMemorySettingsStore()
        session = AuthSession(secureStorage: storage, settings: settings)
        // Pretend we already authenticated.
        session.login(token: "tok", refreshToken: nil, userId: "15")
    }

    private func makeVM(maxAttempts: Int = 3) -> HomeViewModel {
        HomeViewModel(
            apiService: api,
            authSession: session,
            maxWakeAttempts: maxAttempts,
            wakeRetryDelay: 0  // 0 → no real sleeping in tests
        )
    }

    // MARK: - happy path

    func testLoadPicksPrimaryAndPopulatesState() async {
        api.mockVehiclesResponse = .success(VehiclesResponse(count: 2, vehicles: [
            Vehicle(id: "v1", displayName: "B"),
            Vehicle(id: "v2", displayName: "A", isPrimary: true)
        ]))
        api.mockVehicleStateResponse = .success(VehicleState(
            vehicleId: "v2",
            displayName: "A",
            state: "online",
            batteryLevel: 80,
            batteryRange: 320.5,
            latitude: 31.2,
            longitude: 121.4
        ))
        let vm = makeVM()

        await vm.load()

        XCTAssertEqual(vm.state, .ready)
        XCTAssertEqual(vm.vehicle?.id, "v2")
        XCTAssertEqual(vm.batteryLevel, 80)
        XCTAssertEqual(vm.batteryRangeKm, 320.5)
        XCTAssertEqual(vm.coordinate?.latitude, 31.2)
        XCTAssertEqual(vm.displayName, "A")
    }

    func testLoadFallsBackToFirstWhenNoPrimary() async {
        api.mockVehiclesResponse = .success(VehiclesResponse(count: 1, vehicles: [
            Vehicle(id: "only", displayName: "X")
        ]))
        api.mockVehicleStateResponse = .success(VehicleState(vehicleId: "only", batteryLevel: 50))

        let vm = makeVM()
        await vm.load()
        XCTAssertEqual(vm.vehicle?.id, "only")
        XCTAssertEqual(vm.state, .ready)
    }

    // MARK: - error paths

    func testLoadWithoutLoginReportsError() async {
        session.logout()
        let vm = makeVM()
        await vm.load()
        guard case .error(let msg) = vm.state else {
            return XCTFail("Expected .error, got \(vm.state)")
        }
        XCTAssertEqual(msg, "未登录")
    }

    func testLoadWithEmptyVehicleListReportsError() async {
        api.mockVehiclesResponse = .success(VehiclesResponse(count: 0, vehicles: []))
        let vm = makeVM()
        await vm.load()
        guard case .error = vm.state else {
            return XCTFail("Expected .error, got \(vm.state)")
        }
    }

    func testLoadPropagatesAPIError() async {
        api.mockVehiclesResponse = .failure(.invalidURL)
        let vm = makeVM()
        await vm.load()
        guard case .error = vm.state else {
            return XCTFail("Expected .error, got \(vm.state)")
        }
    }

    // MARK: - wake / retry

    func testWakeSucceedsOnSecondPoll() async {
        api.mockVehiclesResponse = .success(VehiclesResponse(count: 1, vehicles: [
            Vehicle(id: "v1", displayName: "A")
        ]))
        // Queue: initial probe fails, retry 1 still asleep, retry 2 online.
        api.mockVehicleStateSequence = [
            .failure(.invalidResponse),
            .failure(.invalidResponse),
            .success(VehicleState(vehicleId: "v1", batteryLevel: 60))
        ]
        api.mockWakeVehicleResponse = .success(WakeResponse(vehicleId: "v1", state: "online", message: nil))

        let vm = makeVM(maxAttempts: 5)
        await vm.load()

        XCTAssertEqual(vm.state, .ready)
        XCTAssertEqual(vm.batteryLevel, 60)
        XCTAssertEqual(api.wakeVehicleCallCount, 1)
        XCTAssertEqual(api.getVehicleStateCallCount, 3)
    }

    func testWakeGivingUpAfterMaxAttemptsTransitionsToOffline() async {
        api.mockVehiclesResponse = .success(VehiclesResponse(count: 1, vehicles: [
            Vehicle(id: "v1", displayName: "A")
        ]))
        api.mockVehicleStateResponse = .failure(.invalidResponse)
        api.mockWakeVehicleResponse = .success(WakeResponse(vehicleId: "v1", state: "offline", message: nil))

        let vm = makeVM(maxAttempts: 3)
        await vm.load()

        XCTAssertEqual(vm.state, .offline)
        XCTAssertEqual(api.wakeVehicleCallCount, 1)
        // 1 initial probe + 3 retries = 4 calls.
        XCTAssertEqual(api.getVehicleStateCallCount, 4)
    }

    // MARK: - polling

    private func loadedVM() async -> HomeViewModel {
        api.mockVehiclesResponse = .success(VehiclesResponse(count: 1, vehicles: [
            Vehicle(id: "v1", displayName: "Tesla", isPrimary: true)
        ]))
        api.mockVehicleStateResponse = .success(VehicleState(
            vehicleId: "v1",
            displayName: "Tesla",
            state: "online",
            batteryLevel: 70,
            batteryRange: 300,
            latitude: 39.9,
            longitude: 116.4
        ))
        let vm = HomeViewModel(
            apiService: api,
            authSession: session,
            maxWakeAttempts: 1,
            wakeRetryDelay: 0,
            pollInterval: 0  // disable real timer; we drive pollOnce manually
        )
        await vm.load()
        return vm
    }

    func testPollOnceUpdatesVehicleState() async {
        let vm = await loadedVM()
        let before = api.getVehicleStateCallCount

        api.mockVehicleStateResponse = .success(VehicleState(
            vehicleId: "v1",
            displayName: "Tesla",
            state: "online",
            batteryLevel: 65,
            batteryRange: 280,
            latitude: 40.0,
            longitude: 116.5
        ))
        await vm.pollOnce()

        XCTAssertEqual(api.getVehicleStateCallCount, before + 1)
        XCTAssertEqual(vm.batteryLevel, 65)
        XCTAssertEqual(vm.coordinate?.latitude, 40.0)
    }

    func testPollOnceSkipsWhenNotReady() async {
        let vm = HomeViewModel(
            apiService: api,
            authSession: session,
            pollInterval: 0
        )
        // state is .idle — never loaded.
        await vm.pollOnce()
        XCTAssertEqual(api.getVehicleStateCallCount, 0)
    }

    func testPollOnceTolersErrorWithoutChangingState() async {
        let vm = await loadedVM()
        api.mockVehicleStateResponse = .failure(.serverError(statusCode: 503, message: "offline"))

        await vm.pollOnce()

        // .ready preserved, vehicleState NOT wiped.
        XCTAssertEqual(vm.state, .ready)
        XCTAssertEqual(vm.batteryLevel, 70, "old data should still be on screen after a poll error")
    }

    func testStartPollingFiresRepeatedlyAtSetInterval() async {
        api.mockVehiclesResponse = .success(VehiclesResponse(count: 1, vehicles: [
            Vehicle(id: "v1", displayName: "Tesla", isPrimary: true)
        ]))
        api.mockVehicleStateResponse = .success(VehicleState(
            vehicleId: "v1",
            displayName: "Tesla",
            state: "online",
            batteryLevel: 70,
            batteryRange: 300,
            latitude: 39.9,
            longitude: 116.4
        ))
        let vm = HomeViewModel(
            apiService: api,
            authSession: session,
            maxWakeAttempts: 1,
            wakeRetryDelay: 0,
            pollInterval: 0.05  // 50ms
        )
        await vm.load()
        let before = api.getVehicleStateCallCount

        vm.startPolling()
        try? await Task.sleep(nanoseconds: 200_000_000)  // 0.2s ≈ 3-4 ticks
        vm.stopPolling()

        let after = api.getVehicleStateCallCount
        XCTAssertGreaterThanOrEqual(after - before, 2, "expected at least 2 polls in 0.2s with a 50ms interval")
    }

    func testInitialLoadFetchesLocationName() async {
        api.mockVehiclesResponse = .success(VehiclesResponse(count: 1, vehicles: [
            Vehicle(id: "v1", displayName: "Tesla", isPrimary: true)
        ]))
        api.mockVehicleStateResponse = .success(VehicleState(
            vehicleId: "v1", displayName: "Tesla", state: "online",
            batteryLevel: 70, batteryRange: 300, latitude: 39.92, longitude: 116.4
        ))
        api.mockReverseGeocodeResponse = .success(ReverseGeocodeResponse(
            latitude: 39.92, longitude: 116.4,
            address: "北京市东城区天安门广场",
            formattedAddress: "北京市东城区"
        ))
        let vm = makeVM()

        await vm.load()

        XCTAssertEqual(vm.locationName, "北京市东城区")
        XCTAssertEqual(api.lastReverseGeocodeArgs?.lat, 39.92)
    }

    func testReverseGeocodeFailureLeavesLocationNameNil() async {
        api.mockVehiclesResponse = .success(VehiclesResponse(count: 1, vehicles: [
            Vehicle(id: "v1", displayName: "Tesla", isPrimary: true)
        ]))
        api.mockVehicleStateResponse = .success(VehicleState(
            vehicleId: "v1", displayName: "Tesla", state: "online",
            batteryLevel: 70, batteryRange: 300, latitude: 39.92, longitude: 116.4
        ))
        api.mockReverseGeocodeResponse = .failure(.serverError(statusCode: 500, message: "boom"))
        let vm = makeVM()

        await vm.load()

        // .ready set, just no location name (failure tolerated).
        XCTAssertEqual(vm.state, .ready)
        XCTAssertNil(vm.locationName)
    }

    func testStopPollingHaltsRequests() async {
        api.mockVehiclesResponse = .success(VehiclesResponse(count: 1, vehicles: [
            Vehicle(id: "v1", displayName: "Tesla", isPrimary: true)
        ]))
        api.mockVehicleStateResponse = .success(VehicleState(
            vehicleId: "v1", displayName: "Tesla", state: "online",
            batteryLevel: 70, batteryRange: 300, latitude: 39.9, longitude: 116.4
        ))
        let vm = HomeViewModel(
            apiService: api,
            authSession: session,
            maxWakeAttempts: 1,
            wakeRetryDelay: 0,
            pollInterval: 0.05
        )
        await vm.load()
        vm.startPolling()
        try? await Task.sleep(nanoseconds: 100_000_000)
        vm.stopPolling()
        let stoppedAt = api.getVehicleStateCallCount

        try? await Task.sleep(nanoseconds: 200_000_000)
        // A single in-flight pollOnce call started before stopPolling
        // can finish *after* the cancel signal fires (the await keeps
        // running until pollOnce returns). What we're verifying is
        // that no *new* polls keep firing on the interval clock.
        XCTAssertLessThanOrEqual(
            api.getVehicleStateCallCount - stoppedAt,
            1,
            "no new polls should fire after stopPolling() (one in-flight tolerated)"
        )
    }
}

