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
                    HubView(apiService: apiService, authSession: authSession)
                }
            } else {
                LoginView(apiService: apiService, authSession: authSession)
            }
        }
        .onChange(of: authSession.isLoggedIn) { _, newValue in
            Log.app.notice("auth state → \(newValue ? "logged in" : "logged out", privacy: .public)")
        }
        .onAppear {
            Log.app.notice("RootView appeared (logged in=\(authSession.isLoggedIn, privacy: .public))")
        }
    }
}

#Preview {
    RootView()
}
