import Foundation

/// A single point-of-interest result from AMap search. Mirrors the
/// fields in Android's `SearchResult` (`ui/search/SearchResult.kt`):
/// id + name + address + lat/lng, with optional distance for "search
/// around a center" queries and city for keyword-only queries.
public struct POIResult: Identifiable, Equatable, Codable {
    public let id: String
    public let name: String
    public let address: String
    public let latitude: Double
    public let longitude: Double
    public let distance: Double?
    public let cityName: String?

    public init(
        id: String,
        name: String,
        address: String,
        latitude: Double,
        longitude: Double,
        distance: Double? = nil,
        cityName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.distance = distance
        self.cityName = cityName
    }
}
