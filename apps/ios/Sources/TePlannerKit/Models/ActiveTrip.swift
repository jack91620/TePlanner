import CoreLocation
import Foundation

/// One stop in a planned multi-stop trip. `kind` distinguishes
/// intermediate charging stops from the final destination so the
/// backend can validate (last must be `.final`).
public struct TripStop: Codable, Hashable, Identifiable {
    public let latitude: Double
    public let longitude: Double
    public let address: String?
    public let name: String?
    public let kind: Kind
    public let stationId: String?
    public let socTarget: Int?

    public enum Kind: String, Codable, Hashable {
        case charging
        case final
    }

    /// Stable identity for SwiftUI ForEach — pin to station id when
    /// present, otherwise fall back to a hash of the coordinates.
    public var id: String {
        if let stationId, !stationId.isEmpty { return "station:\(stationId)" }
        return "\(latitude),\(longitude)"
    }

    public init(
        latitude: Double,
        longitude: Double,
        address: String? = nil,
        name: String? = nil,
        kind: Kind,
        stationId: String? = nil,
        socTarget: Int? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.name = name
        self.kind = kind
        self.stationId = stationId
        self.socTarget = socTarget
    }

    public enum CodingKeys: String, CodingKey {
        case latitude, longitude, address, name, kind
        case stationId = "station_id"
        case socTarget = "soc_target"
    }

    /// Convert a `RoutePlanResponse` (origin → charging stops → final
    /// destination) into the `[TripStop]` payload that `/trips/start`
    /// expects. AMap returns GCJ-02 coordinates; Tesla's nav expects
    /// WGS-84, so we run each pair through `gcj02ToWgs84` here at the
    /// outbound boundary.
    ///
    /// Returns `nil` when the plan's destination is missing
    /// coordinates — callers should surface "目的地缺少坐标" rather
    /// than send a half-defined trip.
    public static func stops(
        from plan: RoutePlanResponse,
        convert: (Double, Double) -> (Double, Double) = TripStop._gcjToWgsDefault,
    ) -> [TripStop]? {
        guard let destLat = plan.destination.lat,
              let destLng = plan.destination.lng else {
            return nil
        }
        var stops: [TripStop] = []
        for s in plan.chargingStops {
            let (lat, lng) = convert(s.latitude, s.longitude)
            stops.append(TripStop(
                latitude: lat,
                longitude: lng,
                address: s.address,
                name: s.name,
                kind: .charging,
                stationId: s.stationId,
                socTarget: s.arrivalSoc,
            ))
        }
        let (dLat, dLng) = convert(destLat, destLng)
        stops.append(TripStop(
            latitude: dLat,
            longitude: dLng,
            address: nil,
            name: plan.destination.name,
            kind: .final,
        ))
        return stops
    }

    public static func _gcjToWgsDefault(_ lat: Double, _ lng: Double) -> (Double, Double) {
        let wgs = CoordConverter.gcj02ToWgs84(
            CLLocationCoordinate2D(latitude: lat, longitude: lng)
        )
        return (wgs.latitude, wgs.longitude)
    }
}

/// Server's view of a trip in progress — what's the current stop,
/// has it been replanned, where is the car. Mirrors the backend
/// `TripResponse` model in app/api/v1/trips.py.
public struct ActiveTrip: Codable, Identifiable {
    public let id: Int
    public let vehicleId: String
    public let status: Status
    /// 0-based index of the stop currently sent to the car;
    /// -1 = trip created but stop 0 not yet sent (e.g. car offline).
    public let currentSegment: Int
    public let stops: [TripStop]
    public let replanCount: Int
    public let lastReplanReason: String?
    public let lastPositionLat: Double?
    public let lastPositionLng: Double?
    public let lastPositionAt: Date?
    public let lastSpeedKmh: Double?
    public let lastBatteryLevelPct: Int?
    public let createdAt: Date
    public let updatedAt: Date
    /// Distance + ETA + projected arrival SOC for the next stop.
    /// Backend computes these live in /trips/active using the cached
    /// position + speed + SOC. nil whenever an input was unavailable
    /// (cold cache, car asleep, segment past end). iOS hides the
    /// line(s) gracefully rather than rendering "?? km".
    public let nextStopDistanceKm: Double?
    public let nextStopEtaSeconds: Int?
    public let nextStopProjectedSocPct: Int?

