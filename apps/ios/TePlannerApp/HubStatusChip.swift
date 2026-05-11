import Foundation
import SwiftUI

/// 2026-05-11 — top-level chip schema for HubView's currentStateChips.
///
/// Lives here (not nested inside HubView) so SwiftUI's type inference
/// on `@State var pendingChipAction: HubStatusChip?` etc. doesn't
/// blow the body type-checker budget. Nested types inside view
/// bodies trip the "compiler unable to type-check this expression in
/// reasonable time" diagnostic far more easily.
///
/// `action` non-nil → chip is tappable. Tap surfaces a
/// confirmationDialog with `confirmTitle`; on confirm the closure
/// runs (typically posting a VCP command).
/// `action` nil → display-only (e.g. "充电中", "座舱过热保护" — no
/// useful tap-action in the current product).
struct HubStatusChip: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
    let color: Color
    let confirmTitle: String?
    let action: (() async -> Void)?

    var isTappable: Bool { action != nil }
}
