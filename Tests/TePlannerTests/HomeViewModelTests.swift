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
}

