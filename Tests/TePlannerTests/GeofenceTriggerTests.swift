import XCTest
@testable import TePlannerKit

/// Phase 8: iOS geofence trigger mirrors the backend interpreter.
/// Test contract identical to `backend/tests/test_geofence_trigger.py`.
@MainActor
final class GeofenceTriggerTests: XCTestCase {
    private var settings: InMemorySettingsStore!
    private var memory: InMemoryAutomationStateMemory!
    private var clock: Date!

    private let homeLat = 39.9000
    private let homeLng = 116.4000
    private let nearLat = 39.9001
    private let nearLng = 116.4001
    private let farLat = 39.9100
    private let farLng = 116.4100

    override func setUp() async throws {
        settings = InMemorySettingsStore()
        memory = InMemoryAutomationStateMemory()
        clock = Date(timeIntervalSince1970: 1_700_000_000)
    }

    private func ctx(at: (Double, Double)?) -> AutomationContext {
        let state: VehicleState? = at.map {
            VehicleState(
                vehicleId: "v1",
                latitude: $0.0, longitude: $0.1,
            )
        }
        return AutomationContext(
            vehicleState: state,
            vehicleId: "v1",
            now: clock,
            settings: settings,
            memory: memory,
        )
    }

    private func enterHomeSpec() -> RuleSpec {
        return [
            "kind": .string("geofenceEnter"),
            "trigger": .object([
                "type": .string("geofence"),
                "lat": .double(homeLat),
                "lng": .double(homeLng),
                "radius_m": .double(200),
                "event": .string("enter"),
                "state_key": .string("geo:home"),
            ]),
            "actions": .array([
                .object([
                    "type": .string("notify"),
                    "title": .string("已抵家"),
                    "body": .string("距离 {distance_m} 米"),
                    "severity": .string("info"),
                ]),
            ]),
        ]
    }

    func testNoFireWhenFarFromCenter() {
        let alert = evaluateRule(enterHomeSpec(), context: ctx(at: (farLat, farLng)))
        XCTAssertNil(alert)
    }

    func testFiresOnFirstEntry() {
        let alert = evaluateRule(enterHomeSpec(), context: ctx(at: (homeLat, homeLng)))
        XCTAssertNotNil(alert)
        XCTAssertEqual(alert?.kind, .geofenceEnter)
        XCTAssertEqual(alert?.severity, .info)
        XCTAssertEqual(alert?.title, "已抵家")
        XCTAssertTrue(alert?.detail.contains("距离 0 米") ?? false)
    }

    func testNoDoubleFireWhileInside() {
        XCTAssertNotNil(evaluateRule(enterHomeSpec(), context: ctx(at: (homeLat, homeLng))))
        clock = clock.addingTimeInterval(1)
        XCTAssertNil(evaluateRule(enterHomeSpec(), context: ctx(at: (homeLat, homeLng))))
    }

    func testReFiresAfterExitAndReentry() {
        XCTAssertNotNil(evaluateRule(enterHomeSpec(), context: ctx(at: (homeLat, homeLng))))
        clock = clock.addingTimeInterval(10 * 60)
        XCTAssertNil(evaluateRule(enterHomeSpec(), context: ctx(at: (farLat, farLng))))
        clock = clock.addingTimeInterval(5 * 60)
        XCTAssertNotNil(evaluateRule(enterHomeSpec(), context: ctx(at: (homeLat, homeLng))))
    }

    func testDebounceSquashesJitter() {
        XCTAssertNotNil(evaluateRule(enterHomeSpec(), context: ctx(at: (homeLat, homeLng))))
        clock = clock.addingTimeInterval(10)
        _ = evaluateRule(enterHomeSpec(), context: ctx(at: (farLat, farLng)))
        clock = clock.addingTimeInterval(20)  // total 30s — within 60s debounce
        XCTAssertNil(evaluateRule(enterHomeSpec(), context: ctx(at: (homeLat, homeLng))))
    }

    func testSkipsWhenLocationMissing() {
        XCTAssertNil(evaluateRule(enterHomeSpec(), context: ctx(at: nil)))
    }
}
