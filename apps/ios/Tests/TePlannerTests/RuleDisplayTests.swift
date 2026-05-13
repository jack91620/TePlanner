import XCTest
@testable import TePlannerKit

/// `RuleDisplay.triggerSentence` is the user-facing one-liner that
/// shows up in AutomationsHomeView's rule rows + the builder's
/// live-preview card. The function is pure (input: RuleSpec) so it
/// can be tested without firing up the SwiftUI view.
///
/// Drift on this surface caused the 2026-05-11 incident where
/// "vehicle.trunk_open" leaked into the UI (commit bd21fb5). These
/// tests pin every trigger family to a known-good sentence shape
/// so future entity additions in the backend don't slip through
/// before iOS has the Chinese name + render logic.
final class RuleDisplayTests: XCTestCase {

    // Helper: parse a JSON-ish dict literal into RuleSpec via the
    // model layer so tests look like the wire format.
    private func spec(_ json: String) -> RuleSpec {
        let data = json.data(using: .utf8)!
        let raw = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        // Convert untyped Any → JSONValue. Tiny recursive helper.
        func encode(_ v: Any) -> JSONValue {
            if let b = v as? Bool { return .bool(b) }
            if let i = v as? Int { return .int(i) }
            if let d = v as? Double { return .double(d) }
            if let s = v as? String { return .string(s) }
            if let arr = v as? [Any] { return .array(arr.map(encode)) }
            if let obj = v as? [String: Any] {
                var m: [String: JSONValue] = [:]
                for (k, val) in obj { m[k] = encode(val) }
                return .object(m)
            }
            return .null
        }
        var out: RuleSpec = [:]
        for (k, v) in raw { out[k] = encode(v) }
        return out
    }

    // MARK: - state_duration

    func test_stateDuration_campMode_renders_chinese() {
        let s = spec("""
        {"kind": "campMode", "trigger": {
            "type": "state_duration",
            "entity": "vehicle.climate.keeper_mode",
            "equals": 3,
            "for_minutes": 120,
            "state_key": "k"
        }}
        """)
        let sentence = RuleDisplay.triggerSentence(s)
        XCTAssertTrue(sentence.contains("空调保持模式"), "got: \(sentence)")
        XCTAssertFalse(sentence.contains("vehicle."), "raw entity leaked: \(sentence)")
    }

    func test_stateDuration_numericOp_renders() {
        let s = spec("""
        {"kind": "lowBattery", "trigger": {
            "type": "state_duration",
            "entity": "vehicle.battery_level",
            "op": "<",
            "value": 30,
            "for_minutes": 1,
            "state_key": "k"
        }}
        """)
        let sentence = RuleDisplay.triggerSentence(s)
        XCTAssertTrue(sentence.contains("电量百分比"), "got: \(sentence)")
        XCTAssertTrue(sentence.contains("低于 30"), "got: \(sentence)")
        XCTAssertFalse(sentence.contains("vehicle."), "raw entity leaked: \(sentence)")
    }

    // MARK: - state_transition

    func test_stateTransition_chargeComplete_renders() {
        let s = spec("""
        {"kind": "chargeComplete", "trigger": {
            "type": "state_transition",
            "entity": "vehicle.charging.state",
            "to": "Complete",
            "first_seen_key": "f",
            "dismissed_key": "d"
        }}
        """)
        let sentence = RuleDisplay.triggerSentence(s)
        XCTAssertTrue(sentence.contains("充电状态"), "got: \(sentence)")
        XCTAssertFalse(sentence.contains("vehicle."), "raw entity leaked: \(sentence)")
    }

    // MARK: - cron

    func test_cron_renders_chinese() {
        let s = spec("""
        {"kind": "weekdayPreheat", "trigger": {
            "type": "cron",
            "expr": "30 7 * * 1-5",
            "tz": "Asia/Shanghai"
        }}
        """)
        let sentence = RuleDisplay.triggerSentence(s)
        XCTAssertTrue(sentence.contains("每个工作日"), "got: \(sentence)")
    }

    // MARK: - geofence

