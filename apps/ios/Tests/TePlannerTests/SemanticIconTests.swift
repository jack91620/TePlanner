import XCTest
@testable import TePlannerKit

/// Catch the silent regression where someone adds an SF Symbol to
/// HubActionIconLibrary but forgets the matching semantic ID — that
/// row would share as the fallback "bolt" and confuse importers.
final class SemanticIconTests: XCTestCase {
    func test_every_picker_icon_has_a_semantic_id() {
        for sym in HubActionIconLibrary.all {
            XCTAssertNotNil(
                SemanticIcon.symbolToSemantic[sym],
                "Add a semantic ID for SF Symbol '\(sym)' to SemanticIcon.symbolToSemantic"
            )
        }
    }

    func test_round_trip_iOS_symbol_to_semantic_and_back() {
        for sym in HubActionIconLibrary.all {
            let sem = SemanticIcon.semantic(for: sym)
            let back = SemanticIcon.symbol(for: sem)
            XCTAssertEqual(back, sym, "round-trip broke for \(sym) → \(sem) → \(back)")
        }
    }

    func test_unknown_semantic_falls_back_to_bolt() {
        XCTAssertEqual(SemanticIcon.symbol(for: "no-such-thing"), "bolt.fill")
    }

    func test_unknown_symbol_falls_back_to_bolt() {
        XCTAssertEqual(SemanticIcon.semantic(for: "no.such.symbol"), "bolt")
    }
}
