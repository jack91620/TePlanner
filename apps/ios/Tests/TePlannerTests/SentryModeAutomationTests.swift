import XCTest
@testable import TePlannerKit

@MainActor
final class SentryModeAutomationTests: XCTestCase {
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

    private func makeEngine(thresholdMinutes: Int = 1440) -> AutomationEngine {
        let spec = specWithThreshold(PresetSpecs.sentryMode, minutes: thresholdMinutes)
        return AutomationEngine(
            registry: [makeRecord(spec: spec)],
            apiService: api,
            settings: settings,
            memory: memory,
            now: { [weak self] in self?.clock ?? Date() }
        )
    }

    private func state(sentry: Bool) -> VehicleState {
        VehicleState(
            vehicleId: "v1",
            displayName: "Tesla",
            state: "online",
            sentryModeOn: sentry
        )
    }

    func testNoAlertWhenSentryOff() {
        let e = makeEngine()
        e.observe(state(sentry: false))
        XCTAssertTrue(e.alerts.isEmpty)
    }

    func testSentryOnEmitsInfoBelowThreshold() {
        let e = makeEngine(thresholdMinutes: 60)
        e.observe(state(sentry: true))
        XCTAssertEqual(e.alerts.count, 1)
        XCTAssertEqual(e.alerts.first?.kind, .sentryMode)
        XCTAssertEqual(e.alerts.first?.severity, .info)
        XCTAssertNil(e.alerts.first?.primaryActionLabel)
    }

    func testSentryUpgradesToCriticalAfterThreshold() {
        let e = makeEngine(thresholdMinutes: 60)
        e.observe(state(sentry: true))
        clock = clock.addingTimeInterval(61 * 60)
        e.recompute()
        XCTAssertEqual(e.alerts.first?.severity, .critical)
        XCTAssertEqual(e.alerts.first?.primaryActionLabel, "关闭哨兵")
    }

    func testSentryOffClearsAlert() {
        let e = makeEngine()
        e.observe(state(sentry: true))
        XCTAssertEqual(e.alerts.count, 1)
        e.observe(state(sentry: false))
        XCTAssertTrue(e.alerts.isEmpty)
    }

    func testThresholdZeroDisablesRule() {
        let e = makeEngine(thresholdMinutes: 0)
        e.observe(state(sentry: true))
        XCTAssertTrue(e.alerts.isEmpty)
    }

    func testPerformPrimaryActionTurnsSentryOff() async {
        let e = makeEngine(thresholdMinutes: 60)
        e.observe(state(sentry: true))
        clock = clock.addingTimeInterval(61 * 60)
        e.recompute()
        let alert = e.alerts[0]

        api.mockSetSentryModeResponse = .success(BaseResponse(success: true, message: "ok"))
        let result = await e.performPrimaryAction(for: alert, vehicleId: "v1")

        if case .failure = result { XCTFail("expected success") }
        XCTAssertEqual(api.setSentryModeCallCount, 1)
        XCTAssertEqual(api.lastSetSentryModeArgs?.on, false,
                       "primary action must call setSentryMode(on: false)")
        XCTAssertTrue(e.alerts.isEmpty)
    }
}
