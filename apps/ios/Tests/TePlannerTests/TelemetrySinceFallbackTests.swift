import XCTest
@testable import TePlannerKit

/// Phase 5: the iOS interpreter prefers the server-recorded
/// `tel:<entity>:since` over the locally-observed `state_key` start
/// time when the telemetry one is earlier. Mirrors
/// `backend/tests/test_interpreter_telemetry_since.py`.
@MainActor
final class TelemetrySinceFallbackTests: XCTestCase {
    private var api: MockAPIService!
    private var settings: InMemorySettingsStore!
    private var memory: InMemoryAutomationStateMemory!
    private var clock: Date!

    override func setUp() async throws {
        api = MockAPIService()
        settings = InMemorySettingsStore()
        memory = InMemoryAutomationStateMemory()
        clock = Date(timeIntervalSince1970: 1_700_000_000)
    }

    private func engine(records: [RuleRecord] = [makeRecord(spec: PresetSpecs.campMode)]) -> AutomationEngine {
        AutomationEngine(
            registry: records,
            apiService: api,
            settings: settings,
            memory: memory,
            now: { [weak self] in self?.clock ?? Date() }
        )
    }

    private func state(camp: Bool) -> VehicleState {
        VehicleState(
            vehicleId: "v1",
            displayName: "Tesla",
            state: "online",
            climateKeeperMode: camp ? 3 : 0
        )
    }

    func testTelemetrySinceSupersedesPollingObservation() throws {
        let engine = engine()
        engine.observe(state(camp: true))  // first observation seeds local startedAt = clock
        XCTAssertEqual(engine.alerts.first?.severity, .info)

        // Server says camp mode actually started 3 hours ago — that's
        // beyond the 2-hour threshold and should flip the alert to
        // critical without us advancing the clock.
        let serverSince = clock.addingTimeInterval(-3 * 3600)
        engine.applyServerTelemetryState([
            TelemetryStateEntry(
                entity: "vehicle.climate.keeper_mode",
                value: .int(3),
                since: serverSince
            )
        ])

        XCTAssertEqual(engine.alerts.first?.severity, .critical)
        XCTAssertEqual(engine.alerts.first?.primaryActionLabel, "关闭")
        XCTAssertTrue(
            engine.alerts.first?.detail.contains("3 小时") ?? false,
            "expected 3-hour duration in detail; got: \(engine.alerts.first?.detail ?? "nil")"
        )
    }

    func testTelemetrySinceIgnoredWhenLaterThanLocalObservation() {
        let engine = engine()
        // Pretend we observed camp mode 4 hours ago locally — way past
        // the 2-hour threshold. Telemetry only saw it 1h ago (e.g.
        // backend restarted and lost cache).
        memory.set("campMode:startedAt", value: clock.addingTimeInterval(-4 * 3600))
        memory.set(
            "tel:vehicle.climate.keeper_mode:since",
            value: clock.addingTimeInterval(-1 * 3600)
        )
        engine.observe(state(camp: true))

        // Local-observed (4h) wins because it's earlier — duration
        // should reflect that, not telemetry's 1h.
        XCTAssertEqual(engine.alerts.first?.severity, .critical)
        XCTAssertTrue(
            engine.alerts.first?.detail.contains("4 小时") ?? false,
            "expected 4-hour duration; got: \(engine.alerts.first?.detail ?? "nil")"
        )
    }

    func testNoTelemetrySinceKeepsLocalBehavior() {
        let engine = engine()
        memory.set("campMode:startedAt", value: clock.addingTimeInterval(-30 * 60))
        engine.observe(state(camp: true))

        XCTAssertEqual(engine.alerts.first?.severity, .info)
        XCTAssertTrue(
            engine.alerts.first?.detail.contains("30 分钟") ?? false,
            "expected 30-minute duration; got: \(engine.alerts.first?.detail ?? "nil")"
        )
    }

    func testTelemetrySinceDoesNotFireWhenStateIsOff() {
        let engine = engine()
        memory.set(
            "tel:vehicle.climate.keeper_mode:since",
            value: clock.addingTimeInterval(-10 * 3600)
        )
        engine.observe(state(camp: false))
        XCTAssertTrue(engine.alerts.isEmpty)
    }

    func testApplyServerTelemetryStatePopulatesMemoryAndRecomputes() {
        let engine = engine()
        engine.observe(state(camp: true))
        let initialDetail = engine.alerts.first?.detail ?? ""

        // Apply 2.5h ago — should flip immediately.
        engine.applyServerTelemetryState([
            TelemetryStateEntry(
                entity: "vehicle.climate.keeper_mode",
                value: .int(3),
                since: clock.addingTimeInterval(-150 * 60)
            )
        ])

        XCTAssertEqual(engine.alerts.first?.severity, .critical)
        XCTAssertNotEqual(engine.alerts.first?.detail, initialDetail)
    }
}
