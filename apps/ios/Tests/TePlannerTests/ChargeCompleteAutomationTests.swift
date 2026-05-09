import XCTest
@testable import TePlannerKit

@MainActor
final class ChargeCompleteAutomationTests: XCTestCase {
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

    private func makeEngine(enabled: Bool = true) -> AutomationEngine {
        let spec = specEnabled(PresetSpecs.chargeComplete, enabled)
        return AutomationEngine(
            registry: [makeRecord(spec: spec)],
            apiService: api,
            settings: settings,
            snoozes: InMemorySnoozeStore(),
            memory: memory,
            now: { [weak self] in self?.clock ?? Date() }
        )
    }

    private func state(_ chargingState: String, soc: Int = 80) -> VehicleState {
        VehicleState(
            vehicleId: "v1",
            displayName: "Tesla",
            state: "online",
            batteryLevel: soc,
            chargingState: chargingState
        )
    }

    func testNoAlertWhenDisconnected() {
        let e = makeEngine()
        e.observe(state("Disconnected"))
        XCTAssertTrue(e.alerts.isEmpty)
    }

    func testNoAlertWhileCharging() {
        let e = makeEngine()
        e.observe(state("Charging"))
        XCTAssertTrue(e.alerts.isEmpty)
    }

    func testFiresOnTransitionToComplete() {
        let e = makeEngine()
        e.observe(state("Charging"))
        e.observe(state("Complete"))

        XCTAssertEqual(e.alerts.count, 1)
        let alert = e.alerts[0]
        XCTAssertEqual(alert.kind, .chargeComplete)
        XCTAssertEqual(alert.severity, .critical)
        XCTAssertEqual(alert.primaryActionLabel, "我知道了")
    }

    func testStaysActiveWhilePlugged() {
        let e = makeEngine()
        e.observe(state("Complete"))
        clock = clock.addingTimeInterval(60 * 60)
        e.observe(state("Complete"))

        XCTAssertEqual(e.alerts.count, 1, "alert remains while car still says Complete")
    }

    func testDismissalSuppressesUntilStateChanges() async {
        let e = makeEngine()
        e.observe(state("Complete"))
        XCTAssertEqual(e.alerts.count, 1)

        let result = await e.performPrimaryAction(for: e.alerts[0], vehicleId: "v1")
        if case .failure = result { XCTFail("expected dismiss to succeed") }
        XCTAssertTrue(e.alerts.isEmpty)

        // Re-observe Complete: stays suppressed (user already
        // acknowledged this charging session).
        e.observe(state("Complete"))
        XCTAssertTrue(e.alerts.isEmpty,
                      "dismissed alert must not re-fire on the same session")
    }

    func testReFiresAfterUnplugAndReplug() async {
        let e = makeEngine()
        e.observe(state("Complete"))
        _ = await e.performPrimaryAction(for: e.alerts[0], vehicleId: "v1")
        XCTAssertTrue(e.alerts.isEmpty)

        // Unplugged → state leaves Complete, both flags clear.
        e.observe(state("Disconnected"))
        XCTAssertTrue(e.alerts.isEmpty)

        // New session: charge → complete should re-fire.
        e.observe(state("Charging"))
        e.observe(state("Complete"))
        XCTAssertEqual(e.alerts.count, 1,
                       "new charging session must re-arm the alert")
    }

    func testToggleOffSuppressesEntirely() {
        let e = makeEngine(enabled: false)
        e.observe(state("Complete"))
        XCTAssertTrue(e.alerts.isEmpty)
    }

    func testAlertDetailIncludesSoc() {
        let e = makeEngine()
        e.observe(state("Complete", soc: 92))
        XCTAssertTrue(e.alerts.first?.detail.contains("92%") ?? false,
                      "user wants to see how full the battery actually is")
    }
}
