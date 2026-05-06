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
    public let distanceKm: Double?
    public let distanceFromRouteM: Int?
    public let open24h: Bool
    public let amenities: [String]?

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
        distanceKm: Double? = nil,
        distanceFromRouteM: Int? = nil,
        open24h: Bool = false,
        amenities: [String]? = nil
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
        self.distanceKm = distanceKm
        self.distanceFromRouteM = distanceFromRouteM
        self.open24h = open24h
        self.amenities = amenities
    }

    public enum CodingKeys: String, CodingKey {
        case id, name, address, latitude, longitude, type
        case availableStalls = "available_stalls"
        case totalStalls = "total_stalls"
        case powerKw = "power_kw"
        case operatorName = "operator"
        case distanceKm = "distance_km"
        case distanceFromRouteM = "distance_from_route_m"
        case open24h = "open_24h"
        case amenities
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
        totalStalls = try c.decodeIfPresent(Int.self, forKey: .totalStalls)
        powerKw = try c.decodeIfPresent(Int.self, forKey: .powerKw)
        operatorName = try c.decodeIfPresent(String.self, forKey: .operatorName)
        distanceKm = try c.decodeIfPresent(Double.self, forKey: .distanceKm)
        distanceFromRouteM = try c.decodeIfPresent(Int.self, forKey: .distanceFromRouteM)
        open24h = try c.decodeIfPresent(Bool.self, forKey: .open24h) ?? false
        amenities = try c.decodeIfPresent([String].self, forKey: .amenities)
    }
}
