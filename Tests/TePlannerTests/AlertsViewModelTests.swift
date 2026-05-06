import XCTest
@testable import TePlannerKit

@MainActor
final class AlertsViewModelTests: XCTestCase {
    private var api: MockAPIService!
    private var settings: InMemorySettingsStore!
    private var clock: Date!

    override func setUp() async throws {
        api = MockAPIService()
        settings = InMemorySettingsStore()
        clock = Date(timeIntervalSince1970: 1_000_000)
    }

    private func makeVM() -> AlertsViewModel {
        AlertsViewModel(apiService: api, settings: settings, now: { [weak self] in
            self?.clock ?? Date()
        })
    }

    private func state(camp: Bool) -> VehicleState {
        VehicleState(
            vehicleId: "v1",
            displayName: "Tesla",
            state: "online",
            climateKeeperMode: camp ? 3 : 0
        )
    }

    func testNoAlertsWhenCampModeOff() {
        let vm = makeVM()
        vm.observe(state(camp: false))
        XCTAssertTrue(vm.alerts.isEmpty)
    }

    func testCampOnEmitsInfoAlertImmediately() {
        let vm = makeVM()
        vm.observe(state(camp: true))
        XCTAssertEqual(vm.alerts.count, 1)
        let alert = vm.alerts[0]
        XCTAssertEqual(alert.kind, .campMode)
        XCTAssertEqual(alert.severity, .info)
        XCTAssertNil(alert.primaryActionLabel, "no action button below threshold")
    }

    func testCampOnUpgradesToCriticalAfterThreshold() {
        settings.campModeReminderMinutes = 60  // 1h
        let vm = makeVM()
        vm.observe(state(camp: true))
        // Advance the clock past threshold
        clock = clock.addingTimeInterval(60 * 60 + 1)
        vm.recompute()

        XCTAssertEqual(vm.alerts.first?.severity, .critical)
        XCTAssertEqual(vm.alerts.first?.primaryActionLabel, "关闭")
    }

    func testCampOffClearsAlert() {
        let vm = makeVM()
        vm.observe(state(camp: true))
        XCTAssertEqual(vm.alerts.count, 1)

        vm.observe(state(camp: false))
        XCTAssertTrue(vm.alerts.isEmpty)
    }

    func testReObserveSameOnStateDoesNotResetTimestamp() {
        settings.campModeReminderMinutes = 60
        let vm = makeVM()
        vm.observe(state(camp: true))
        let firstStart = clock!

        clock = clock.addingTimeInterval(30 * 60)  // +30 min
        vm.observe(state(camp: true))  // still on
        // Advance again to past threshold from the original start.
        clock = clock.addingTimeInterval(31 * 60)  // total +61 min
        vm.recompute()

        XCTAssertEqual(vm.alerts.first?.severity, .critical, "duration should be measured from first-on, not most-recent observe")
        _ = firstStart  // silence unused warning
    }

    func testThresholdZeroDisablesCampReminder() {
        settings.campModeReminderMinutes = 0
        let vm = makeVM()
        vm.observe(state(camp: true))
        XCTAssertTrue(vm.alerts.isEmpty, "threshold = 0 should suppress the reminder entirely")
    }

    func testClearCampModeCallsAPIAndClearsAlert() async {
        let vm = makeVM()
        vm.observe(state(camp: true))
        XCTAssertEqual(vm.alerts.count, 1)

        api.mockSetClimateKeeperModeResponse = .success(BaseResponse(success: true, message: "ok"))
        let result = await vm.clearCampMode(vehicleId: "v1")

        if case .failure = result { XCTFail("expected success") }
        XCTAssertEqual(api.setClimateKeeperModeCallCount, 1)
        XCTAssertEqual(api.lastSetClimateKeeperModeArgs?.mode, 0)
        XCTAssertTrue(vm.alerts.isEmpty, "alert should clear optimistically on success")
    }

    func testClearCampModeKeepsAlertOnAPIFailure() async {
        let vm = makeVM()
        vm.observe(state(camp: true))

        api.mockSetClimateKeeperModeResponse = .failure(.serverError(statusCode: 503, message: "offline"))
        let result = await vm.clearCampMode(vehicleId: "v1")

        if case .success = result { XCTFail("expected failure") }
        XCTAssertEqual(vm.alerts.count, 1, "alert should stay so the user can retry")
    }
}
