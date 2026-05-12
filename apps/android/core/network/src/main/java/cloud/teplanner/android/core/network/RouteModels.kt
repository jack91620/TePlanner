package cloud.teplanner.android.core.network

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Phase F.3.3 — route + charging-plan wire shapes. Mirrors the
 * iOS `RouteModels.swift` + backend `app/api/v1/routes.py`.
 *
 * Three-step orchestration:
 *   1. POST /routes/route        → polyline + dist + duration
 *   2. AMap Android RoutePoiSearch (alongby chargingPile)
 *   3. POST /routes/charging-plan → greedy stop selection + arrival SOC
 */
@Serializable
data class LocationInput(
    val name: String? = null,
    val latitude: Double,
    val longitude: Double,
)

@Serializable
data class Coordinate(
    val latitude: Double,
    val longitude: Double,
    val name: String? = null,
)

@Serializable
data class RouteOnlyRequest(
    val origin: LocationInput,
    val destination: LocationInput,
)

@Serializable
data class RouteOnlyResponse(
    val origin: Coordinate,
    val destination: Coordinate,
    @SerialName("total_distance_km") val totalDistanceKm: Double,
    @SerialName("driving_duration_minutes") val drivingDurationMinutes: Int,
    val polyline: List<Coordinate>,
)

@Serializable
data class POIInput(
    val id: String,
    val name: String,
    val latitude: Double,
    val longitude: Double,
    val address: String? = null,
)

@Serializable
data class ChargingPlanRequest(
    val polyline: List<List<Double>>,
    @SerialName("total_distance_km") val totalDistanceKm: Double,
    @SerialName("candidate_pois") val candidatePois: List<POIInput>,
    @SerialName("initial_soc") val initialSoc: Int,
    @SerialName("car_type") val carType: String = "model_y_long_range",
    @SerialName("min_arrival_soc") val minArrivalSoc: Int = 20,
    @SerialName("vehicle_range_km") val vehicleRangeKm: Double? = null,
)

@Serializable
data class ChargingStopResponse(
    @SerialName("station_id") val stationId: String,
    val name: String,
    val latitude: Double,
    val longitude: Double,
    val address: String? = null,
    val operator: String? = null,
    @SerialName("distance_from_start_km") val distanceFromStartKm: Double,
    @SerialName("arrival_soc") val arrivalSoc: Int,
    @SerialName("departure_soc") val departureSoc: Int,
    @SerialName("charging_duration_minutes") val chargingDurationMinutes: Int,
)

@Serializable
data class ChargingPlanResponse(
    @SerialName("charging_stops") val chargingStops: List<ChargingStopResponse>,
    @SerialName("num_charging_stops") val numChargingStops: Int,
    @SerialName("charging_duration_minutes") val chargingDurationMinutes: Int,
    @SerialName("arrival_soc") val arrivalSoc: Int,
    val warnings: List<String> = emptyList(),
)

@Serializable
data class PlaceLocation(
    val lat: Double,
    val lng: Double,
)

@Serializable
data class PlaceResult(
    val id: String? = null,
    val title: String? = null,
    val name: String,
    val address: String? = null,
    val location: PlaceLocation,
    @SerialName("distance_km") val distanceKm: Double? = null,
) {
    val latitude: Double get() = location.lat
    val longitude: Double get() = location.lng
}

// MARK: - POST /routes/save — write to "最近" history

@Serializable
data class SaveRoutePlanLocation(
    val latitude: Double,
    val longitude: Double,
    val address: String? = null,
)

@Serializable
data class SaveRoutePlanChargingStop(
    @SerialName("station_id") val stationId: String? = null,
    val name: String? = null,
    val latitude: Double? = null,
    val longitude: Double? = null,
    val address: String? = null,
    @SerialName("arrival_soc") val arrivalSoc: Int? = null,
    @SerialName("departure_soc") val departureSoc: Int? = null,
    @SerialName("charging_duration_minutes") val chargingDurationMinutes: Int? = null,
)

@Serializable
data class SaveRoutePlanRequest(
    val origin: SaveRoutePlanLocation,
    val destination: SaveRoutePlanLocation,
    @SerialName("total_distance_km") val totalDistanceKm: Double? = null,
    @SerialName("total_duration_minutes") val totalDurationMinutes: Int? = null,
    @SerialName("polyline_points") val polylinePoints: List<List<Double>>? = null,
    @SerialName("charging_stops") val chargingStops: List<SaveRoutePlanChargingStop> = emptyList(),
)

@Serializable
data class SaveRoutePlanResponse(
    val id: Int,
    @SerialName("created_at") val createdAt: String,
)

@Serializable
data class PlaceSearchResponse(
    val results: List<PlaceResult> = emptyList(),
)

// MARK: - GET /routes/ — list user's 最近 trips
// Wire schema notes:
//   - lat/lng come back as `lat` and `lng` (not `latitude`/`longitude`)
//     because the backend dict literal in routes.list_routes uses those
//     keys (see backend/app/api/v1/routes.py:512). Don't normalize via
//     SerialName on the saved-trip side or the decode breaks silently.
//   - `address` may be null when the user typed a destination without
//     resolving via geocode (older trip rows).
//   - `created_at` is the server-side timestamp in ISO 8601 with
//     timezone offset; never null on saved rows.

@Serializable
data class RoutePlanLocation(
    val lat: Double,
    val lng: Double,
    val address: String? = null,
)

@Serializable
data class RoutePlanSummary(
    val id: Int,
    val origin: RoutePlanLocation,
    val destination: RoutePlanLocation,
    @SerialName("total_distance_km") val totalDistanceKm: Double? = null,
    @SerialName("total_duration_minutes") val totalDurationMinutes: Int? = null,
    val status: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
)

@Serializable
data class RoutePlanListResponse(
    val count: Int = 0,
    val routes: List<RoutePlanSummary> = emptyList(),
)
