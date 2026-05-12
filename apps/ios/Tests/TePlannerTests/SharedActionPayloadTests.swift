import XCTest
@testable import TePlannerKit

/// Wire-format invariants for SharedActionPayload. Catches the
/// subtle JSON encoding bugs that surface as silent data loss
/// in shared actions — e.g. an Optional Int dropping to nil
/// because the decoder expected a non-null field, or a non-ASCII
/// name getting Unicode-escape-corrupted in the round-trip.
final class SharedActionPayloadTests: XCTestCase {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - delayMsAfter Optional Int round-trip

    func test_step_delay_survives_encode_decode_when_set() throws {
        let original = SharedActionPayload(
            name: "离家",
            icon: "house",
            tint: .blue,
            steps: [
                HubActionStep(capability: "tesla.security.set_sentry",
                              params: ["vehicle.sentry_mode_on": .bool(true)],
                              delayMsAfter: 3000),
                HubActionStep(capability: "tesla.security.door_lock"),
            ],
            confirmRequired: true,
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SharedActionPayload.self, from: data)
        XCTAssertEqual(decoded.steps.count, 2)
        XCTAssertEqual(decoded.steps[0].delayMsAfter, 3000)
        XCTAssertNil(decoded.steps[1].delayMsAfter)
    }

    func test_step_delay_nil_omitted_from_wire_or_preserved_as_nil() throws {
        let original = SharedActionPayload(
            name: "锁车",
            icon: "lock",
            tint: .blue,
            steps: [HubActionStep(capability: "tesla.security.door_lock")],
            confirmRequired: false,
        )
        let data = try encoder.encode(original)
        let json = String(data: data, encoding: .utf8) ?? ""
        // Either omit the key (most compact) or send null. Both
        // decode back to nil; neither should serialize as 0.
        XCTAssertFalse(json.contains("\"delay_ms_after\":0"),
                       "delayMsAfter=nil must not serialize as 0; would set a real 0ms wait on import")
        let decoded = try decoder.decode(SharedActionPayload.self, from: data)
        XCTAssertNil(decoded.steps[0].delayMsAfter)
    }

    // MARK: - Step params (JSONValue round-trip)

    func test_step_params_with_mixed_types_round_trip() throws {
        let original = SharedActionPayload(
            name: "充电",
            icon: "bolt",
            tint: .orange,
            steps: [
                HubActionStep(
                    capability: "tesla.charging.set_limit",
                    params: [
                        "vehicle.charge_limit_soc": .int(80),
                        "vehicle.locked": .bool(true),
                        "vehicle.note": .string("home"),
                    ],
                ),
            ],
            confirmRequired: false,
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SharedActionPayload.self, from: data)
        XCTAssertEqual(decoded.steps[0].params["vehicle.charge_limit_soc"], .int(80))
        XCTAssertEqual(decoded.steps[0].params["vehicle.locked"], .bool(true))
        XCTAssertEqual(decoded.steps[0].params["vehicle.note"], .string("home"))
    }

    // MARK: - Chinese name + payload-dict encode helper

    func test_encodeShareablePayload_preserves_chinese_name_and_keys() throws {
        let original = SharedActionPayload(
            name: "上下班通勤",
            icon: "house",
            tint: .green,
            steps: [HubActionStep(capability: "tesla.climate.preheat")],
            confirmRequired: false,
        )
        guard let bag = encodeShareablePayload(original) else {
            return XCTFail("encodeShareablePayload returned nil")
        }
        XCTAssertEqual(bag["name"], .string("上下班通勤"))
        XCTAssertEqual(bag["icon"], .string("house"))
        XCTAssertEqual(bag["confirm_required"], .bool(false))
    }

    // MARK: - HubAction <-> SharedActionPayload symmetry

    func test_HubAction_to_payload_and_back_preserves_steps() {
        let source = HubAction(
            name: "宠物模式",
            icon: "thermometer.medium",
            tint: .green,
            steps: [
                HubActionStep(
                    capability: "tesla.climate.set_keeper_mode",
                    params: ["vehicle.climate.keeper_mode": .int(2)],
                    delayMsAfter: nil,
                ),
                HubActionStep(
                    capability: "tesla.security.set_sentry",
                    params: ["vehicle.sentry_mode_on": .bool(false)],
                    delayMsAfter: 5000,
                ),
            ],
            confirmRequired: true,
        )
        let payload = SharedActionPayload.from(source)
        let imported = payload.toHubAction()

        XCTAssertEqual(imported.name, source.name)
        XCTAssertEqual(imported.tint, source.tint)
        XCTAssertEqual(imported.confirmRequired, source.confirmRequired)
        XCTAssertEqual(imported.steps.count, source.steps.count)
        XCTAssertEqual(imported.steps[0].capability, "tesla.climate.set_keeper_mode")
        XCTAssertEqual(imported.steps[0].params["vehicle.climate.keeper_mode"], .int(2))
        XCTAssertNil(imported.steps[0].delayMsAfter)
        XCTAssertEqual(imported.steps[1].delayMsAfter, 5000)
        // isSystem MUST be false on import even if source was system.
        XCTAssertFalse(imported.isSystem)
        // Fresh UUID — must NOT collide with source.
        XCTAssertNotEqual(imported.id, source.id)
        // SF Symbol → semantic → SF Symbol round-trip works.
        XCTAssertEqual(imported.icon, "thermometer.medium")
    }

    func test_system_action_share_drops_system_flag_on_import() {
        let source = HubAction(
            name: "锁车", icon: "lock.fill", tint: .blue,
            steps: [HubActionStep(capability: "tesla.security.door_lock")],
            confirmRequired: false,
            isSystem: true,
        )
        let imported = SharedActionPayload.from(source).toHubAction()
        XCTAssertFalse(imported.isSystem,
                       "receiver of a shared system action must own it (not inherit the system flag)")
    }
}
