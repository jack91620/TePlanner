import XCTest
@testable import TePlannerKit
import TePlannerAPI

/// Phase C PoC — prove the OpenAPI-generated `TePlannerAPI.RuleResponse`
/// decodes the same wire payload as the hand-written
/// `TePlannerKit.RuleRecord`. If this test stays green over time, we
/// can confidently migrate `APIService.swift` to consume the
/// generated DTO directly and delete `RuleRecord`'s manual Codable
/// boilerplate.
///
/// Today (2026-05-11) both representations co-exist; this is the
/// behavioural contract for the migration.
final class RuleResponseParityTests: XCTestCase {

    /// Realistic payload mirroring `GET /api/v1/automations/`'s
    /// shape — one preset, one user-authored — including the
    /// `is_firing` + `firing_since` fields added today.
    private let json: String = """
    {
      "id": "f3a91-uuid",
      "preset_id": "camp_mode_overstay",
      "name": "露营模式超时提醒",
      "enabled": true,
      "spec": {
        "kind": "camp_mode",
        "trigger": {
          "type": "state_duration",
          "entity": "vehicle.climate.keeper_mode",
          "equals": 3,
          "for_minutes": 120,
          "state_key": "camp_mode_first_seen"
        },
        "actions_above": [{"type": "notify"}]
      },
      "version": 1,
      "updated_at": "2026-05-11T08:00:00Z",
      "last_fired_at": "2026-05-11T07:30:00Z",
      "display_order": 0,
      "is_firing": true,
      "firing_since": "2026-05-11T07:30:00Z"
    }
    """

    private func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    func test_handwritten_RuleRecord_decodes_with_isFiring() throws {
        let data = json.data(using: .utf8)!
        let record = try makeDecoder().decode(RuleRecord.self, from: data)
        XCTAssertEqual(record.id, "f3a91-uuid")
        XCTAssertEqual(record.presetId, "camp_mode_overstay")
        XCTAssertEqual(record.name, "露营模式超时提醒")
        XCTAssertTrue(record.enabled)
        XCTAssertEqual(record.version, 1)
        XCTAssertEqual(record.displayOrder, 0)
        XCTAssertTrue(record.isFiring)
        XCTAssertNotNil(record.firingSince)
    }

    func test_generated_TePlannerAPI_RuleResponse_decodes_same_wire() throws {
        let data = json.data(using: .utf8)!
        let resp = try makeDecoder().decode(TePlannerAPI.RuleResponse.self, from: data)
        XCTAssertEqual(resp.id, "f3a91-uuid")
        XCTAssertEqual(resp.presetId, "camp_mode_overstay")
        XCTAssertEqual(resp.name, "露营模式超时提醒")
        XCTAssertTrue(resp.enabled)
        XCTAssertEqual(resp.version, 1)
        XCTAssertEqual(resp.displayOrder, 0)
        XCTAssertEqual(resp.isFiring, true)
        XCTAssertNotNil(resp.firingSince)
    }

    /// Cross-check identical scalar fields land in both representations.
    /// If a future codegen run drifts (e.g. enabled becomes Optional),
    /// this test catches the wire-shape divergence before APIService
    /// migration does.
    func test_field_parity_between_handwritten_and_generated() throws {
        let data = json.data(using: .utf8)!
        let dec = makeDecoder()
        let record = try dec.decode(RuleRecord.self, from: data)
        let resp = try dec.decode(TePlannerAPI.RuleResponse.self, from: data)

        XCTAssertEqual(record.id, resp.id)
        XCTAssertEqual(record.presetId, resp.presetId)
        XCTAssertEqual(record.name, resp.name)
        XCTAssertEqual(record.enabled, resp.enabled)
        XCTAssertEqual(record.version, resp.version)
        XCTAssertEqual(record.displayOrder, resp.displayOrder)
        XCTAssertEqual(record.lastFiredAt, resp.lastFiredAt)
        XCTAssertEqual(record.isFiring, resp.isFiring)
        XCTAssertEqual(record.firingSince, resp.firingSince)
    }

    /// Backward-compat: a server response missing `is_firing` (older
    /// build, or roll-back) must decode cleanly into both types,
    /// defaulting `isFiring` to false.
    func test_decode_without_is_firing_defaults_to_false() throws {
        let stripped = """
        {
          "id": "old-build",
          "preset_id": null,
          "name": "Legacy",
          "enabled": true,
          "spec": {"kind": "x", "trigger": {"type": "cron", "expr": "* * * * *"}},
          "version": 1
        }
        """
        let data = stripped.data(using: .utf8)!
        let dec = makeDecoder()
        let record = try dec.decode(RuleRecord.self, from: data)
        XCTAssertFalse(record.isFiring)
        XCTAssertNil(record.firingSince)

        let resp = try dec.decode(TePlannerAPI.RuleResponse.self, from: data)
        // Generated SDK has Optional<Bool>? = false default; either nil
        // (undecided) or false is acceptable as "not firing".
        XCTAssertNotEqual(resp.isFiring, true)
    }
}
