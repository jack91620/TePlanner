import XCTest
@testable import TePlannerKit

final class CapabilityRegistryTests: XCTestCase {
    /// All 5 expected ids must be present + match safety class.
    func testRegistryHasExpectedCapabilities() {
        let expected: [String: SafetyClass] = [
            "tesla.climate.set_keeper_mode": .writable,
            "tesla.climate.preheat":         .writable,
            "tesla.security.set_sentry":     .security,
            "tesla.charging.set_limit":      .writable,
            "tesla.navigation.send":         .writable,
        ]
        for (id, expectedClass) in expected {
            guard let cap = CapabilityRegistry.shared.get(id) else {
                XCTFail("missing capability: \(id)")
                continue
            }
            XCTAssertEqual(cap.safetyClass, expectedClass, "wrong class for \(id)")
        }
    }

    func testJSONValueRoundtrip() throws {
        let v: [String: JSONValue] = [
            "mode": .int(0),
            "on": .bool(true),
            "percent": .int(70),
            "lat": .double(39.9),
            "name": .string("故宫"),
        ]
        let data = try JSONEncoder().encode(v)
        let decoded = try JSONDecoder().decode([String: JSONValue].self, from: data)
        XCTAssertEqual(v, decoded)
        XCTAssertEqual(decoded.int("mode"), 0)
        XCTAssertEqual(decoded.bool("on"), true)
        XCTAssertEqual(decoded.double("lat"), 39.9)
        XCTAssertEqual(decoded.string("name"), "故宫")
    }

    /// dispatch with unknown id returns failure result, not throws.
    func testDispatchUnknownReturnsFailure() async {
        let api = MockAPIService()
        let result = await CapabilityRegistry.shared.dispatch(
            capabilityId: "not.real",
            ctx: CapabilityContext(vehicleId: "v1"),
            params: [:],
            api: api
        )
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.error, "Unknown capability: not.real")
    }

    /// Bad params surface as in-band failure.
    func testSetClimateKeeperBadParams() async {
        let api = MockAPIService()
        let result = await CapabilityRegistry.shared.dispatch(
            capabilityId: "tesla.climate.set_keeper_mode",
            ctx: CapabilityContext(vehicleId: "v1"),
            params: ["mode": .int(99)],
            api: api
        )
        XCTAssertFalse(result.success)
        XCTAssertNotNil(result.error)
    }

    /// Successful dispatch invokes the right APIService method.
    func testSetClimateKeeperHappyPath() async {
        let api = MockAPIService()
        let result = await CapabilityRegistry.shared.dispatch(
            capabilityId: "tesla.climate.set_keeper_mode",
            ctx: CapabilityContext(vehicleId: "v1"),
            params: ["mode": .int(0)],
            api: api
        )
        XCTAssertTrue(result.success)
        XCTAssertEqual(api.setClimateKeeperModeCallCount, 1)
        XCTAssertEqual(api.lastSetClimateKeeperModeArgs?.vehicleId, "v1")
        XCTAssertEqual(api.lastSetClimateKeeperModeArgs?.mode, 0)
    }

    /// Charge-limit range check 50..100.
    func testSetChargeLimitOutOfRange() async {
        let api = MockAPIService()
        let r = await CapabilityRegistry.shared.dispatch(
            capabilityId: "tesla.charging.set_limit",
            ctx: CapabilityContext(vehicleId: "v1"),
            params: ["percent": .int(30)],
            api: api
        )
        XCTAssertFalse(r.success)
    }

    func testNavigationRequiresLatLng() async {
        let api = MockAPIService()
        let r = await CapabilityRegistry.shared.dispatch(
            capabilityId: "tesla.navigation.send",
            ctx: CapabilityContext(vehicleId: "v1"),
            params: ["latitude": .double(39.9)],
            api: api
        )
        XCTAssertFalse(r.success)
    }
}
