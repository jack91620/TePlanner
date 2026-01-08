package com.teplanner.data.model

import com.google.gson.annotations.SerializedName

/**
 * Response wrapper for vehicles list
 */
data class VehiclesResponse(
    @SerializedName("count")
    val count: Int,

    @SerializedName("vehicles")
    val vehicles: List<Vehicle>
)

/**
 * Tesla vehicle information
 */
data class Vehicle(
    @SerializedName("id")
    val id: String,

    @SerializedName("vehicle_id")
    val vehicleId: Long? = null,

    @SerializedName("vin")
    val vin: String? = null,

    @SerializedName("display_name")
    val displayName: String? = null,

    @SerializedName("model")
    val model: String? = null,

    @SerializedName("state")
    val state: String = "offline", // "online", "asleep", "offline"

    @SerializedName("in_service")
    val inService: Boolean = false,

    @SerializedName("is_primary")
    val isPrimary: Boolean = false,

    @SerializedName("color")
    val color: String? = null,

    @SerializedName("access_type")
    val accessType: String? = null
)

/**
 * Vehicle state including battery, location, etc.
 */
data class VehicleState(
    @SerializedName("vehicle_id")
    val vehicleId: String? = null,

    @SerializedName("display_name")
    val displayName: String? = null,

    @SerializedName("state")
    val state: String? = null, // online, asleep, offline

    @SerializedName("battery_level")
    val batteryLevel: Int? = null,

    @SerializedName("battery_range_km")
    val batteryRange: Double? = null, // km

    @SerializedName("usable_battery_level")
    val usableBatteryLevel: Int? = null,

    @SerializedName("charging_state")
    val chargingState: String? = null, // "Charging", "Complete", "Disconnected", etc.

    @SerializedName("latitude")
    val latitude: Double? = null,

    @SerializedName("longitude")
    val longitude: Double? = null,

    @SerializedName("heading")
    val heading: Int? = null,

    @SerializedName("speed")
    val speed: Int? = null, // km/h

    @SerializedName("odometer_km")
    val odometer: Double? = null,

    @SerializedName("inside_temp")
    val insideTemp: Double? = null,

    @SerializedName("outside_temp")
    val outsideTemp: Double? = null
)
