import XCTest
@testable import TePlannerKit

@MainActor
final class ChargingStatsViewModelTests: XCTestCase {
    private var store: InMemoryChargingSessionStore!
    private var clock: Date!
    private var calendar: Calendar!

    override func setUp() async throws {
        store = InMemoryChargingSessionStore()
        // Pin to mid-month so "this month" math is unambiguous.
        let comps = DateComponents(year: 2026, month: 5, day: 15, hour: 12, minute: 0)
        calendar = Calendar(identifier: .gregorian)
        clock = calendar.date(from: comps)!
    }

    private func makeVM() -> ChargingStatsViewModel {
        ChargingStatsViewModel(
            store: store,
            now: { [weak self] in self?.clock ?? Date() },
            calendar: calendar
        )
    }

    private func session(
        startOffsetDays: Int = 0,
        durationMinutes: Int = 30,
        startSoc: Int = 30,
        endSoc: Int? = 80,
        startRange: Double = 120,
        endRange: Double? = 320,
        complete: Bool? = true
    ) -> ChargingSession {
        let start = calendar.date(byAdding: .day, value: startOffsetDays, to: clock)!
        let end = endSoc != nil
            ? start.addingTimeInterval(TimeInterval(durationMinutes * 60))
            : nil
        return ChargingSession(
            vehicleId: "v1",
            startAt: start,
            endAt: end,
            startSoc: startSoc,
            endSoc: endSoc,
            startRangeKm: startRange,
            endRangeKm: endRange,
            locationName: "家",
            endedAsComplete: complete
        )
    }

    func testEmptyState() {
        let vm = makeVM()
        vm.reload()
        XCTAssertFalse(vm.hasAnyData)
        XCTAssertEqual(vm.monthlyCount, 0)
        XCTAssertEqual(vm.monthlyDurationMinutes, 0)
        XCTAssertEqual(vm.monthlyRangeAddedKm, 0)
    }

    func testCountsThisMonthSessionsOnly() {
        // 3 sessions this month, 1 last month
        store.upsert(session(startOffsetDays: -1))   // ~14th
        store.upsert(session(startOffsetDays: -5))   // ~10th
        store.upsert(session(startOffsetDays: -10))  // ~5th
        store.upsert(session(startOffsetDays: -20))  // late April

        let vm = makeVM()
        vm.reload()
        XCTAssertEqual(vm.monthlyCount, 3,
                       "session from previous month must not count toward this-month bucket")
    }

    func testAggregatesDurationAndRange() {
        store.upsert(session(durationMinutes: 30, startRange: 100, endRange: 250))
        store.upsert(session(startOffsetDays: -2, durationMinutes: 45, startRange: 80, endRange: 280))

        let vm = makeVM()
        vm.reload()
        XCTAssertEqual(vm.monthlyDurationMinutes, 75)
        XCTAssertEqual(vm.monthlyRangeAddedKm, 350)
    }

    func testOngoingSessionExcludedFromAggregates() {
        let ongoing = ChargingSession(
            vehicleId: "v1",
            startAt: clock,
            startSoc: 50,
            startRangeKm: 200,
            locationName: nil
        )
        store.upsert(ongoing)

        let vm = makeVM()
        vm.reload()
        XCTAssertTrue(vm.hasAnyData,
                      "ongoing session shows in history list")
        XCTAssertEqual(vm.monthlyCount, 0,
                       "but doesn't count in monthly stats until finalized")
    }

    func testSessionsListSortedNewestFirst() {
        store.upsert(session(startOffsetDays: -5))
        store.upsert(session(startOffsetDays: -1))
        store.upsert(session(startOffsetDays: -3))

        let vm = makeVM()
        vm.reload()
        XCTAssertEqual(vm.sessions.count, 3)
        XCTAssertGreaterThan(vm.sessions[0].startAt, vm.sessions[1].startAt)
        XCTAssertGreaterThan(vm.sessions[1].startAt, vm.sessions[2].startAt)
    }
}
