import XCTest
@testable import TePlannerKit

/// Phase D.1 + D.6 — server-canonical snooze. iOS dropped its
/// UserDefaults `rule_snooze_until` map (D.1) AND its local rule
/// evaluator (D.6); these tests now cover only the iOS-side
/// BackendSnoozeStore optimistic-update + rollback contract.
/// Engine-level snooze gating is exercised in
/// `backend/tests/test_snooze.py` against the real evaluator.
@MainActor
final class SnoozeTests: XCTestCase {
    private var api: MockAPIService!
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let ruleId = "camp_mode_overstay"

    override func setUp() {
        super.setUp()
        api = MockAPIService()
    }

    func test_backendStore_refreshPopulatesCacheFromServer() async {
        let store = BackendSnoozeStore(apiService: api, now: { self.now })
        let serverDeadline = now.addingTimeInterval(3600)
        api.mockSnoozeListResponse = .success(SnoozeListResponse(snoozes: [
            SnoozeRecord(
                ruleId: ruleId,
                snoozedUntilUtc: serverDeadline,
                reason: "充电中",
                createdAt: self.now.addingTimeInterval(-60),
            ),
        ]))
        await store.refresh()
        XCTAssertEqual(store.activeUntil[ruleId], serverDeadline)
        XCTAssertEqual(api.fetchSnoozesCallCount, 1)
    }

    func test_backendStore_snoozeAppliesOptimisticallyAndSyncsServerDeadline() async {
        let store = BackendSnoozeStore(apiService: api, now: { self.now })
        let serverDeadline = now.addingTimeInterval(2 * 3600)
        api.mockSnoozeResponse = .success(SnoozeRecord(
            ruleId: ruleId,
            snoozedUntilUtc: serverDeadline,
            reason: nil,
            createdAt: self.now,
        ))
        let ok = await store.snooze(ruleId: ruleId, hours: 6, reason: nil)
        XCTAssertTrue(ok)
        XCTAssertEqual(store.activeUntil[ruleId], serverDeadline,
                       "cache must reflect the server-acknowledged deadline")
        XCTAssertEqual(api.snoozeCalls.count, 1)
        XCTAssertEqual(api.snoozeCalls.first?.ruleId, ruleId)
        XCTAssertEqual(api.snoozeCalls.first?.hours, 6)
    }

    func test_backendStore_snoozeRollsBackOnFailure() async {
        let store = BackendSnoozeStore(apiService: api, now: { self.now })
        api.mockSnoozeResponse = .failure(.serverError(statusCode: 500, message: "boom"))
        let ok = await store.snooze(ruleId: ruleId, hours: 1, reason: nil)
        XCTAssertFalse(ok)
        XCTAssertNil(store.activeUntil[ruleId],
                     "failed snooze must not leave a phantom entry in the cache")
    }

    func test_backendStore_unsnoozeIsIdempotentAndRollsBackOnFailure() async {
        let store = BackendSnoozeStore(apiService: api, now: { self.now })
        api.mockSnoozeResponse = .success(SnoozeRecord(
            ruleId: ruleId,
            snoozedUntilUtc: self.now.addingTimeInterval(3600),
            reason: nil,
            createdAt: self.now,
        ))
        await store.snooze(ruleId: ruleId, hours: 1, reason: nil)
        XCTAssertNotNil(store.activeUntil[ruleId])

        api.mockUnsnoozeResponse = .failure(.serverError(statusCode: 500, message: "boom"))
        let ok = await store.unsnooze(ruleId: ruleId)
        XCTAssertFalse(ok)
        XCTAssertNotNil(store.activeUntil[ruleId],
                        "failed unsnooze must restore the previous deadline")
        XCTAssertEqual(api.unsnoozeCalls, [ruleId])
    }

    func test_engineApplyServerAlertsSortsByCritical() async {
        // Phase D.6 contract: backend snooze-filters before pushing
        // (Phase A.1 server-side gate). iOS engine just sorts and
        // displays. Test the sort: critical-first, then info.
        let engine = AutomationEngine(
            registry: [],
            apiService: api,
            settings: InMemorySettingsStore(),
            snoozes: InMemorySnoozeStore(now: { self.now }),
            now: { self.now },
        )
        let infoAlert = VehicleAlert(
            kind: .campMode, title: "info", detail: "d",
            severity: .info, primaryActionLabel: nil,
        )
        let criticalAlert = VehicleAlert(
            kind: .sentryMode, title: "crit", detail: "d",
            severity: .critical, primaryActionLabel: nil,
        )
        engine.applyServerAlerts([infoAlert, criticalAlert])
        XCTAssertEqual(engine.alerts.count, 2)
        XCTAssertEqual(engine.alerts.first?.severity, .critical,
                       "critical-severity alerts sort first")
    }
}
