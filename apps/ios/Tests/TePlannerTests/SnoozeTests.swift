import XCTest
@testable import TePlannerKit

/// Phase D.1 — server-canonical snooze. iOS dropped its UserDefaults
/// `rule_snooze_until` map and now talks to backend's automation_snooze
/// table via APIService + SnoozeStore. AutomationEngine reads the
/// store's `activeUntil` map; UI writes via `snooze(...)` /
/// `unsnooze(...)`. These tests cover the engine snooze gate
/// (mirrors the original behavior) plus the optimistic-update path.
@MainActor
final class SnoozeTests: XCTestCase {
    private var settings: InMemorySettingsStore!
    private var snoozes: InMemorySnoozeStore!
    private var api: MockAPIService!
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private var campRecord: RuleRecord {
        RuleRecord(
            id: "camp_mode_overstay",
            presetId: "camp_mode_overstay",
            name: "露营模式超时",
            enabled: true,
            spec: PresetSpecs.campMode,
        )
    }

    private func ruleWithThreshold(_ minutes: Int) -> RuleRecord {
        var spec = PresetSpecs.campMode
        if case .object(var trigger) = spec["trigger"] ?? .null {
            trigger["for_minutes"] = .int(minutes)
            spec["trigger"] = .object(trigger)
        }
        return RuleRecord(
            id: "camp_mode_overstay",
            presetId: "camp_mode_overstay",
            name: "露营模式超时",
            enabled: true,
            spec: spec,
        )
    }

    private func campState() -> VehicleState {
        VehicleState(vehicleId: "v1", state: "online", climateKeeperMode: 3)
    }

    override func setUp() {
        super.setUp()
        settings = InMemorySettingsStore()
        api = MockAPIService()
        snoozes = InMemorySnoozeStore(now: { self.now.addingTimeInterval(120) })
    }

    func test_snoozedRule_doesNotEmitAlert() {
        let engine = AutomationEngine(
            registry: [ruleWithThreshold(1)], apiService: api, settings: settings,
            snoozes: snoozes,
            now: { self.now }
        )
        engine.observe(campState(), vehicleId: "v1")

        let later = AutomationEngine(
            registry: [ruleWithThreshold(1)], apiService: api, settings: settings,
            snoozes: snoozes,
            now: { self.now.addingTimeInterval(120) }
        )
        later.applyServerTelemetryState([
            TelemetryStateEntry(
                entity: "vehicle.climate.keeper_mode",
                value: .int(3),
                since: now,
            ),
        ])
        later.observe(campState(), vehicleId: "v1")
        XCTAssertEqual(later.alerts.count, 1, "baseline: rule fires once threshold met")

        snoozes._setForTesting([
            campRecord.id: now.addingTimeInterval(120 + 3600),
        ])
        later.recompute(vehicleId: "v1")
        XCTAssertTrue(later.alerts.isEmpty, "snoozed rule must not appear in alerts")
    }

    func test_expiredSnooze_isIgnored_byEngine() {
        let later = AutomationEngine(
            registry: [ruleWithThreshold(1)], apiService: api, settings: settings,
            snoozes: snoozes,
            now: { self.now.addingTimeInterval(120) }
        )
        later.applyServerTelemetryState([
            TelemetryStateEntry(
                entity: "vehicle.climate.keeper_mode",
                value: .int(3),
                since: now,
            ),
        ])
        snoozes._setForTesting([
            campRecord.id: now.addingTimeInterval(-600),
        ])
        later.observe(campState(), vehicleId: "v1")
        XCTAssertEqual(later.alerts.count, 1, "expired snooze must not block the rule")
    }

    func test_backendStore_refreshPopulatesCacheFromServer() async {
        let store = BackendSnoozeStore(apiService: api, now: { self.now })
        let serverDeadline = now.addingTimeInterval(3600)
        api.mockSnoozeListResponse = .success(SnoozeListResponse(snoozes: [
            SnoozeRecord(
                ruleId: campRecord.id,
                snoozedUntilUtc: serverDeadline,
                reason: "充电中",
                createdAt: self.now.addingTimeInterval(-60),
            ),
        ]))
        await store.refresh()
        XCTAssertEqual(store.activeUntil[campRecord.id], serverDeadline)
        XCTAssertEqual(api.fetchSnoozesCallCount, 1)
    }

    func test_backendStore_snoozeAppliesOptimisticallyAndSyncsServerDeadline() async {
        let store = BackendSnoozeStore(apiService: api, now: { self.now })
        let serverDeadline = now.addingTimeInterval(2 * 3600)
        api.mockSnoozeResponse = .success(SnoozeRecord(
            ruleId: campRecord.id,
            snoozedUntilUtc: serverDeadline,
            reason: nil,
            createdAt: self.now,
        ))
        let ok = await store.snooze(ruleId: campRecord.id, hours: 6, reason: nil)
        XCTAssertTrue(ok)
        XCTAssertEqual(store.activeUntil[campRecord.id], serverDeadline,
                       "cache must reflect the server-acknowledged deadline")
        XCTAssertEqual(api.snoozeCalls.count, 1)
        XCTAssertEqual(api.snoozeCalls.first?.ruleId, campRecord.id)
        XCTAssertEqual(api.snoozeCalls.first?.hours, 6)
    }

    func test_backendStore_snoozeRollsBackOnFailure() async {
        let store = BackendSnoozeStore(apiService: api, now: { self.now })
        api.mockSnoozeResponse = .failure(.serverError(statusCode: 500, message: "boom"))
        let ok = await store.snooze(ruleId: campRecord.id, hours: 1, reason: nil)
        XCTAssertFalse(ok)
        XCTAssertNil(store.activeUntil[campRecord.id],
                     "failed snooze must not leave a phantom entry in the cache")
    }

    func test_backendStore_unsnoozeIsIdempotentAndRollsBackOnFailure() async {
        let store = BackendSnoozeStore(apiService: api, now: { self.now })
        api.mockSnoozeResponse = .success(SnoozeRecord(
            ruleId: campRecord.id,
            snoozedUntilUtc: self.now.addingTimeInterval(3600),
            reason: nil,
            createdAt: self.now,
        ))
        await store.snooze(ruleId: campRecord.id, hours: 1, reason: nil)
        XCTAssertNotNil(store.activeUntil[campRecord.id])

        api.mockUnsnoozeResponse = .failure(.serverError(statusCode: 500, message: "boom"))
        let ok = await store.unsnooze(ruleId: campRecord.id)
        XCTAssertFalse(ok)
        XCTAssertNotNil(store.activeUntil[campRecord.id],
                        "failed unsnooze must restore the previous deadline")
        XCTAssertEqual(api.unsnoozeCalls, [campRecord.id])
    }
}
