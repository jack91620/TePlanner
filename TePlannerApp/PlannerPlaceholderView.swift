import SwiftUI
import TePlannerKit

/// Placeholder confirming TePlannerKit is wired into the app bundle. The
/// existing planner ContentView is kept available during the Phase 1 → 2
/// transition; once HomeView replaces it we'll delete this file.
struct PlannerPlaceholderView: View {
    @StateObject private var viewModel = ContentViewModel()

    var body: some View {
        NavigationStack {
            ContentView(viewModel: viewModel)
                .navigationTitle("规划（旧版）")
        }
    }
}
