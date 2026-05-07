import XCTest
@testable import TePlannerKit

@MainActor
final class ChargingSessionTrackerTests: XCTestCase {
    private var store: InMemoryChargingSessionStore!
    private var clock: Date!

    override func setUp() async throws {
        store = InMemoryChargingSessionStore()
        clock = Date(timeIntervalSince1970: 1_700_000_000)
    }

    private func makeTracker() -> ChargingSessionTracker {
        ChargingSessionTracker(store: store, now: { [weak self] in self?.clock ?? Date() })
    }

    private func state(_ chargingState: String, soc: Int = 50, range: Double = 200) -> VehicleState {
        VehicleState(
            vehicleId: "v1",
            displayName: "Tesla",
            state: "online",
            batteryLevel: soc,
            batteryRange: range,
            chargingState: chargingState
        )
    }

    func testNoSessionRecordedWhenNeverCharging() {
        let t = makeTracker()
        t.observe(state("Disconnected"))
        t.observe(state("Disconnected"))
        XCTAssertEqual(store.recent(limit: nil).count, 0)
    }

    func testStartingChargeOpensSession() {
        let t = makeTracker()
        t.observe(state("Disconnected", soc: 30, range: 120))
        t.observe(state("Charging", soc: 30, range: 120))

        let sessions = store.recent(limit: nil)
        XCTAssertEqual(sessions.count, 1)
        let s = sessions[0]
        XCTAssertEqual(s.startSoc, 30)
        XCTAssertEqual(s.startRangeKm, 120)
        XCTAssertNil(s.endAt)
        XCTAssertTrue(s.isOngoing)
    }

    func testCompletingChargeFinalizesSession() {
        let t = makeTracker()
        t.observe(state("Disconnected", soc: 30, range: 120))
        t.observe(state("Charging", soc: 30, range: 120))

        clock = clock.addingTimeInterval(45 * 60)  // +45 min
        t.observe(state("Complete", soc: 80, range: 320))

        let sessions = store.recent(limit: nil)
        XCTAssertEqual(sessions.count, 1)
        let s = sessions[0]
        XCTAssertNotNil(s.endAt)
        XCTAssertEqual(s.endSoc, 80)
        XCTAssertEqual(s.endRangeKm, 320)
        XCTAssertEqual(s.socDelta, 50)
        XCTAssertEqual(s.rangeAddedKm, 200)
        XCTAssertEqual(s.durationMinutes, 45)
        XCTAssertEqual(s.endedAsComplete, true)
    }

    func testUnpluggingMidChargeFinalizesAsIncomplete() {
        let t = makeTracker()
        t.observe(state("Disconnected", soc: 30))
        t.observe(state("Charging", soc: 30))
        clock = clock.addingTimeInterval(20 * 60)
        t.observe(state("Disconnected", soc: 55))

        let s = store.recent(limit: nil)[0]
        XCTAssertEqual(s.endedAsComplete, false)
        XCTAssertEqual(s.socDelta, 25)
    }

    func testRepeatedChargingStateDoesNotOpenNewSession() {
        let t = makeTracker()
        t.observe(state("Charging", soc: 30))
        t.observe(state("Charging", soc: 35))
        t.observe(state("Charging", soc: 40))
        XCTAssertEqual(store.recent(limit: nil).count, 1,
                       "consecutive Charging observations should not double-open")
    }

    func testStartedBeforeAppLaunchFinalizesGracefully() {
        // App launches with the car already charging. lastSeenChargingState
        // is nil; first observation = Charging. We open a session.
        let t = makeTracker()
        t.observe(state("Charging", soc: 60, range: 240))

        clock = clock.addingTimeInterval(30 * 60)
        t.observe(state("Complete", soc: 80, range: 320))

        XCTAssertEqual(store.recent(limit: nil).count, 1)
        XCTAssertEqual(store.recent(limit: nil)[0].endSoc, 80)
    }

    func testStaleOngoingClosedBeforeOpeningNew() {
        // Simulate a previous app crash that left a session ongoing
        // — the next charge cycle should close it before recording
        // the new one, avoiding "two sessions ongoing forever".
        let stale = ChargingSession(
            vehicleId: "v1",
            startAt: clock.addingTimeInterval(-3600),
            startSoc: 20,
            startRangeKm: 80,
            locationName: nil
        )
        store.upsert(stale)
        XCTAssertNotNil(store.ongoing())

        let t = makeTracker()
        t.observe(state("Disconnected", soc: 20))
        t.observe(state("Charging", soc: 20))

        XCTAssertEqual(store.recent(limit: nil).count, 2)
        XCTAssertNil(store.recent(limit: nil).first { $0.id == stale.id }?.endAt == nil ? true : nil,
                     "stale session must have been closed")
    }

    func testTwoConsecutiveSessionsRecorded() {
        let t = makeTracker()
        // session 1
        t.observe(state("Disconnected"))
        t.observe(state("Charging", soc: 30))
        clock = clock.addingTimeInterval(30 * 60)
        t.observe(state("Complete", soc: 80))
        // session 2 a day later
        clock = clock.addingTimeInterval(24 * 3600)
        t.observe(state("Disconnected"))
        t.observe(state("Charging", soc: 40))
        clock = clock.addingTimeInterval(40 * 60)
        t.observe(state("Complete", soc: 85))

        XCTAssertEqual(store.recent(limit: nil).count, 2)
    }
}
