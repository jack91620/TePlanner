import Foundation

/// Phase 8.2: shapes for the client-orchestrated route planning flow.
/// /routes/route returns just the polyline; iOS runs along-route POI
/// search via the AMap SDK; the resulting POIs go to /routes/charging-
/// plan to produce the greedy charging stops.

public struct RouteOnlyRequest: Codable, Sendable {
    public let origin: LocationInput
    public let destination: LocationInput

    public init(origin: LocationInput, destination: LocationInput) {
        self.origin = origin
        self.destination = destination
    }
}

public struct RouteOnlyResponse: Codable, Sendable {
    public let origin: LocationDetail
    public let destination: LocationDetail
    public let totalDistanceKm: Double
    public let drivingDurationMinutes: Int
    public let polyline: [Coordinate]

    public enum CodingKeys: String, CodingKey {
        case origin, destination, polyline
        case totalDistanceKm = "total_distance_km"
        case drivingDurationMinutes = "driving_duration_minutes"
    }
}

/// Single along-route POI as returned by `AlongRoutePOIProvider`.
/// Mirrors AMap iOS SDK's `AMapRoutePOI` minus SDK-specific types.
public struct AlongRoutePOI: Equatable, Sendable, Codable {
    public let id: String
    public let name: String
    public let latitude: Double
    public let longitude: Double
    /// Distance from start along the route in meters; 0 when SDK
    /// doesn't return one. Backend recomputes from polyline anyway,
    /// so this is informational only.
    public let routeDistanceMeters: Int

    public init(id: String, name: String, latitude: Double, longitude: Double, routeDistanceMeters: Int = 0) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.routeDistanceMeters = routeDistanceMeters
    }
}

/// Provider abstraction so RoutePreviewViewModel can stay in
/// TePlannerKit (no SDK dep) — App layer wires the AMap SDK impl
/// in `AlongRoutePOIService`.
public protocol AlongRoutePOIProvider: Sendable {
    func searchChargingStations(polyline: [Coordinate]) async throws -> [AlongRoutePOI]
}

public struct ChargingPlanRequest: Codable, Sendable {
    public let polyline: [[Double]]      // [[lat, lng], …]
    public let totalDistanceKm: Double
    public let candidatePois: [AlongRoutePOI]
    public let initialSoc: Int
    public let carType: String
    public let minArrivalSoc: Int
    public let vehicleRangeKm: Double?

    public init(
        polyline: [[Double]],
        totalDistanceKm: Double,
        candidatePois: [AlongRoutePOI],
        initialSoc: Int,
        carType: String = "model_y_long_range",
        minArrivalSoc: Int = 20,
        vehicleRangeKm: Double? = nil
    ) {
        self.polyline = polyline
        self.totalDistanceKm = totalDistanceKm
        self.candidatePois = candidatePois
        self.initialSoc = initialSoc
        self.carType = carType
        self.minArrivalSoc = minArrivalSoc
        self.vehicleRangeKm = vehicleRangeKm
    }

    public enum CodingKeys: String, CodingKey {
        case polyline
        case totalDistanceKm = "total_distance_km"
        case candidatePois = "candidate_pois"
        case initialSoc = "initial_soc"
        case carType = "car_type"
        case minArrivalSoc = "min_arrival_soc"
        case vehicleRangeKm = "vehicle_range_km"
    }
}

extension AlongRoutePOI {
    /// Encoding shape required by the backend's `POIInput`:
    /// `id / name / latitude / longitude / address?`. Note backend
    /// doesn't read `routeDistanceMeters`, so we strip it on encode
    /// to keep the wire format minimal.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: WireKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(latitude, forKey: .latitude)
        try c.encode(longitude, forKey: .longitude)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: WireKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.latitude = try c.decode(Double.self, forKey: .latitude)
        self.longitude = try c.decode(Double.self, forKey: .longitude)
        self.routeDistanceMeters = 0
    }

    private enum WireKeys: String, CodingKey {
        case id, name, latitude, longitude
    }
}

public struct ChargingPlanResponse: Codable, Sendable {
    public let chargingStops: [ChargingStop]
    public let numChargingStops: Int
    public let chargingDurationMinutes: Int
    public let arrivalSoc: Int
    public let warnings: [String]

    public enum CodingKeys: String, CodingKey {
        case chargingStops = "charging_stops"
        case numChargingStops = "num_charging_stops"
        case chargingDurationMinutes = "charging_duration_minutes"
        case arrivalSoc = "arrival_soc"
        case warnings
    }
}

extension Coordinate: Sendable {}