    func test_geofence_placeholder_signals_unconfigured() {
        let s = spec("""
        {"kind": "geofenceEnter", "trigger": {
            "type": "geofence",
            "lat": 0,
            "lng": 0,
            "radius_m": 200,
            "event": "enter"
        }}
        """)
        let sentence = RuleDisplay.triggerSentence(s)
        XCTAssertTrue(sentence.contains("待选择"), "placeholder must call out: \(sentence)")
    }

    func test_geofence_realLatLng_renders() {
        let s = spec("""
        {"kind": "geofenceEnter", "trigger": {
            "type": "geofence",
            "lat": 39.9087,
            "lng": 116.3974,
            "radius_m": 200,
            "event": "enter"
        }}
        """)
        let sentence = RuleDisplay.triggerSentence(s)
        XCTAssertTrue(sentence.contains("进入"), "got: \(sentence)")
        XCTAssertTrue(sentence.contains("200m"), "got: \(sentence)")
        XCTAssertFalse(sentence.contains("待选择"), "real lat/lng must not show 待选择: \(sentence)")
    }

    // MARK: - user_departure (B3) — must NOT leak raw entity keys

    func test_userDeparture_locked_check_no_raw_leak() {
        let s = spec("""
        {"kind": "leftUnlocked", "trigger": {
            "type": "user_departure",
            "check": {"entity": "vehicle.locked", "op": "==", "value": false},
            "last_eval_key": "k"
        }}
        """)
        let sentence = RuleDisplay.triggerSentence(s)
        XCTAssertTrue(sentence.contains("下车后"), "user_departure must say 下车后: \(sentence)")
        XCTAssertTrue(sentence.contains("车锁"), "entity must be localized: \(sentence)")
        XCTAssertFalse(sentence.contains("vehicle."), "raw entity leaked: \(sentence)")
    }

    func test_userDeparture_trunk_open_no_raw_leak() {
        // Regression for the bd21fb5 bug — trunk_open shown as
        // "vehicle.trunk_open" in builder list.
        let s = spec("""
        {"kind": "closureLeftOpen", "trigger": {
            "type": "user_departure",
            "check": {"entity": "vehicle.trunk_open", "op": "==", "value": true},
            "last_eval_key": "k"
        }}
        """)
        let sentence = RuleDisplay.triggerSentence(s)
        XCTAssertTrue(sentence.contains("后备箱"), "got: \(sentence)")
        XCTAssertFalse(sentence.contains("vehicle."), "raw entity leaked: \(sentence)")
    }

    func test_userDeparture_with_geofence_gate_renders_prefix() {
        let s = spec("""
        {"kind": "sentryMode", "trigger": {
            "type": "user_departure",
            "check": {"entity": "vehicle.sentry_mode_on", "op": "==", "value": false},
            "last_eval_key": "k",
            "at_geofence": {"lat": 39.9, "lng": 116.4, "radius_m": 200}
        }}
        """)
        let sentence = RuleDisplay.triggerSentence(s)
        XCTAssertTrue(sentence.contains("范围内"), "geofence gate prefix missing: \(sentence)")
        XCTAssertTrue(sentence.contains("哨兵模式"), "got: \(sentence)")
    }

    func test_userDeparture_with_placeholder_geofence_says_pending() {
        let s = spec("""
        {"kind": "sentryMode", "trigger": {
            "type": "user_departure",
            "check": {"entity": "vehicle.sentry_mode_on", "op": "==", "value": false},
            "last_eval_key": "k",
            "at_geofence": {"lat": 0, "lng": 0, "radius_m": 200}
        }}
        """)
        let sentence = RuleDisplay.triggerSentence(s)
        XCTAssertTrue(sentence.contains("待选择"), "placeholder geofence must flag pending: \(sentence)")
    }

    // MARK: - entity name parity guard

