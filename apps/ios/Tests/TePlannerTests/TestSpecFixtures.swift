import Foundation
@testable import TePlannerKit

/// Phase D.6 — minimal RuleSpec fixtures for tests that previously
/// used the deleted `PresetSpecs.campMode` etc. We don't need a full
/// preset definition any more (engine doesn't evaluate); we just need
/// SOME well-formed spec so RuleRecord constructs and serialises.
enum TestSpecFixtures {
    /// Minimal `state_duration` spec mimicking the camp_mode preset's
    /// shape — kind, trigger, actions_above. Fits the tests that care
    /// about snooze gating + display ordering, not actual evaluation.
    static var campMode: RuleSpec {
        [
            "kind": .string("camp_mode"),
            "trigger": .object([
                "type": .string("state_duration"),
                "entity": .string("vehicle.climate.keeper_mode"),
                "equals": .int(3),
                "for_minutes": .int(120),
                "state_key": .string("camp_mode_first_seen"),
            ]),
            "actions_above": .array([]),
            "actions_below": .array([]),
        ]
    }
}
