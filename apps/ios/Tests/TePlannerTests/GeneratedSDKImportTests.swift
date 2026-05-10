import XCTest
@testable import TePlannerKit
import TePlannerAPI

/// Phase C smoke test — proves the OpenAPI-generated TePlannerAPI
/// SDK is reachable from TePlannerKit and its types are wired
/// correctly. Phase D will replace APIService.swift's hand-rolled
/// HTTP plumbing with calls to this generated SDK; until then this
/// test just guards against codegen drift breaking the import.
///
/// Generator emits init args alphabetically. If you regenerate the
/// SDK and these tests start failing on argument-order errors, the
/// underlying API model changed — accept the new positional shape.
final class GeneratedSDKImportTests: XCTestCase {
    func test_can_construct_generated_request_models() throws {
        let body = TePlannerAPI.SnoozeRequest(hours: 6, reason: "充电中")
        XCTAssertEqual(body.hours, 6)
        XCTAssertEqual(body.reason, "充电中")
    }

    func test_can_construct_charging_session_request() throws {
        let body = TePlannerAPI.ChargingSessionRequest(
            clientSessionId: "test",
            startedAt: Date(),
            startSoc: 30,
            startRangeKm: 100,
            locationName: "Home"
        )
        XCTAssertEqual(body.startSoc, 30)
        XCTAssertEqual(body.locationName, "Home")
    }

    func test_charging_session_response_decodes() throws {
        let json = """
        {
          "id": 1,
          "vehicle_id": "VIN1",
          "client_session_id": null,
          "started_at": "2026-05-09T12:00:00Z",
          "ended_at": null,
          "start_soc": 30,
          "end_soc": null,
          "start_range_km": null,
          "end_range_km": null,
          "energy_added_kwh": null,
          "location_name": null,
          "lat": null,
          "lng": null,
          "ended_as_complete": null,
          "source": "ios",
          "duration_minutes": null,
          "range_added_km": null,
          "soc_delta": null
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let resp = try decoder.decode(TePlannerAPI.ChargingSessionResponse.self, from: json)
        XCTAssertEqual(resp.id, 1)
        XCTAssertEqual(resp.vehicleId, "VIN1")
        XCTAssertEqual(resp.startSoc, 30)
        XCTAssertEqual(resp.source, "ios")
    }
}
