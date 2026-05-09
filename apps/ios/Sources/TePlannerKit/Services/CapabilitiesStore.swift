import Foundation
import Combine

/// Caches the backend's capability registry so the visual builder can
/// render action-block pickers without hardcoded knowledge of each
/// capability's params. Fetched once per app launch from
/// `/api/v1/automations/capabilities`.
@MainActor
public final class CapabilitiesStore: ObservableObject {
    @Published public private(set) var capabilities: [CapabilityInfo] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var lastError: String?

    private let apiService: APIServiceProtocol

    public init(apiService: APIServiceProtocol) {
        self.apiService = apiService
    }

    public func refreshIfNeeded() async {
        if !capabilities.isEmpty { return }
        await refresh()
    }

    public func refresh() async {
        isLoading = true
        defer { isLoading = false }
        let result = await apiService.listCapabilities()
        switch result {
        case .success(let list):
            capabilities = list
            lastError = nil
        case .failure(let err):
            lastError = err.localizedDescription
        }
    }

    public func get(_ id: String) -> CapabilityInfo? {
        capabilities.first { $0.id == id }
    }

    /// Filter by safety class — used by the builder to default to
    /// the "safe" subset and require an "I understand" toggle for the
    /// rest.
    public func capabilities(matching predicate: (CapabilityInfo) -> Bool) -> [CapabilityInfo] {
        capabilities.filter(predicate)
    }
}
