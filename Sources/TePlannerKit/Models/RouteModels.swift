import Foundation

// MARK: - Data Models to match the Backend API response

public struct RoutePlanResponse: Codable, Identifiable {
    public let routeId: Int?
    public var id: Int { routeId ?? UUID().hashValue }
    public let origin: LocationDetail
    public let destination: LocationDetail
    public let totalDistanceKm: Double
    public let totalDurationMinutes: Int
    public let drivingDurationMinutes: Int
    public let chargingDurationMinutes: Int
    public let chargingStops: [ChargingStop]
    public let numChargingStops: Int
    public let initialSoc: Int
    public let arrivalSoc: Int
    public let polyline: [Coordinate]
    public let warnings: [String]
    
    public enum CodingKeys: String, CodingKey {
        case routeId = "route_id"
        case origin, destination
        case totalDistanceKm = "total_distance_km"
        case totalDurationMinutes = "total_duration_minutes"
        case drivingDurationMinutes = "driving_duration_minutes"
        case chargingDurationMinutes = "charging_duration_minutes"
        case chargingStops = "charging_stops"
        case numChargingStops = "num_charging_stops"
        case initialSoc = "initial_soc"
        case arrivalSoc = "arrival_soc"
        case polyline, warnings
    }
}

public struct LocationDetail: Codable {
    public let lat: Double?
    public let lng: Double?
    public let name: String
}

public struct ChargingStop: Codable, Identifiable {
    public let stationId: String
    public var id: String { stationId }
    public let name: String
    public let latitude: Double
    public let longitude: Double
    public let address: String?
    public let operatorName: String?
    public let distanceFromStartKm: Double
    public let arrivalSoc: Int
    public let departureSoc: Int
    public let chargingDurationMinutes: Int

    public enum CodingKeys: String, CodingKey {
        case stationId = "station_id"
        case name, latitude, longitude, address
        case operatorName = "operator"
        case distanceFromStartKm = "distance_from_start_km"
        case arrivalSoc = "arrival_soc"
        case departureSoc = "departure_soc"
        case chargingDurationMinutes = "charging_duration_minutes"
    }
}

public struct Coordinate: Codable {
    public let latitude: Double
    public let longitude: Double
}

// MARK: - Request Models for the Backend API

public struct LocationInput: Codable {
    public let latitude: Double
    public let longitude: Double
    public let address: String?

    public init(latitude: Double, longitude: Double, address: String?) {
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
    }
}

// MARK: - Geocoding Models

public struct GeocodeRequest: Codable {
    public let address: String
}

public struct GeocodeResponse: Codable {
    public let latitude: Double
    public let longitude: Double
    public let address: String
    public let formattedAddress: String?

    public enum CodingKeys: String, CodingKey {
        case latitude, longitude, address
        case formattedAddress = "formatted_address"
    }
}

/// Response from POST /routes/reverse-geocode. Backend may return
/// either a Tencent-style "address" or a city/district recommendation
/// in `formatted_address`. UI prefers the formatted one when present.
public struct ReverseGeocodeResponse: Codable {
    public let latitude: Double
    public let longitude: Double
    public let address: String?
    public let formattedAddress: String?

    public enum CodingKeys: String, CodingKey {
        case latitude, longitude, address
        case formattedAddress = "formatted_address"
    }

    public var displayName: String? {
        if let f = formattedAddress, !f.isEmpty { return f }
        if let a = address, !a.isEmpty { return a }
        return nil
    }
}

// MARK: - Recent / saved routes (GET /routes/)

public struct RecentRoutesResponse: Codable {
    public let count: Int
    public let routes: [RecentRoute]
}

public struct RecentRoute: Codable, Identifiable, Equatable {
    public let id: Int
    public let origin: RouteEndpoint
    public let destination: RouteEndpoint
    public let totalDistanceKm: Double?
    public let totalDurationMinutes: Int?
    public let status: String?
    public let createdAt: String?

    public enum CodingKeys: String, CodingKey {
        case id, origin, destination, status
        case totalDistanceKm = "total_distance_km"
        case totalDurationMinutes = "total_duration_minutes"
        case createdAt = "created_at"
    }
}

public struct RouteEndpoint: Codable, Equatable {
    public let lat: Double?
    public let lng: Double?
    public let address: String?
}
