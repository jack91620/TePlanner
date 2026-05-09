import XCTest
@testable import TePlannerKit

/// Phase D.5 — the iOS-side `ChargeLimitSuggester` static helpers
/// were deleted. The decision logic now lives in the backend
/// (`app/services/charge_analysis/suggester.py`) and iOS calls
/// `POST /vehicles/{vid}/suggest-charge-limit` to get a `Suggest
/// ChargeLimitResponse`. The exhaustive algorithm test cases that
/// used to live here moved to `backend/tests/test_charge_limit_
/// suggester.py` (Phase A.4) so all 3 platforms (iOS / Android /
/// Harmony) consume one source of truth.
///
/// What remains on iOS is wire-format pinning (request encodes /
/// response decodes per Pydantic shape) — the actual reasoning is
/// the backend's responsibility.
@MainActor
final class ChargeLimitSuggesterTests: XCTestCase {
    func test_request_encodesSnakeCaseFieldNames() throws {
        let req = SuggestChargeLimitRequest(
            currentLimit: 85,
            dailyLimitSoc: 80,
            tripLimitSoc: 100,
            tripWindowHours: 12,
        )
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        let data = try enc.encode(req)
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains("\"current_limit\":85"))
        XCTAssertTrue(json.contains("\"daily_limit_soc\":80"))
        XCTAssertTrue(json.contains("\"trip_limit_soc\":100"))
        XCTAssertTrue(json.contains("\"trip_window_hours\":12"))
    }

    func test_response_decodesDailyShape() throws {
        let json = """
        {
          "recommended_percent": 80,
          "current_percent": 90,
          "reason": "daily",
          "hours_away": null,
          "already_matches": false
        }
        """.data(using: .utf8)!
        let resp = try JSONDecoder().decode(SuggestChargeLimitResponse.self, from: json)
        XCTAssertEqual(resp.recommendedPercent, 80)
        XCTAssertEqual(resp.currentPercent, 90)
        XCTAssertEqual(resp.reason, "daily")
        XCTAssertNil(resp.hoursAway)
        XCTAssertFalse(resp.alreadyMatches)
    }

    func test_response_decodesUpcomingDepartureShape() throws {
        let json = """
        {
          "recommended_percent": 100,
          "current_percent": 80,
          "reason": "upcoming_departure",
          "hours_away": 4,
          "already_matches": false
        }
        """.data(using: .utf8)!
        let resp = try JSONDecoder().decode(SuggestChargeLimitResponse.self, from: json)
        XCTAssertEqual(resp.recommendedPercent, 100)
        XCTAssertEqual(resp.reason, "upcoming_departure")
        XCTAssertEqual(resp.hoursAway, 4)
    }

    func test_mockServiceRoundtrip_passesRequestThrough() async {
        let api = MockAPIService()
        api.mockSuggestChargeLimitResponse = .success(SuggestChargeLimitResponse(
            recommendedPercent: 100,
            currentPercent: 80,
            reason: "upcoming_departure",
            hoursAway: 4,
            alreadyMatches: false,
        ))
        let result = await api.suggestChargeLimit(
            vehicleId: "VIN1",
            request: SuggestChargeLimitRequest(currentLimit: 80),
        )
        guard case .success(let resp) = result else {
            XCTFail("expected success"); return
        }
        XCTAssertEqual(resp.recommendedPercent, 100)
        XCTAssertEqual(api.suggestChargeLimitCalls.count, 1)
        XCTAssertEqual(api.suggestChargeLimitCalls.first?.vehicleId, "VIN1")
        XCTAssertEqual(api.suggestChargeLimitCalls.first?.request.currentLimit, 80)
    }
}
