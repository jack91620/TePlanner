import XCTest
@testable import TePlannerKit

@MainActor
final class AutomationEngineTests: XCTestCase {
    private var api: MockAPIService!
    private var settings: InMemorySettingsStore!
    private var memory: InMemoryAutomationStateMemory!
    private var clock: Date!

    override func setUp() async throws {
        api = MockAPIService()
        settings = InMemorySettingsStore()
        memory = InMemoryAutomationStateMemory()
        clock = Date(timeIntervalSince1970: 1_000_000)
    }

    private func makeEngine(rules: [any Automation] = [CampModeAutomation()]) -> AutomationEngine {
        AutomationEngine(
            registry: rules,
            apiService: api,
            settings: settings,
            memory: memory,
            now: { [weak self] in self?.clock ?? Date() }
        )
    }

    private func state(camp: Bool, vehicleId: String = "v1") -> VehicleState {
        VehicleState(
            vehicleId: vehicleId,
            displayName: "Tesla",
            state: "online",
            climateKeeperMode: camp ? 3 : 0
        )
    }

    // MARK: - camp mode behavior (preserves AlertsViewModel coverage)

    func testNoAlertsWhenCampModeOff() {
        let engine = makeEngine()
        engine.observe(state(camp: false))
        XCTAssertTrue(engine.alerts.isEmpty)
    }

    func testCampOnEmitsInfoAlertImmediately() {
        let engine = makeEngine()
        engine.observe(state(camp: true))
        XCTAssertEqual(engine.alerts.count, 1)
        let alert = engine.alerts[0]
        XCTAssertEqual(alert.kind, .campMode)
        XCTAssertEqual(alert.severity, .info)
        XCTAssertNil(alert.primaryActionLabel, "no action button below threshold")
    }

    func testCampOnUpgradesToCriticalAfterThreshold() {
        settings.campModeReminderMinutes = 60
        let engine = makeEngine()
        engine.observe(state(camp: true))

        clock = clock.addingTimeInterval(60 * 60 + 1)
        engine.recompute()

        XCTAssertEqual(engine.alerts.first?.severity, .critical)
        XCTAssertEqual(engine.alerts.first?.primaryActionLabel, "关闭")
    }

    func testCampOffClearsAlert() {
        let engine = makeEngine()
        engine.observe(state(camp: true))
        XCTAssertEqual(engine.alerts.count, 1)

        engine.observe(state(camp: false))
        XCTAssertTrue(engine.alerts.isEmpty)
    }

    func testReObserveSameOnStateDoesNotResetTimestamp() {
        settings.campModeReminderMinutes = 60
        let engine = makeEngine()
        engine.observe(state(camp: true))

        clock = clock.addingTimeInterval(30 * 60)
        engine.observe(state(camp: true))   // still on
        clock = clock.addingTimeInterval(31 * 60)
        engine.recompute()

        XCTAssertEqual(engine.alerts.first?.severity, .critical,
                       "duration should be measured from first-on, not most-recent observe")
    }

    func testThresholdZeroDisablesCampReminder() {
        settings.campModeReminderMinutes = 0
        let engine = makeEngine()
        engine.observe(state(camp: true))
        XCTAssertTrue(engine.alerts.isEmpty,
                      "threshold = 0 should suppress the reminder entirely")
    }

    // MARK: - performPrimaryAction wires through to APIService

    func testPerformPrimaryActionCallsAPIAndClearsAlert() async {
        settings.campModeReminderMinutes = 60
        let engine = makeEngine()
        engine.observe(state(camp: true))
        clock = clock.addingTimeInterval(61 * 60)
        engine.recompute()
        guard let alert = engine.alerts.first else {
            return XCTFail("expected critical camp alert")
        }
        XCTAssertEqual(alert.severity, .critical)

        api.mockSetClimateKeeperModeResponse = .success(BaseResponse(success: true, message: "ok"))
        let result = await engine.performPrimaryAction(for: alert, vehicleId: "v1")

        if case .failure = result { XCTFail("expected success") }
        XCTAssertEqual(api.setClimateKeeperModeCallCount, 1)
        XCTAssertEqual(api.lastSetClimateKeeperModeArgs?.mode, 0)
        XCTAssertTrue(engine.alerts.isEmpty,
                      "alert should clear optimistically after successful action")
    }

    func testPerformPrimaryActionKeepsAlertOnAPIFailure() async {
        settings.campModeReminderMinutes = 60
        let engine = makeEngine()
        engine.observe(state(camp: true))
        clock = clock.addingTimeInterval(61 * 60)
        engine.recompute()
        let alert = engine.alerts[0]

        api.mockSetClimateKeeperModeResponse = .failure(.serverError(statusCode: 503, message: "offline"))
        let result = await engine.performPrimaryAction(for: alert, vehicleId: "v1")

        if case .success = result { XCTFail("expected failure") }
        XCTAssertEqual(engine.alerts.count, 1, "alert should stay so the user can retry")
    }

    // MARK: - registry / multi-rule wiring

    func testEmptyRegistryNeverEmitsAlerts() {
        let engine = makeEngine(rules: [])
        engine.observe(state(camp: true))
        XCTAssertTrue(engine.alerts.isEmpty)
    }

    func testSeveritySortPlacesCriticalFirst() {
        // Two camp rules — same kind, but the test demonstrates the
        // engine's ordering contract: critical before info. Useful as
        // a sanity check for when 5.2 lands two real rules.
        settings.campModeReminderMinutes = 60
        let engine = makeEngine()
        engine.observe(state(camp: true))
        clock = clock.addingTimeInterval(61 * 60)
        engine.recompute()

        XCTAssertEqual(engine.alerts.first?.severity, .critical)
    }
}