    /// Every entity backend's _ENTITY_MAP knows about must map to a
    /// Chinese name on iOS. scripts/audit_entity_parity.py is the
    /// CI-level guard; this is a faster unit-test check covering
    /// the same set so a developer running `swift test` catches drift
    /// without waiting for precommit.
    func test_all_known_entities_have_chinese_names() {
        let knownEntities = [
            "vehicle.climate.keeper_mode",
            "vehicle.sentry_mode_on",
            "vehicle.cabin_overheat_protection_on",
            "vehicle.charging.state",
            "vehicle.battery_level",
            "vehicle.locked",
            "vehicle.shift_state",
            "vehicle.parked_unlocked",
            "vehicle.parked_with_door_open",
            "vehicle.parked_with_window_open",
            "vehicle.parked_with_frunk_open",
            "vehicle.parked_with_trunk_open",
            "vehicle.door_open",
            "vehicle.window_open",
            "vehicle.frunk_open",
            "vehicle.trunk_open",
            "vehicle.location.latitude",
            "vehicle.location.longitude",
            "vehicle.inside_temp_c",
            "vehicle.outside_temp_c",
            "vehicle.speed_kmh",
            "vehicle.charger_power_kw",
            "vehicle.software_version",
            "vehicle.connectivity",
        ]
        for entity in knownEntities {
            let name = RuleDisplay.entityName(entity)
            XCTAssertNotEqual(
                name, entity,
                "RuleDisplay.entityName(\(entity)) fell through to raw key — add a case in RuleDisplay.swift",
            )
            XCTAssertFalse(
                name.contains("vehicle."),
                "RuleDisplay.entityName(\(entity)) = \(name) — Chinese name must not contain vehicle.*",
            )
        }
    }

    // MARK: - isHiddenInPicker (vehicle_config-driven gating)

    func test_isHiddenInPicker_navSendAddress_alwaysHidden() {
        // Wire-format twin of tesla.navigation.send; client surfaces
        // only the unified "发送导航目的地" entry. Hidden regardless
        // of vehicle config.
        XCTAssertTrue(RuleDisplay.isHiddenInPicker(
            "tesla.navigation.send_address", vehicleConfig: nil,
        ))
        XCTAssertTrue(RuleDisplay.isHiddenInPicker(
            "tesla.navigation.send_address",
            vehicleConfig: VehicleConfig(carType: "models", roofColor: "Sunroof"),
        ))
    }

    func test_isHiddenInPicker_sunRoof_hiddenOnModelY() {
        let modelY = VehicleConfig(carType: "modely", roofColor: "Glass")
        XCTAssertTrue(RuleDisplay.isHiddenInPicker(
            "tesla.closures.sun_roof_vent", vehicleConfig: modelY,
        ))
        XCTAssertTrue(RuleDisplay.isHiddenInPicker(
            "tesla.closures.sun_roof_close", vehicleConfig: modelY,
        ))
    }

    func test_isHiddenInPicker_sunRoof_visibleOnModelS() {
        let modelS = VehicleConfig(carType: "models", roofColor: "Sunroof")
        XCTAssertFalse(RuleDisplay.isHiddenInPicker(
            "tesla.closures.sun_roof_vent", vehicleConfig: modelS,
        ))
        XCTAssertFalse(RuleDisplay.isHiddenInPicker(
            "tesla.closures.sun_roof_close", vehicleConfig: modelS,
        ))
    }

    func test_isHiddenInPicker_sunRoof_visibleWhenConfigUnknown() {
        // First-launch / cold-cache safety: rather than hide every
        // model-specific capability, show them all until /state lands.
        XCTAssertFalse(RuleDisplay.isHiddenInPicker(
            "tesla.closures.sun_roof_vent", vehicleConfig: nil,
        ))
    }

    func test_isHiddenInPicker_chargePort_hiddenWhenManual() {
        let manualPort = VehicleConfig(motorizedChargePort: false)
        XCTAssertTrue(RuleDisplay.isHiddenInPicker(
            "tesla.charging.port_open", vehicleConfig: manualPort,
        ))
        XCTAssertTrue(RuleDisplay.isHiddenInPicker(
            "tesla.charging.port_close", vehicleConfig: manualPort,
        ))
    }

    func test_isHiddenInPicker_unrelatedCapability_alwaysVisible() {
        let any = VehicleConfig(carType: "modely", roofColor: "Glass")
        XCTAssertFalse(RuleDisplay.isHiddenInPicker(
            "tesla.security.door_lock", vehicleConfig: any,
        ))
        XCTAssertFalse(RuleDisplay.isHiddenInPicker(
            "tesla.climate.preheat", vehicleConfig: any,
        ))
    }
}
