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
    /// Optional now (was required-non-empty). Backend emits null when
    /// the reverse-geocode for this lat/lng failed; UI should fall
    /// back to "未知地点" or just show the coordinate string.
    public let name: String?
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
    /// New 2026-05-11 — extras pulled through from AMap so the
    /// along-route stop list can open the same detail sheet as
    /// nearby stations. All optional / default-empty so old
    /// fixtures + backends still decode.
    public let tel: String?
    public let photos: [String]
    public let rating: Double?
    public let openHours: String?
    public let open24h: Bool

    public enum CodingKeys: String, CodingKey {
        case stationId = "station_id"
        case name, latitude, longitude, address, tel, photos, rating
        case operatorName = "operator"
        case distanceFromStartKm = "distance_from_start_km"
        case arrivalSoc = "arrival_soc"
        case departureSoc = "departure_soc"
        case chargingDurationMinutes = "charging_duration_minutes"
        case openHours = "open_hours"
        case open24h = "open_24h"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stationId = try c.decode(String.self, forKey: .stationId)
        name = try c.decode(String.self, forKey: .name)
        latitude = try c.decode(Double.self, forKey: .latitude)
        longitude = try c.decode(Double.self, forKey: .longitude)
        address = try c.decodeIfPresent(String.self, forKey: .address)
        operatorName = try c.decodeIfPresent(String.self, forKey: .operatorName)
        distanceFromStartKm = try c.decode(Double.self, forKey: .distanceFromStartKm)
        arrivalSoc = try c.decode(Int.self, forKey: .arrivalSoc)
        departureSoc = try c.decode(Int.self, forKey: .departureSoc)
        chargingDurationMinutes = try c.decode(Int.self, forKey: .chargingDurationMinutes)
        tel = try c.decodeIfPresent(String.self, forKey: .tel)
        photos = try c.decodeIfPresent([String].self, forKey: .photos) ?? []
        rating = try c.decodeIfPresent(Double.self, forKey: .rating)
        openHours = try c.decodeIfPresent(String.self, forKey: .openHours)
        open24h = try c.decodeIfPresent(Bool.self, forKey: .open24h) ?? false
    }

    public init(
        stationId: String,
        name: String,
        latitude: Double,
        longitude: Double,
        address: String? = nil,
        operatorName: String? = nil,
        distanceFromStartKm: Double,
        arrivalSoc: Int,
        departureSoc: Int,
        chargingDurationMinutes: Int,
        tel: String? = nil,
        photos: [String] = [],
        rating: Double? = nil,
        openHours: String? = nil,
        open24h: Bool = false
    ) {
        self.stationId = stationId
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.operatorName = operatorName
        self.distanceFromStartKm = distanceFromStartKm
        self.arrivalSoc = arrivalSoc
        self.departureSoc = departureSoc
        self.chargingDurationMinutes = chargingDurationMinutes
        self.tel = tel
        self.photos = photos
        self.rating = rating
        self.openHours = openHours
        self.open24h = open24h
    }

    /// Adapter so the route stop can be shown in the shared
    /// `ChargingStationDetailView`. Distance-along-route would be
    /// the wrong "distance" to show on a detail page (it's an
    /// answer to a different question), so we pass nil and let the
    /// detail view's "距离" row hide.
    public func toStation() -> ChargingStation {
        ChargingStation(
            id: stationId,
            name: name,
            address: address,
            latitude: latitude,
            longitude: longitude,
            operatorName: operatorName,
            tel: tel,
            distanceKm: nil,
            open24h: open24h,
            openHours: openHours,
            photos: photos,
            rating: rating
        )
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

// MARK: - POST /routes/save (record a trip in 最近 history)

public struct SaveRoutePlanLocation: Codable, Equatable {
    public let latitude: Double
    public let longitude: Double
    public let address: String?

    public init(latitude: Double, longitude: Double, address: String?) {
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
    }
}

public struct SaveRoutePlanChargingStop: Codable, Equatable {
    public let stationId: String?
    public let name: String?
    public let latitude: Double?
    public let longitude: Double?
    public let address: String?
    public let arrivalSoc: Int?
    public let departureSoc: Int?
    public let chargingDurationMinutes: Int?

    public init(
        stationId: String?,
        name: String?,
        latitude: Double?,
        longitude: Double?,
        address: String?,
        arrivalSoc: Int?,
        departureSoc: Int?,
        chargingDurationMinutes: Int?,
    ) {
        self.stationId = stationId
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.arrivalSoc = arrivalSoc
        self.departureSoc = departureSoc
        self.chargingDurationMinutes = chargingDurationMinutes
    }

    public enum CodingKeys: String, CodingKey {
        case stationId = "station_id"
        case name
        case latitude, longitude, address
        case arrivalSoc = "arrival_soc"
        case departureSoc = "departure_soc"
        case chargingDurationMinutes = "charging_duration_minutes"
    }
}

public struct SaveRoutePlanRequest: Codable, Equatable {
    public let origin: SaveRoutePlanLocation
    public let destination: SaveRoutePlanLocation
    public let totalDistanceKm: Double?
    public let totalDurationMinutes: Int?
    public let polylinePoints: [[Double]]?
    public let chargingStops: [SaveRoutePlanChargingStop]

    public init(
        origin: SaveRoutePlanLocation,
        destination: SaveRoutePlanLocation,
        totalDistanceKm: Double? = nil,
        totalDurationMinutes: Int? = nil,
        polylinePoints: [[Double]]? = nil,
        chargingStops: [SaveRoutePlanChargingStop] = [],
    ) {
        self.origin = origin
        self.destination = destination
        self.totalDistanceKm = totalDistanceKm
        self.totalDurationMinutes = totalDurationMinutes
        self.polylinePoints = polylinePoints
        self.chargingStops = chargingStops
    }

    public enum CodingKeys: String, CodingKey {
        case origin, destination
        case totalDistanceKm = "total_distance_km"
        case totalDurationMinutes = "total_duration_minutes"
        case polylinePoints = "polyline_points"
        case chargingStops = "charging_stops"
    }
}

public struct SaveRoutePlanResponse: Codable, Equatable {
    public let id: Int
    public let createdAt: String

    public enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
    }
}
