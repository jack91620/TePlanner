import Foundation
@testable import TePlannerKit

/// Helpers shared across the 4 automation rule tests. Phase 10.2
/// migrated from per-class rule structs to declarative JSON specs;
/// these helpers build custom specs (with mutated thresholds for
/// tests that explicitly exercise threshold edge cases) on top of the
/// hardcoded `PresetSpecs`.

func makeRecord(spec: RuleSpec, id: String = "test", presetId: String? = nil) -> RuleRecord {
    RuleRecord(id: id, presetId: presetId, name: "test", enabled: true, spec: spec, version: 1)
}

/// Returns a copy of `spec` with the trigger's `for_minutes` overridden.
func specWithThreshold(_ spec: RuleSpec, minutes: Int) -> RuleSpec {
    var out = spec
    if case .object(var trigger) = out["trigger"] ?? .null {
        trigger["for_minutes"] = .int(minutes)
        out["trigger"] = .object(trigger)
    }
    return out
}

/// Returns a copy of `spec` with `enabled` flipped.
func specEnabled(_ spec: RuleSpec, _ enabled: Bool) -> RuleSpec {
    var out = spec
    out["enabled"] = .bool(enabled)
    return out
}
