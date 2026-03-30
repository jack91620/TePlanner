import Foundation

// MARK: - Data Models to match the Backend API response

struct RoutePlanResponse: Codable, Identifiable {
    let routeId: Int?
    var id: Int { routeId ?? UUID().hashValue }
    let origin: LocationDetail
    let destination: LocationDetail
    let totalDistanceKm: Double
    let totalDurationMinutes: Int
    let drivingDurationMinutes: Int
    let chargingDurationMinutes: Int
    let chargingStops: [ChargingStop]
    let numChargingStops: Int
    let initialSoc: Int
    let arrivalSoc: Int
    let polyline: [Coordinate]
    let warnings: [String]
    
    enum CodingKeys: String, CodingKey {
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

struct LocationDetail: Codable {
    let lat: Double?
    let lng: Double?
    let name: String
}

struct ChargingStop: Codable, Identifiable {
    let stationId: String
    var id: String { stationId }
    let name: String
    let latitude: Double
    let longitude: Double
    let address: String?
    let operatorName: String?
    let distanceFromStartKm: Double
    let arrivalSoc: Int
    let departureSoc: Int
    let chargingDurationMinutes: Int

    enum CodingKeys: String, CodingKey {
        case stationId = "station_id"
        case name, latitude, longitude, address
        case operatorName = "operator"
        case distanceFromStartKm = "distance_from_start_km"
        case arrivalSoc = "arrival_soc"
        case departureSoc = "departure_soc"
        case chargingDurationMinutes = "charging_duration_minutes"
    }
}

struct Coordinate: Codable {
    let latitude: Double
    let longitude: Double
}

// MARK: - Request Models for the Backend API

struct RoutePlanRequest: Codable {
    let origin: LocationInput?
    let destination: LocationInput
    let vehicleId: String?
    let currentSoc: Int?
    let carType: String = "model_y_long_range" // Default value for now
    let minArrivalSoc: Int = 20 // Default value for now

    enum CodingKeys: String, CodingKey {
        case origin, destination
        case vehicleId = "vehicle_id"
        case currentSoc = "current_soc"
        case carType = "car_type"
        case minArrivalSoc = "min_arrival_soc"
    }
}

struct LocationInput: Codable {
    let latitude: Double
    let longitude: Double
    let address: String?
}
