import SwiftUI
import TePlannerKit // Import the new library module

@main
struct TePlannerApp: App {
    // The ViewModel is now created and owned by the App, ensuring it persists.
    @StateObject private var viewModel = ContentViewModel()

    var body: some Scene {
        WindowGroup {
            // The single instance of the ViewModel is passed to the ContentView.
            ContentView(viewModel: viewModel)
        }
    }
}
