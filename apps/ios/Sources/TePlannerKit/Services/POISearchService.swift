import Foundation

/// AMap POI search abstraction. Concrete implementation
/// (`AMapPOISearchService`) lives in the app target since it depends on
/// `AMapSearchKit`. The protocol stays here so view models and tests can
/// swap in mocks without pulling AMap into TePlannerKit.
public protocol POISearchService: Sendable {
    /// Free-text keyword search, optionally scoped to a city
    /// (name or adcode). City "" means search nationwide.
    func searchByKeyword(_ keyword: String, city: String) async -> Result<[POIResult], POISearchError>

    /// Search POIs around a coordinate within `radius` meters.
    /// Used for "nearby chargers" later in Phase 2/3.
    func searchAround(
        keyword: String,
        latitude: Double,
        longitude: Double,
        radiusMeters: Int
    ) async -> Result<[POIResult], POISearchError>
}

public enum POISearchError: Error, Equatable {
    case emptyQuery
    case sdkError(code: Int, message: String)
    case unknown
}
