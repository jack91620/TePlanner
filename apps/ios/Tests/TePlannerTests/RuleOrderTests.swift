import XCTest
@testable import TePlannerKit

/// Phase D.2 — server-canonical rule ordering.
///
/// iOS dropped the local UserDefaults `automation_rule_order` array.
/// Drag/move now POSTs `PUT /automations/order` and replaces the local
/// rule cache with the response (server returns the freshly sorted
/// list). These tests cover (a) RuleRecord round-trips display_order
/// from the wire, (b) reorder() routes to the API and swaps the cache,
/// (c) failures don't corrupt the cache.
@MainActor
final class RuleOrderTests: XCTestCase {

    private var settings: InMemorySettingsStore!
    private var api: MockAPIService!
    private var store: AutomationRulesStore!

    override func setUp() {
        super.setUp()
        settings = InMemorySettingsStore()
        api = MockAPIService()
        store = AutomationRulesStore(apiService: api, settings: settings)
    }

    private func record(id: String, name: String, displayOrder: Int? = nil) -> RuleRecord {
        RuleRecord(
            id: id,
            presetId: nil,
            name: name,
            enabled: true,
            spec: TestSpecFixtures.campMode,
            version: 1,
            displayOrder: displayOrder,
        )
    }

    func test_ruleRecord_decodesDisplayOrder_fromServerJSON() throws {
        let json = """
        {
          "id": "r1",
          "preset_id": null,
          "name": "测试规则",
          "enabled": true,
          "spec": {"kind": "camp_mode", "trigger": {"type": "cron", "expr": "0 8 * * *"}},
          "version": 1,
          "display_order": 3
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(RuleRecord.self, from: json)
        XCTAssertEqual(decoded.displayOrder, 3)
    }

    func test_ruleRecord_decodesNilDisplayOrder_whenMissing() throws {
        let json = """
        {"id":"r","preset_id":null,"name":"n","enabled":true,
         "spec":{"kind":"camp_mode","trigger":{"type":"cron","expr":"* * * * *"}},
         "version":1}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(RuleRecord.self, from: json)
        XCTAssertNil(decoded.displayOrder)
    }

    func test_reorder_callsApi_andSwapsLocalCacheOnSuccess() async {
        let r1 = record(id: "r1", name: "r1")
        let r2 = record(id: "r2", name: "r2")
        let r3 = record(id: "r3", name: "r3")
        api.mockListAutomationsResponse = .success([r1, r2, r3])
        await store.refresh()
        XCTAssertEqual(store.rules.map(\.id), ["r1", "r2", "r3"])

        let reordered = [
            record(id: "r3", name: "r3", displayOrder: 0),
            record(id: "r1", name: "r1", displayOrder: 1),
            record(id: "r2", name: "r2", displayOrder: 2),
        ]
        api.mockReorderResponse = .success(reordered)
        let ok = await store.reorder(ruleIds: ["r3", "r1", "r2"])
        XCTAssertTrue(ok)
        XCTAssertEqual(store.rules.map(\.id), ["r3", "r1", "r2"])
        XCTAssertEqual(api.reorderCalls.count, 1)
        XCTAssertEqual(api.reorderCalls.first?.ruleIds, ["r3", "r1", "r2"])
        XCTAssertEqual(api.reorderCalls.first?.clear, false)
    }

    func test_reorder_failurePreservesPriorCache() async {
        let r1 = record(id: "r1", name: "r1")
        let r2 = record(id: "r2", name: "r2")
        api.mockListAutomationsResponse = .success([r1, r2])
        await store.refresh()

        api.mockReorderResponse = .failure(.serverError(statusCode: 500, message: "boom"))
        let ok = await store.reorder(ruleIds: ["r2", "r1"])
        XCTAssertFalse(ok)
        XCTAssertEqual(store.rules.map(\.id), ["r1", "r2"],
                       "cache must keep prior order on API failure")
        XCTAssertNotNil(store.lastError)
    }

    func test_reorder_clearTrue_propagates() async {
        api.mockReorderResponse = .success([])
        _ = await store.reorder(ruleIds: [], clear: true)
        XCTAssertEqual(api.reorderCalls.first?.clear, true)
        XCTAssertEqual(api.reorderCalls.first?.ruleIds, [])
    }
}
