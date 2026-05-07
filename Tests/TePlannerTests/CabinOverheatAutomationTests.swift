import XCTest
@testable import TePlannerKit

@MainActor
final class CabinOverheatAutomationTests: XCTestCase {
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

    private func makeEngine() -> AutomationEngine {
        AutomationEngine(
            registry: [CabinOverheatAutomation()],
            apiService: api,
            settings: settings,
            memory: memory,
            now: { [weak self] in self?.clock ?? Date() }
        )
    }

    private func state(overheatOn: Bool) -> VehicleState {
        VehicleState(
            vehicleId: "v1",
            displayName: "Tesla",
            state: "online",
            cabinOverheatProtectionOn: overheatOn
        )
    }

    func testNoAlertWhenOverheatOff() {
        let e = makeEngine()
        e.observe(state(overheatOn: false))
        XCTAssertTrue(e.alerts.isEmpty)
    }

    func testNoAlertImmediatelyAfterOn() {
        // The rule waits for `cabinOverheatReminderMinutes` to elapse
        // before surfacing — the car is already mitigating, so the
        // first few minutes of "protection on" are noise.
        settings.cabinOverheatReminderMinutes = 60
        let e = makeEngine()
        e.observe(state(overheatOn: true))
        XCTAssertTrue(e.alerts.isEmpty)
    }

    func testEmitsInfoAlertAfterThreshold() {
        settings.cabinOverheatReminderMinutes = 60
        let e = makeEngine()
        e.observe(state(overheatOn: true))
        clock = clock.addingTimeInterval(61 * 60)
        e.recompute()

        XCTAssertEqual(e.alerts.count, 1)
        XCTAssertEqual(e.alerts.first?.kind, .cabinOverheat)
        XCTAssertEqual(e.alerts.first?.severity, .info,
                       "cabin overheat is informational only; the car already mitigates")
        XCTAssertNil(e.alerts.first?.primaryActionLabel,
                     "info alert exposes no action button")
    }

    func testOverheatOffClearsAlert() {
        settings.cabinOverheatReminderMinutes = 60
        let e = makeEngine()
        e.observe(state(overheatOn: true))
        clock = clock.addingTimeInterval(61 * 60)
        e.recompute()
        XCTAssertEqual(e.alerts.count, 1)

        e.observe(state(overheatOn: false))
        XCTAssertTrue(e.alerts.isEmpty)
    }

    func testThresholdZeroDisablesRule() {
        settings.cabinOverheatReminderMinutes = 0
        let e = makeEngine()
        e.observe(state(overheatOn: true))
        clock = clock.addingTimeInterval(24 * 60 * 60)
        e.recompute()
        XCTAssertTrue(e.alerts.isEmpty)
    }
}
