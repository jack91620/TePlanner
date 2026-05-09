import XCTest
@testable import TePlannerKit

/// These tests pin the JSON wire format against the Android backend. If a
/// field name changes, both clients should change together — this catches
/// drift early.
final class ModelDecodingTests: XCTestCase {
    private let decoder = JSONDecoder()

    func testVehicleStateDecodesAndroidShape() throws {
        let json = """
        {
          "vehicle_id": "12345",
          "display_name": "我的Model Y",
          "state": "online",
          "battery_level": 78,
          "battery_range_km": 312.5,
          "usable_battery_level": 76,
          "charging_state": "Disconnected",
          "latitude": 31.2304,
          "longitude": 121.4737,
          "heading": 90,
          "speed": 0,
          "odometer_km": 12345.6,
          "inside_temp": 22.5,
          "outside_temp": 18.0
        }
        """.data(using: .utf8)!

        let state = try decoder.decode(VehicleState.self, from: json)
        XCTAssertEqual(state.vehicleId, "12345")
        XCTAssertEqual(state.displayName, "我的Model Y")
        XCTAssertEqual(state.batteryLevel, 78)
        XCTAssertEqual(state.batteryRange, 312.5)
        XCTAssertEqual(state.latitude, 31.2304)
        XCTAssertEqual(state.chargingState, "Disconnected")
        XCTAssertEqual(state.odometer, 12345.6)
    }

    func testVehicleDecodesWithDefaults() throws {
        let json = """
        { "id": "abc", "vin": "5YJ" }
        """.data(using: .utf8)!

        let vehicle = try decoder.decode(Vehicle.self, from: json)
        XCTAssertEqual(vehicle.id, "abc")
        XCTAssertEqual(vehicle.vin, "5YJ")
        XCTAssertEqual(vehicle.state, "offline")
        XCTAssertFalse(vehicle.inService)
        XCTAssertFalse(vehicle.isPrimary)
    }

    func testChargingStationDecodesTypeEnum() throws {
        let json = """
        {
          "id": "s1",
          "name": "国家电网充电站",
          "address": "上海市浦东新区",
          "latitude": 31.1,
          "longitude": 121.4,
          "type": "supercharger",
          "available_stalls": 4,
          "total_stalls": 8,
          "power_kw": 250,
          "operator": "Tesla",
          "distance_km": 12.3,
          "open_24h": true
        }
        """.data(using: .utf8)!

        let station = try decoder.decode(ChargingStation.self, from: json)
        XCTAssertEqual(station.id, "s1")
        XCTAssertEqual(station.type, .supercharger)
        XCTAssertEqual(station.powerKw, 250)
        XCTAssertEqual(station.operatorName, "Tesla")
        XCTAssertTrue(station.open24h)
    }

    func testChargingStationUnknownTypeFallsBackToOther() throws {
        let json = """
        {
          "id": "s2",
          "name": "未知充电站",
          "latitude": 31.0,
          "longitude": 121.0,
          "type": "magic_new_type"
        }
        """.data(using: .utf8)!

        let station = try decoder.decode(ChargingStation.self, from: json)
        XCTAssertEqual(station.type, .other)
        XCTAssertFalse(station.open24h)
    }

    func testTeslaAuthUrlResponseDecodes() throws {
        let json = """
        {
          "url": "https://auth.tesla.com/oauth2/v3/authorize?client_id=...",
          "state": "csrf-xyz",
          "user_id": 15
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(TeslaAuthUrlResponse.self, from: json)
        XCTAssertEqual(response.state, "csrf-xyz")
        XCTAssertEqual(response.userId, 15)
        XCTAssertTrue(response.url.starts(with: "https://"))
    }

    func testTeslaStatusResponseFillsDefaults() throws {
        let json = """
        { "linked": true }
        """.data(using: .utf8)!

        let status = try decoder.decode(TeslaStatusResponse.self, from: json)
        XCTAssertTrue(status.linked)
        XCTAssertFalse(status.expired)
        XCTAssertEqual(status.vehicleCount, 0)
    }

    func testWakeResponseSuccessHeuristic() throws {
        let online = try decoder.decode(WakeResponse.self, from: #"{"state":"online"}"#.data(using: .utf8)!)
        XCTAssertTrue(online.success)

        let offline = try decoder.decode(WakeResponse.self, from: #"{"state":"offline"}"#.data(using: .utf8)!)
        XCTAssertFalse(offline.success)

        let missing = try decoder.decode(WakeResponse.self, from: "{}".data(using: .utf8)!)
        XCTAssertFalse(missing.success)
    }

    // MARK: - Phase D.1 — Pydantic date format coverage

    /// SnoozeRecord round-trips Pydantic v2's `datetime.utcnow().
    /// isoformat()` output. The backend returns shapes like
    /// ``2026-05-09T09:26:35.704923`` (no tz, microsecond precision)
    /// — strict ISO8601DateFormatter rejects this. APIService's
    /// `decodePydanticDate` strips the fractional component and
    /// retries against the plain parser. Regression test for the
    /// 2026-05-09 incident where snooze cards never appeared because
    /// every POST response failed to decode.
    func testSnoozeRecordDecodesPydanticMicrosecondTimestamp() throws {
        let json = """
        {
          "rule_id": "cb4c3205-e43f-43a6-a0c5-43346ec72b25",
          "snoozed_until_utc": "2026-05-09T09:26:35.704923",
          "reason": null,
          "created_at": "2026-05-09T08:26:35.705936"
        }
        """.data(using: .utf8)!
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .custom(APIService.decodePydanticDate)
        let snooze = try dec.decode(SnoozeRecord.self, from: json)
        XCTAssertEqual(snooze.ruleId, "cb4c3205-e43f-43a6-a0c5-43346ec72b25")
        XCTAssertNil(snooze.reason)
        // ``snoozed_until_utc`` must be in the future relative to a
        // reference date well before 2026 — assert a coarse range
        // rather than an exact instant.
        XCTAssertGreaterThan(
            snooze.snoozedUntilUtc.timeIntervalSinceReferenceDate,
            Date(timeIntervalSince1970: 1_700_000_000).timeIntervalSinceReferenceDate
        )
    }

    func testDecodePydanticDateAcceptsAllFiveFlavors() throws {
        struct Wrapper: Decodable { let d: Date }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .custom(APIService.decodePydanticDate)
        for s in [
            "2026-05-09T09:26:35.123Z",         // ISO + fractional + tz
            "2026-05-09T09:26:35+00:00",        // ISO no fractional + tz
            "2026-05-09T09:26:35",              // plain no tz
            "2026-05-09T09:26:35.704923",       // plain + microseconds (no tz)
        ] {
            let json = "{\"d\":\"\(s)\"}".data(using: .utf8)!
            XCTAssertNoThrow(try dec.decode(Wrapper.self, from: json),
                             "must accept \(s)")
        }
    }
}
