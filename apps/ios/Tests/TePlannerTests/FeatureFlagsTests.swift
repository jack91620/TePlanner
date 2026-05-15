import XCTest
@testable import TePlannerKit

/// Pins the FeatureFlags registry contract — particularly the
/// production default for `chargingPlanning` (must remain OFF until
/// the multi-stop trip pipeline graduates from internal testing).
@MainActor
final class FeatureFlagsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clean slate per test — a leaked override from a prior run
        // would make these assertions non-deterministic.
        for flag in FeatureFlags.Flag.allCases {
            FeatureFlags.setOverride(flag, to: nil)
        }
    }

    override func tearDown() {
        for flag in FeatureFlags.Flag.allCases {
            FeatureFlags.setOverride(flag, to: nil)
        }
        super.tearDown()
    }

    func testChargingPlanningDefaultsOff() {
        // App Store users must NOT see the planning entry until we
        // re-enable. If this test ever fails, the v1 hide-the-feature
        // promise is broken.
        XCTAssertFalse(FeatureFlags.isOn(.chargingPlanning))
        XCTAssertFalse(FeatureFlags.Flag.chargingPlanning.defaultValue)
    }

    func testOverrideTakesEffectImmediately() {
        FeatureFlags.setOverride(.chargingPlanning, to: true)
        XCTAssertTrue(FeatureFlags.isOn(.chargingPlanning))

        FeatureFlags.setOverride(.chargingPlanning, to: false)
        XCTAssertFalse(FeatureFlags.isOn(.chargingPlanning))
    }

    func testNilOverrideRestoresDefault() {
        FeatureFlags.setOverride(.chargingPlanning, to: true)
        XCTAssertTrue(FeatureFlags.isOn(.chargingPlanning))

        FeatureFlags.setOverride(.chargingPlanning, to: nil)
        XCTAssertFalse(FeatureFlags.isOn(.chargingPlanning))
    }

    func testFlagMetadataNonEmpty() {
        // Every flag must carry a displayName + description so the
        // Settings toggle has something to render.
        for flag in FeatureFlags.Flag.allCases {
            XCTAssertFalse(flag.displayName.isEmpty,
                           "\(flag.rawValue) has empty displayName")
            XCTAssertFalse(flag.description.isEmpty,
                           "\(flag.rawValue) has empty description")
            XCTAssertTrue(flag.rawValue.hasPrefix("feature."),
                          "\(flag.rawValue) must use the feature.* UserDefaults namespace")
        }
    }
}
