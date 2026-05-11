import Foundation

public enum ChargingStationType: String, Codable, CaseIterable {
    case supercharger
    case destination
    case ccs
    case chademo
    case gbT = "gb_t"
    case other

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ChargingStationType(rawValue: raw.lowercased()) ?? .other
    }
}

public struct ChargingStation: Codable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let address: String?
    public let latitude: Double
    public let longitude: Double
    public let type: ChargingStationType
    public let availableStalls: Int?
    public let totalStalls: Int?
    public let powerKw: Int?
    public let operatorName: String?
    public let tel: String?
    public let distanceKm: Double?
    public let distanceFromRouteM: Int?
    public let open24h: Bool
    public let amenities: [String]?
    public let openHours: String?
    /// Photos hosted on AMap CDN (store.is.autonavi.com). Empty when
    /// the POI has none. Order is AMap's — first photo is usually
    /// the most representative.
    public let photos: [String]
    /// AMap 0–5 rating (e.g. 4.4). nil when the POI has too few
    /// reviews to score.
    public let rating: Double?
    /// Entrance pin coords if AMap returned `entr_location` — the
    /// front door pin, not the polygon centroid that `latitude/
    /// longitude` give. ~50–100m offset for roadside stations.
    public let entranceLatitude: Double?
    public let entranceLongitude: Double?

    public init(
        id: String,
        name: String,
        address: String? = nil,
        latitude: Double,
        longitude: Double,
        type: ChargingStationType = .other,
        availableStalls: Int? = nil,
        totalStalls: Int? = nil,
        powerKw: Int? = nil,
        operatorName: String? = nil,
        tel: String? = nil,
        distanceKm: Double? = nil,
        distanceFromRouteM: Int? = nil,
        open24h: Bool = false,
        amenities: [String]? = nil,
        openHours: String? = nil,
        photos: [String] = [],
        rating: Double? = nil,
        entranceLatitude: Double? = nil,
        entranceLongitude: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.type = type
        self.availableStalls = availableStalls
        self.totalStalls = totalStalls
        self.powerKw = powerKw
        self.operatorName = operatorName
        self.tel = tel
        self.distanceKm = distanceKm
        self.distanceFromRouteM = distanceFromRouteM
        self.open24h = open24h
        self.amenities = amenities
        self.openHours = openHours
        self.photos = photos
        self.rating = rating
        self.entranceLatitude = entranceLatitude
        self.entranceLongitude = entranceLongitude
    }

    public enum CodingKeys: String, CodingKey {
        case id, name, address, latitude, longitude, type, tel, amenities, photos, rating
        // Backend `/charging/nearby` returns `available_ports`/`total_ports`;
        // older planner code used `available_stalls`/`total_stalls`. Accept both.
        case availableStalls = "available_stalls"
        case availablePorts = "available_ports"
        case totalStalls = "total_stalls"
        case totalPorts = "total_ports"
        case powerKw = "power_kw"
        case operatorName = "operator"
        case distanceKm = "distance_km"
        case distanceFromRouteM = "distance_from_route_m"
        case open24h = "open_24h"
        case openHours = "open_hours"
        case entranceLatitude = "entrance_latitude"
        case entranceLongitude = "entrance_longitude"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        address = try c.decodeIfPresent(String.self, forKey: .address)
        latitude = try c.decode(Double.self, forKey: .latitude)
        longitude = try c.decode(Double.self, forKey: .longitude)
        type = try c.decodeIfPresent(ChargingStationType.self, forKey: .type) ?? .other
        availableStalls = try c.decodeIfPresent(Int.self, forKey: .availableStalls)
            ?? c.decodeIfPresent(Int.self, forKey: .availablePorts)
        totalStalls = try c.decodeIfPresent(Int.self, forKey: .totalStalls)
            ?? c.decodeIfPresent(Int.self, forKey: .totalPorts)
        powerKw = try c.decodeIfPresent(Int.self, forKey: .powerKw)
        operatorName = try c.decodeIfPresent(String.self, forKey: .operatorName)
        tel = try c.decodeIfPresent(String.self, forKey: .tel)
        distanceKm = try c.decodeIfPresent(Double.self, forKey: .distanceKm)
        distanceFromRouteM = try c.decodeIfPresent(Int.self, forKey: .distanceFromRouteM)
        open24h = try c.decodeIfPresent(Bool.self, forKey: .open24h) ?? false
        amenities = try c.decodeIfPresent([String].self, forKey: .amenities)
        openHours = try c.decodeIfPresent(String.self, forKey: .openHours)
        photos = try c.decodeIfPresent([String].self, forKey: .photos) ?? []
        rating = try c.decodeIfPresent(Double.self, forKey: .rating)
        entranceLatitude = try c.decodeIfPresent(Double.self, forKey: .entranceLatitude)
        entranceLongitude = try c.decodeIfPresent(Double.self, forKey: .entranceLongitude)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(address, forKey: .address)
        try c.encode(latitude, forKey: .latitude)
        try c.encode(longitude, forKey: .longitude)
        try c.encode(type, forKey: .type)
        try c.encodeIfPresent(availableStalls, forKey: .availableStalls)
        try c.encodeIfPresent(totalStalls, forKey: .totalStalls)
        try c.encodeIfPresent(powerKw, forKey: .powerKw)
        try c.encodeIfPresent(operatorName, forKey: .operatorName)
        try c.encodeIfPresent(tel, forKey: .tel)
        try c.encodeIfPresent(distanceKm, forKey: .distanceKm)
        try c.encodeIfPresent(distanceFromRouteM, forKey: .distanceFromRouteM)
        try c.encode(open24h, forKey: .open24h)
        try c.encodeIfPresent(amenities, forKey: .amenities)
        try c.encodeIfPresent(openHours, forKey: .openHours)
        if !photos.isEmpty { try c.encode(photos, forKey: .photos) }
        try c.encodeIfPresent(rating, forKey: .rating)
        try c.encodeIfPresent(entranceLatitude, forKey: .entranceLatitude)
        try c.encodeIfPresent(entranceLongitude, forKey: .entranceLongitude)
    }
}

/// Wrapper for `GET /charging/nearby` response. The endpoint returns
/// `{count, stations}` rather than a bare array.
public struct NearbyChargingResponse: Codable {
    public let count: Int
    public let stations: [ChargingStation]
}
