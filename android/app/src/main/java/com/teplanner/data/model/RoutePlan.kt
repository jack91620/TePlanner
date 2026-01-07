package com.teplanner.data.model

import com.google.gson.annotations.SerializedName

/**
 * Location point with optional name
 */
data class Location(
    @SerializedName("latitude")
    val latitude: Double,

    @SerializedName("longitude")
    val longitude: Double,

    @SerializedName("name")
    val name: String? = null,

    @SerializedName("address")
    val address: String? = null
)

/**
 * Charging stop along a route
 */
data class ChargingStop(
    @SerializedName("station_id")
    val stationId: String,

    @SerializedName("station")
    val station: ChargingStation,

    @SerializedName("arrival_soc")
    val arrivalSoc: Int,

    @SerializedName("departure_soc")
    val departureSoc: Int,

    @SerializedName("charging_duration_minutes")
    val chargingDurationMinutes: Int,

    @SerializedName("distance_from_start_km")
    val distanceFromStartKm: Double
)

/**
 * Complete route plan with charging stops
 */
data class RoutePlan(
    @SerializedName("route_id")
    val routeId: String?,

    @SerializedName("origin")
    val origin: Location,

    @SerializedName("destination")
    val destination: Location,

    @SerializedName("total_distance_km")
    val totalDistanceKm: Double,

    @SerializedName("total_duration_minutes")
    val totalDurationMinutes: Int,

    @SerializedName("driving_duration_minutes")
    val drivingDurationMinutes: Int,

    @SerializedName("charging_duration_minutes")
    val chargingDurationMinutes: Int,

    @SerializedName("charging_stops")
    val chargingStops: List<ChargingStop>,

    @SerializedName("initial_soc")
    val initialSoc: Int,

    @SerializedName("arrival_soc")
    val arrivalSoc: Int,

    @SerializedName("warnings")
    val warnings: List<String>? = null
)

/**
 * Request to plan charging route
 */
data class ChargingPlanRequest(
    @SerializedName("charging_stations")
    val chargingStations: List<ChargingStationInput>,

    @SerializedName("total_distance_km")
    val totalDistanceKm: Double,

    @SerializedName("current_soc")
    val currentSoc: Int,

    @SerializedName("vehicle_id")
    val vehicleId: String? = null,

    @SerializedName("min_arrival_soc")
    val minArrivalSoc: Int = 20
)

data class ChargingStationInput(
    @SerializedName("id")
    val id: String,

    @SerializedName("name")
    val name: String,

    @SerializedName("lat")
    val lat: Double,

    @SerializedName("lng")
    val lng: Double,

    @SerializedName("distance_from_start_km")
    val distanceFromStartKm: Double
)

/**
 * Response from charging plan API
 */
data class ChargingPlanResponse(
    @SerializedName("recommended_stops")
    val recommendedStops: List<RecommendedStop>,

    @SerializedName("arrival_soc")
    val arrivalSoc: Int,

    @SerializedName("total_charging_time_minutes")
    val totalChargingTimeMinutes: Int
)

data class RecommendedStop(
    @SerializedName("station_id")
    val stationId: String,

    @SerializedName("charge_to_soc")
    val chargeToSoc: Int,

    @SerializedName("charging_minutes")
    val chargingMinutes: Int,

    @SerializedName("arrival_soc")
    val arrivalSoc: Int
)
