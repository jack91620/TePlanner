import SwiftUI
import TePlannerKit

/// App-level shell. Hands LoginView/HomeView the same long-lived
/// dependencies (single APIService instance, single AuthSession) and
/// switches between them based on whether the user is logged in.
struct RootView: View {
    @StateObject private var authSession = AuthSession()
    private let apiService: APIServiceProtocol = APIService.shared

    var body: some View {
        Group {
            if authSession.isLoggedIn {
                NavigationStack {
                    HomeView(apiService: apiService, authSession: authSession)
                        .navigationTitle("TePlanner")
                        .navigationBarTitleDisplayMode(.inline)
                }
            } else {
                LoginView(apiService: apiService, authSession: authSession)
            }
        }
    }
}

#Preview {
    RootView()
}
