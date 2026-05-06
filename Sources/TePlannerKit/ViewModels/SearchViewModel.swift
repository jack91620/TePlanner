import Foundation
import Combine

/// Drives the search screen: debounced keyword input, async POI lookup,
/// state for the result list / loading / error / empty states. Mirrors
/// the Android `SearchViewModel`'s 300ms debounce + cancel-previous-job
/// pattern via `Task` cancellation.
@MainActor
public final class SearchViewModel: ObservableObject {
    public enum State: Equatable {
        case idle
        case searching
        case results([POIResult])
        case empty
        case error(String)
    }

    @Published public private(set) var state: State = .idle
    @Published public private(set) var query: String = ""

    private let service: POISearchService
    private let debounceMillis: UInt64
    private var debounceTask: Task<Void, Never>?

    public init(service: POISearchService, debounceMillis: UInt64 = 300) {
        self.service = service
        self.debounceMillis = debounceMillis
    }

    /// Update the keyword. Triggers a debounced search; an empty
    /// keyword resets to .idle and cancels any in-flight search.
    public func updateQuery(_ newValue: String) {
        query = newValue
        debounceTask?.cancel()

        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            state = .idle
            return
        }

        debounceTask = Task { [weak self, debounceMillis] in
            try? await Task.sleep(nanoseconds: debounceMillis * 1_000_000)
            guard !Task.isCancelled else { return }
            await self?.performSearch(trimmed)
        }
    }

    /// Run the search immediately, skipping the debounce. Useful for
    /// "submit" actions on the keyboard.
    public func searchNow() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            await self?.performSearch(trimmed)
        }
    }

    public func clear() {
        debounceTask?.cancel()
        query = ""
        state = .idle
    }

    private func performSearch(_ keyword: String) async {
        state = .searching
        Log.search.notice("performSearch start (q=\(keyword, privacy: .private(mask: .hash)))")

        let result = await service.searchByKeyword(keyword, city: "")
        guard !Task.isCancelled else { return }

        switch result {
        case .success(let pois):
            Log.search.notice("performSearch success (count=\(pois.count, privacy: .public))")
            state = pois.isEmpty ? .empty : .results(pois)
        case .failure(let error):
            Log.search.error("performSearch failed: \(error.message, privacy: .public)")
            state = .error(error.message)
        }
    }
}

private extension POISearchError {
    var message: String {
        switch self {
        case .emptyQuery: return "请输入搜索关键词"
        case .sdkError(let code, let message): return "搜索失败 (\(code)): \(message)"
        case .unknown: return "搜索失败，请稍后重试"
        }
    }
}