    public enum Status: String, Codable {
        case active, completed, cancelled
    }

    public init(
        id: Int,
        vehicleId: String,
        status: Status,
        currentSegment: Int,
        stops: [TripStop],
        replanCount: Int = 0,
        lastReplanReason: String? = nil,
        lastPositionLat: Double? = nil,
        lastPositionLng: Double? = nil,
        lastPositionAt: Date? = nil,
        lastSpeedKmh: Double? = nil,
        lastBatteryLevelPct: Int? = nil,
        nextStopDistanceKm: Double? = nil,
        nextStopEtaSeconds: Int? = nil,
        nextStopProjectedSocPct: Int? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.vehicleId = vehicleId
        self.status = status
        self.currentSegment = currentSegment
        self.stops = stops
        self.replanCount = replanCount
        self.lastReplanReason = lastReplanReason
        self.lastPositionLat = lastPositionLat
        self.lastPositionLng = lastPositionLng
        self.lastPositionAt = lastPositionAt
        self.lastSpeedKmh = lastSpeedKmh
        self.lastBatteryLevelPct = lastBatteryLevelPct
        self.nextStopDistanceKm = nextStopDistanceKm
        self.nextStopEtaSeconds = nextStopEtaSeconds
        self.nextStopProjectedSocPct = nextStopProjectedSocPct
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public enum CodingKeys: String, CodingKey {
        case id, status, stops
        case vehicleId = "vehicle_id"
        case currentSegment = "current_segment"
        case replanCount = "replan_count"
        case lastReplanReason = "last_replan_reason"
        case lastPositionLat = "last_position_lat"
        case lastPositionLng = "last_position_lng"
        case lastPositionAt = "last_position_at"
        case lastSpeedKmh = "last_speed_kmh"
        case lastBatteryLevelPct = "last_battery_level_pct"
        case nextStopDistanceKm = "next_stop_distance_km"
        case nextStopEtaSeconds = "next_stop_eta_seconds"
        case nextStopProjectedSocPct = "next_stop_projected_soc_pct"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - Convenience

    public var currentStop: TripStop? {
        guard currentSegment >= 0, currentSegment < stops.count else { return nil }
        return stops[currentSegment]
    }

    public var nextStop: TripStop? {
        let nxt = currentSegment + 1
        guard nxt < stops.count else { return nil }
        return stops[nxt]
    }

    /// Stops not yet visited (current + everything after). Used by
    /// the Hub card to show "下一段 + 剩余 N 站".
    public var remainingStops: [TripStop] {
        guard currentSegment >= 0 else { return stops }
        return Array(stops[currentSegment...])
    }

    public var isOnFinalStop: Bool {
        currentSegment >= 0 && currentSegment == stops.count - 1
    }
}

// MARK: - Request bodies (POST /trips/*)

public struct StartTripRequest: Codable {
    public let vehicleId: String
    public let stops: [TripStop]
    public let polyline: [[Double]]?

    public init(vehicleId: String, stops: [TripStop], polyline: [[Double]]? = nil) {
        self.vehicleId = vehicleId
        self.stops = stops
        self.polyline = polyline
    }

    public enum CodingKeys: String, CodingKey {
        case vehicleId = "vehicle_id"
        case stops, polyline
    }
}

public struct ReplanTripRequest: Codable {
    public let newStops: [TripStop]
    public let reason: String
    public let polyline: [[Double]]?

    public init(newStops: [TripStop], reason: String, polyline: [[Double]]? = nil) {
        self.newStops = newStops
        self.reason = reason
        self.polyline = polyline
    }

    public enum CodingKeys: String, CodingKey {
        case newStops = "new_stops"
        case reason, polyline
    }
}
