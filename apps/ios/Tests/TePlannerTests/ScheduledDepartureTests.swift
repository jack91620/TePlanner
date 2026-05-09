import XCTest
@testable import TePlannerKit

final class ScheduledDepartureTests: XCTestCase {
    func testFireAtSubtractsLeadTime() {
        let dep = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = ScheduledDeparture(departureAt: dep, leadTimeMinutes: 15, vehicleId: "v1")
        XCTAssertEqual(entry.fireAt, dep.addingTimeInterval(-15 * 60))
    }

    func testLeadTimeFloorsAtOneMinute() {
        let entry = ScheduledDeparture(
            departureAt: Date(),
            leadTimeMinutes: 0,
            vehicleId: nil
        )
        XCTAssertEqual(entry.leadTimeMinutes, 1,
                       "scheduling 0 minutes lead is meaningless; clamp to 1")
    }

    func testIsInFuture() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let past = ScheduledDeparture(departureAt: now.addingTimeInterval(-60), vehicleId: nil)
        let future = ScheduledDeparture(departureAt: now.addingTimeInterval(60), vehicleId: nil)
        XCTAssertFalse(past.isInFuture(now: now))
        XCTAssertTrue(future.isInFuture(now: now))
    }
}

final class ScheduledDepartureStoreTests: XCTestCase {
    private var clock: Date!

    override func setUp() async throws {
        clock = Date(timeIntervalSince1970: 1_700_000_000)
    }

    private func makeStore() -> InMemoryScheduledDepartureStore {
        InMemoryScheduledDepartureStore(now: { [weak self] in self?.clock ?? Date() })
    }

    func testEmptyStoreReturnsNil() {
        XCTAssertNil(makeStore().current())
    }

    func testSaveThenCurrent() {
        let store = makeStore()
        let entry = ScheduledDeparture(
            label: "上班",
            departureAt: clock.addingTimeInterval(3600),
            leadTimeMinutes: 20,
            vehicleId: "v1"
        )
        store.save(entry)
        XCTAssertEqual(store.current(), entry)
    }

    func testStorePrunesPastDepartures() {
        let store = makeStore()
        let entry = ScheduledDeparture(
            departureAt: clock.addingTimeInterval(60),
            leadTimeMinutes: 5,
            vehicleId: nil
        )
        store.save(entry)
        XCTAssertNotNil(store.current())

        // Time advances past departure
        clock = clock.addingTimeInterval(120)
        XCTAssertNil(store.current(),
                     "store should not surface departures that have already passed")
    }

    func testClearRemovesEntry() {
        let store = makeStore()
        store.save(ScheduledDeparture(
            departureAt: clock.addingTimeInterval(3600),
            vehicleId: nil
        ))
        store.clear()
        XCTAssertNil(store.current())
    }

    func testSaveOverwritesExisting() {
        let store = makeStore()
        let first = ScheduledDeparture(
            label: "early",
            departureAt: clock.addingTimeInterval(3600),
            vehicleId: nil
        )
        let second = ScheduledDeparture(
            label: "later",
            departureAt: clock.addingTimeInterval(7200),
            vehicleId: nil
        )
        store.save(first)
        store.save(second)
        XCTAssertEqual(store.current()?.label, "later",
                       "single-slot store should reflect the latest save")
    }
}
