import Foundation

/// Drives the "最近" tab — a list of past route plans the backend
/// saved for the user. Server-side endpoint is `GET /routes/?limit&offset`.
@MainActor
public final class RecentTripsViewModel: ObservableObject {
    public enum State: Equatable {
        case idle
        case loading
        case loaded([RecentRoute])
        case empty
        case error(String)
    }

    @Published public private(set) var state: State = .idle

    private let apiService: APIServiceProtocol
    private let pageSize: Int

    public init(apiService: APIServiceProtocol, pageSize: Int = 20) {
        self.apiService = apiService
        self.pageSize = pageSize
    }

    public func load() async {
        state = .loading
        Log.search.notice("recent trips load (limit=\(self.pageSize, privacy: .public))")
        let result = await apiService.getRecentRoutes(limit: pageSize, offset: 0)
        switch result {
        case .success(let response):
            Log.search.notice("recent trips ok (count=\(response.count, privacy: .public))")
            state = response.routes.isEmpty ? .empty : .loaded(response.routes)
        case .failure(let error):
            Log.search.error("recent trips failed: \(error.localizedDescription, privacy: .public)")
            state = .error(error.localizedDescription)
        }
    }
}
