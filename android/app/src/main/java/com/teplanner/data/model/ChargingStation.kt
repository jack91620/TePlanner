package com.teplanner.data.model

import com.google.gson.annotations.SerializedName

/**
 * Charging station information
 */
data class ChargingStation(
    @SerializedName("id")
    val id: String,

    @SerializedName("name")
    val name: String,

    @SerializedName("address")
    val address: String?,

    @SerializedName("latitude")
    val latitude: Double,

    @SerializedName("longitude")
    val longitude: Double,

    @SerializedName("type")
    val type: ChargingStationType = ChargingStationType.OTHER,

    @SerializedName("available_stalls")
    val availableStalls: Int? = null,

    @SerializedName("total_stalls")
    val totalStalls: Int? = null,

    @SerializedName("power_kw")
    val powerKw: Int? = null,

    @SerializedName("operator")
    val operator: String? = null,

    @SerializedName("distance_km")
    val distanceKm: Double? = null,

    @SerializedName("distance_from_route_m")
    val distanceFromRouteM: Int? = null,

    @SerializedName("open_24h")
    val open24h: Boolean = false,

    @SerializedName("amenities")
    val amenities: List<String>? = null
)

enum class ChargingStationType {
    @SerializedName("supercharger")
    SUPERCHARGER,

    @SerializedName("destination")
    DESTINATION,

    @SerializedName("ccs")
    CCS,

    @SerializedName("chademo")
    CHADEMO,

    @SerializedName("gb_t")
    GB_T,

    @SerializedName("other")
    OTHER
}
