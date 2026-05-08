import XCTest
@testable import TePlannerKit

/// Tests for the per-rule snooze. Snooze is iOS-side only — server
/// keeps evaluating but the engine recompute filters snoozed rules
/// before they ever reach the alert list, so the notification
/// scheduler diffs them out as if disabled.
@MainActor
final class SnoozeTests: XCTestCase {
    private var settings: InMemorySettingsStore!
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
    }

    func test_snoozedRule_doesNotEmitAlert() {
        let engine = AutomationEngine(
            registry: [ruleWithThreshold(1)], apiService: api, settings: settings,
            now: { self.now }
        )
        // First observation seeds the start time at "now". Second
        // observation 2 minutes later trips the 1-min threshold.
        engine.observe(campState(), vehicleId: "v1")

        let later = AutomationEngine(
            registry: [ruleWithThreshold(1)], apiService: api, settings: settings,
            now: { self.now.addingTimeInterval(120) }
        )
        // Pre-seed memory so the rule has been "active" for 2 minutes.
        later.applyServerTelemetryState([
            TelemetryStateEntry(
                entity: "vehicle.climate.keeper_mode",
                value: .int(3),
                since: now,
            ),
        ])
        later.observe(campState(), vehicleId: "v1")
        XCTAssertEqual(later.alerts.count, 1, "baseline: rule fires once threshold met")

        // Snooze 1 hour. Recompute → alert dropped.
        settings.ruleSnooze[campRecord.id] = self.now
            .addingTimeInterval(120 + 3600)
            .timeIntervalSince1970
        later.recompute(vehicleId: "v1")
        XCTAssertTrue(later.alerts.isEmpty, "snoozed rule must not appear in alerts")
    }

    func test_expiredSnooze_isIgnored_byEngine() {
        let later = AutomationEngine(
            registry: [ruleWithThreshold(1)], apiService: api, settings: settings,
            now: { self.now.addingTimeInterval(120) }
        )
        later.applyServerTelemetryState([
            TelemetryStateEntry(
                entity: "vehicle.climate.keeper_mode",
                value: .int(3),
                since: now,
            ),
        ])
        // Snooze that already expired (10 minutes ago). Must not block.
        settings.ruleSnooze[campRecord.id] = self.now
            .addingTimeInterval(-600)
            .timeIntervalSince1970
        later.observe(campState(), vehicleId: "v1")
        XCTAssertEqual(later.alerts.count, 1, "expired snooze must not block the rule")
    }

    func test_userDefaultsStore_prunesExpiredEntries_onRead() {
        let suiteName = "SnoozeTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsSettingsStore(defaults: defaults)
        store.ruleSnooze = [
            "fresh": Date().addingTimeInterval(3600).timeIntervalSince1970,
            "stale": Date().addingTimeInterval(-3600).timeIntervalSince1970,
        ]
        let read = store.ruleSnooze
        XCTAssertNotNil(read["fresh"], "future entries must survive a round-trip")
        XCTAssertNil(read["stale"], "past entries must be pruned on read")
    }
}
