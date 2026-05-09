import XCTest
@testable import TePlannerKit

/// Phase D.4 — verifies the backend-backed store's contract:
///   - upsert mutates the cache synchronously (Tracker depends on
///     this — observe() runs on each polling tick and reads ongoing()
///     without awaiting any network)
///   - the POST is fire-and-forget; success replaces the cached row
///     with the server response so duration / range additions stay
///     consistent
///   - failure rolls back the cache to its prior shape
///   - refresh() repopulates the cache from a list response
@MainActor
final class BackendChargingSessionStoreTests: XCTestCase {
    private var api: MockAPIService!

    override func setUp() async throws {
        api = MockAPIService()
    }

    private func session(
        id: UUID = UUID(),
        vehicleId: String = "VIN1",
        startAt: Date = Date(),
        endAt: Date? = nil,
        startSoc: Int? = 30
    ) -> ChargingSession {
        ChargingSession(
            id: id,
            vehicleId: vehicleId,
            startAt: startAt,
            endAt: endAt,
            startSoc: startSoc,
            startRangeKm: 100,
            locationName: "Home",
        )
    }

    func test_upsert_synchronouslyAddsToCache() {
        let store = BackendChargingSessionStore(apiService: api)
        let s = session()
        store.upsert(s)
        XCTAssertEqual(store.recent(limit: nil).count, 1)
        XCTAssertEqual(store.ongoing()?.id, s.id, "ongoing should match — endAt is nil")
    }

    func test_upsert_withoutVehicleId_skipsApiCall() async {
        let store = BackendChargingSessionStore(apiService: api)
        let s = ChargingSession(vehicleId: nil, startAt: Date(), startSoc: 30, startRangeKm: 100, locationName: nil)
        store.upsert(s)
        await Task.yield()
        XCTAssertEqual(api.upsertChargingSessionCalls.count, 0,
                       "no vehicle → cache only, no POST")
        XCTAssertEqual(store.recent(limit: nil).count, 1)
    }

    func test_upsert_postsToBackend_andSwapsToServerResponse() async {
        let store = BackendChargingSessionStore(apiService: api)
        let serverEnd = Date(timeIntervalSince1970: 1_700_001_000)
        let s = session()
        api.mockUpsertChargingSessionResponse = .success(ChargingSessionResponse(
            id: 42,
            vehicleId: "VIN1",
            clientSessionId: s.id.uuidString,
            startedAt: s.startAt,
            endedAt: serverEnd,
            startSoc: 30,
            endSoc: 80,
            startRangeKm: 100,
            endRangeKm: 320,
            energyAddedKwh: 35.5,
            locationName: "Home",
            lat: nil,
            lng: nil,
            endedAsComplete: true,
            source: "ios",
            durationMinutes: 30,
            rangeAddedKm: 220,
            socDelta: 50,
        ))

        store.upsert(s)
        for _ in 0..<5 { await Task.yield() }
        XCTAssertEqual(api.upsertChargingSessionCalls.count, 1)
        XCTAssertEqual(api.upsertChargingSessionCalls.first?.vehicleId, "VIN1")

        let cached = try? XCTUnwrap(store.recent(limit: nil).first)
        XCTAssertEqual(cached?.endSoc, 80,
                       "server's authoritative end_soc must replace the cached row")
        XCTAssertEqual(cached?.endRangeKm, 320)
    }

    func test_upsert_failureRollsBackNewInsert() async {
        let store = BackendChargingSessionStore(apiService: api)
        api.mockUpsertChargingSessionResponse =
            .failure(.serverError(statusCode: 500, message: "boom"))
        let s = session()
        store.upsert(s)
        XCTAssertEqual(store.recent(limit: nil).count, 1, "optimistic insert visible immediately")
        for _ in 0..<5 { await Task.yield() }
        XCTAssertEqual(store.recent(limit: nil).count, 0,
                       "POST failure must roll back the new row")
    }

    func test_upsert_failureRevertsToPriorRow() async {
        let store = BackendChargingSessionStore(apiService: api)
        let s = session(startSoc: 30)
        store.upsert(s)
        for _ in 0..<5 { await Task.yield() }
        let originalSoc = store.recent(limit: nil).first?.startSoc

        api.mockUpsertChargingSessionResponse =
            .failure(.serverError(statusCode: 500, message: "boom"))
        var updated = s
        updated.endSoc = 99
        store.upsert(updated)
        XCTAssertEqual(store.recent(limit: nil).first?.endSoc, 99,
                       "optimistic update visible immediately")
        for _ in 0..<5 { await Task.yield() }
        XCTAssertEqual(store.recent(limit: nil).first?.endSoc, nil,
                       "update failure must restore the prior row's nil endSoc")
        XCTAssertEqual(store.recent(limit: nil).first?.startSoc, originalSoc)
    }

    func test_refresh_replacesCacheFromServer() async {
        let store = BackendChargingSessionStore(apiService: api)
        store.upsert(session())  // pre-existing local row

        let serverSession = ChargingSessionResponse(
            id: 7,
            vehicleId: "VIN1",
            clientSessionId: UUID().uuidString,
            startedAt: Date(),
            endedAt: Date(),
            startSoc: 20,
            endSoc: 90,
            startRangeKm: 80,
            endRangeKm: 360,
            energyAddedKwh: nil,
            locationName: "Office",
            lat: nil,
            lng: nil,
            endedAsComplete: true,
            source: "ios",
            durationMinutes: 60,
            rangeAddedKm: 280,
            socDelta: 70,
        )
        api.mockListChargingSessionsResponse =
            .success(ChargingSessionListResponse(sessions: [serverSession]))

        await store.refresh(vehicleId: "VIN1")
        XCTAssertEqual(store.recent(limit: nil).count, 1)
        XCTAssertEqual(store.recent(limit: nil).first?.locationName, "Office",
                       "refresh replaces local cache with server-canonical list")
    }

    func test_refresh_withNilVehicleId_isNoOp() async {
        let store = BackendChargingSessionStore(apiService: api)
        store.upsert(session())
        await store.refresh(vehicleId: nil)
        XCTAssertEqual(api.listChargingSessionsCalls.count, 0)
        XCTAssertEqual(store.recent(limit: nil).count, 1, "cache untouched")
    }
}
