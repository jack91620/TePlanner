import XCTest
@testable import TePlannerKit

/// Pin the ActiveTripStore lifecycle: refresh, start, advance,
/// cancel. Real Tesla nav sends are mocked through MockAPIService;
/// these tests only check that the right endpoints are hit and the
/// published `trip` reflects the response.
@MainActor
final class ActiveTripStoreTests: XCTestCase {

    private func sampleTrip(id: Int = 1, segment: Int = 0,
                            status: ActiveTrip.Status = .active) -> ActiveTrip {
        ActiveTrip(
            id: id,
            vehicleId: "tesla_42",
            status: status,
            currentSegment: segment,
            stops: [
                TripStop(latitude: 31.2, longitude: 121.4, name: "A", kind: .charging),
                TripStop(latitude: 32.0, longitude: 121.0, name: "终点", kind: .final),
            ],
            createdAt: Date(),
            updatedAt: Date(),
        )
    }

    func testRefreshNoActiveTripPublishesNil() async {
        let mock = MockAPIService()
        mock.mockActiveTripResponse = .success(nil)
        let store = ActiveTripStore(apiService: mock)
        await store.refresh()
        XCTAssertNil(store.trip)
        XCTAssertNil(store.lastError)
    }

    func testRefreshActiveTripPublishesIt() async {
        let mock = MockAPIService()
        mock.mockActiveTripResponse = .success(sampleTrip())
        let store = ActiveTripStore(apiService: mock)
        await store.refresh()
        XCTAssertNotNil(store.trip)
        XCTAssertEqual(store.trip?.id, 1)
        XCTAssertEqual(store.trip?.currentSegment, 0)
    }

    func testStartPushesRequestAndCachesResult() async {
        let mock = MockAPIService()
        let trip = sampleTrip()
        mock.mockStartTripResponse = .success(trip)
        let store = ActiveTripStore(apiService: mock)
        let stops = [
            TripStop(latitude: 0, longitude: 0, kind: .charging),
            TripStop(latitude: 1, longitude: 1, kind: .final),
        ]
        let ok = await store.start(vehicleId: "tesla_42", stops: stops)
        XCTAssertTrue(ok)
        XCTAssertEqual(mock.lastStartTripRequest?.vehicleId, "tesla_42")
        XCTAssertEqual(mock.lastStartTripRequest?.stops.count, 2)
        XCTAssertEqual(store.trip?.id, 1)
    }

    func testAdvanceClearsTripWhenServerReportsCompleted() async {
        // After advancing past the last stop the backend flips
        // status to .completed and we drop the local trip so the Hub
        // card hides.
        let mock = MockAPIService()
        mock.mockActiveTripResponse = .success(sampleTrip())
        let store = ActiveTripStore(apiService: mock)
        await store.refresh()

        var done = sampleTrip()
        done = ActiveTrip(
            id: done.id, vehicleId: done.vehicleId, status: .completed,
            currentSegment: done.stops.count - 1, stops: done.stops,
            createdAt: done.createdAt, updatedAt: done.updatedAt,
        )
        mock.mockAdvanceTripResponse = .success(done)
        await store.advance()

        XCTAssertNil(store.trip)
        XCTAssertEqual(mock.lastAdvanceTripId, 1)
    }

    func testAdvanceKeepsActiveTripWhenServerStillActive() async {
        let mock = MockAPIService()
        mock.mockActiveTripResponse = .success(sampleTrip(segment: 0))
        let store = ActiveTripStore(apiService: mock)
        await store.refresh()

        mock.mockAdvanceTripResponse = .success(sampleTrip(segment: 1))
        await store.advance()
        XCTAssertEqual(store.trip?.currentSegment, 1)
    }

    func testCancelClearsTrip() async {
        let mock = MockAPIService()
        mock.mockActiveTripResponse = .success(sampleTrip())
        let store = ActiveTripStore(apiService: mock)
        await store.refresh()

        var cancelled = sampleTrip()
        cancelled = ActiveTrip(
            id: cancelled.id, vehicleId: cancelled.vehicleId,
            status: .cancelled,
            currentSegment: cancelled.currentSegment,
            stops: cancelled.stops,
            createdAt: cancelled.createdAt, updatedAt: cancelled.updatedAt,
        )
        mock.mockCancelTripResponse = .success(cancelled)
        await store.cancel()
        XCTAssertNil(store.trip)
        XCTAssertEqual(mock.lastCancelTripId, 1)
    }
}
