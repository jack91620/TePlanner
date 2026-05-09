import XCTest
@testable import TePlannerKit

@MainActor
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

    func testResponseDecodesPydanticPayload() throws {
        let json = """
        {
          "id": 7,
          "departure_at_utc": "2026-05-09T08:00:00",
          "lead_minutes": 15,
          "label": "上班",
          "vehicle_id": "VIN1",
          "target_charge_soc": null,
          "enabled": true,
          "fire_at_utc": "2026-05-09T07:45:00",
          "created_at": "2026-05-09T07:00:00",
          "updated_at": "2026-05-09T07:00:00"
        }
        """.data(using: .utf8)!
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .custom(APIService.decodePydanticDate)
        let resp = try dec.decode(ScheduledDepartureResponse.self, from: json)
        XCTAssertEqual(resp.id, 7)
        XCTAssertEqual(resp.label, "上班")
        XCTAssertEqual(resp.leadMinutes, 15)
        let domain = try XCTUnwrap(resp.toDomain())
        XCTAssertEqual(domain.label, "上班")
        XCTAssertEqual(domain.vehicleId, "VIN1")
    }

    func testDisabledResponseDecodesAsNilDomain() throws {
        let json = """
        {
          "id": 1, "departure_at_utc": "2030-01-01T00:00:00", "lead_minutes": 1,
          "label": null, "vehicle_id": null, "target_charge_soc": null,
          "enabled": false, "fire_at_utc": "2030-01-01T00:00:00",
          "created_at": null, "updated_at": null
        }
        """.data(using: .utf8)!
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .custom(APIService.decodePydanticDate)
        let resp = try dec.decode(ScheduledDepartureResponse.self, from: json)
        XCTAssertNil(resp.toDomain(), "disabled rows must surface as nil")
    }
}


@MainActor
final class ScheduledDepartureStoreTests: XCTestCase {
    private var clock: Date!
    private var api: MockAPIService!

    override func setUp() async throws {
        clock = Date(timeIntervalSince1970: 1_700_000_000)
        api = MockAPIService()
    }

    private func makeInMemory() -> InMemoryScheduledDepartureStore {
        InMemoryScheduledDepartureStore(now: { [weak self] in self?.clock ?? Date() })
    }

    private func makeBackend() -> BackendScheduledDepartureStore {
        BackendScheduledDepartureStore(apiService: api, now: { [weak self] in self?.clock ?? Date() })
    }

    private func futureDeparture(_ secondsAhead: TimeInterval = 3600) -> ScheduledDeparture {
        ScheduledDeparture(
            label: "上班",
            departureAt: clock.addingTimeInterval(secondsAhead),
            leadTimeMinutes: 20,
            vehicleId: "v1"
        )
    }

    // MARK: - Pure in-memory store

    func testEmptyStoreReturnsNil() {
        XCTAssertNil(makeInMemory().current())
    }

    func testSaveThenCurrent() async {
        let store = makeInMemory()
        let entry = futureDeparture()
        await store.save(entry)
        XCTAssertEqual(store.current(), entry)
    }

    func testStorePrunesPastDepartures() async {
        let store = makeInMemory()
        let entry = ScheduledDeparture(
            departureAt: clock.addingTimeInterval(60),
            leadTimeMinutes: 5,
            vehicleId: nil
        )
        await store.save(entry)
        XCTAssertNotNil(store.current())
        clock = clock.addingTimeInterval(120)
        XCTAssertNil(store.current(),
                     "store should not surface departures that have already passed")
    }

    func testClearRemovesEntry() async {
        let store = makeInMemory()
        await store.save(futureDeparture())
        await store.clear()
        XCTAssertNil(store.current())
    }

    func testSaveOverwritesExisting() async {
        let store = makeInMemory()
        let first = ScheduledDeparture(label: "early", departureAt: clock.addingTimeInterval(3600), vehicleId: nil)
        let second = ScheduledDeparture(label: "later", departureAt: clock.addingTimeInterval(7200), vehicleId: nil)
        await store.save(first)
        await store.save(second)
        XCTAssertEqual(store.current()?.label, "later",
                       "single-slot store should reflect the latest save")
    }

    // MARK: - Backend store (Phase D.3)

    func testBackendStore_refreshPopulatesCacheFromServer() async {
        let store = makeBackend()
        let serverDeparture = futureDeparture(3600)
        api.mockScheduledDepartureResponse = .success(ScheduledDepartureResponse(
            id: 1,
            departureAtUtc: serverDeparture.departureAt,
            leadMinutes: serverDeparture.leadTimeMinutes,
            label: serverDeparture.label,
            vehicleId: serverDeparture.vehicleId,
            targetChargeSoc: nil,
            enabled: true,
            fireAtUtc: serverDeparture.fireAt,
            createdAt: clock.addingTimeInterval(-60),
            updatedAt: clock.addingTimeInterval(-60),
        ))
        await store.refresh()
        XCTAssertEqual(store.current(), serverDeparture)
        XCTAssertEqual(api.fetchScheduledDepartureCallCount, 1)
    }

    func testBackendStore_saveOptimisticAndAcksFromServer() async {
        let store = makeBackend()
        let entry = futureDeparture()
        let ok = await store.save(entry)
        XCTAssertTrue(ok)
        XCTAssertEqual(store.current(), entry)
        XCTAssertEqual(api.upsertScheduledDepartureCalls.count, 1)
        XCTAssertEqual(api.upsertScheduledDepartureCalls.first?.label, "上班")
    }

    func testBackendStore_saveRollsBackOnFailure() async {
        let store = makeBackend()
        api.mockUpsertScheduledDepartureResponse = .failure(.serverError(statusCode: 500, message: "boom"))
        let ok = await store.save(futureDeparture())
        XCTAssertFalse(ok)
        XCTAssertNil(store.current(), "failed save must not leave a phantom in cache")
    }

    func testBackendStore_clearOptimisticAndRollsBack() async {
        let store = makeBackend()
        await store.save(futureDeparture())
        XCTAssertNotNil(store.current())

        api.mockClearScheduledDepartureResponse = .failure(.serverError(statusCode: 500, message: "boom"))
        let ok = await store.clear()
        XCTAssertFalse(ok)
        XCTAssertNotNil(store.current(),
                        "failed clear must restore the previous departure")
        XCTAssertEqual(api.clearScheduledDepartureCallCount, 1)
    }

    func testBackendStore_currentPrunesExpiredCache() async {
        let store = makeBackend()
        let nearly = ScheduledDeparture(
            departureAt: clock.addingTimeInterval(60),
            leadTimeMinutes: 5,
            vehicleId: nil
        )
        await store.save(nearly)
        XCTAssertNotNil(store.current())
        clock = clock.addingTimeInterval(120)
        XCTAssertNil(store.current(), "expired cached entry must surface as nil")
    }
}
