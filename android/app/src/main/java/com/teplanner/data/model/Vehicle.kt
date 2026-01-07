package com.teplanner.data.model

import com.google.gson.annotations.SerializedName

/**
 * Tesla vehicle information
 */
data class Vehicle(
    @SerializedName("id")
    val id: String,

    @SerializedName("vehicle_id")
    val vehicleId: Long,

    @SerializedName("vin")
    val vin: String,

    @SerializedName("display_name")
    val displayName: String,

    @SerializedName("state")
    val state: String, // "online", "asleep", "offline"

    @SerializedName("in_service")
    val inService: Boolean = false,

    @SerializedName("color")
    val color: String? = null,

    @SerializedName("access_type")
    val accessType: String? = null
)

/**
 * Vehicle state including battery, location, etc.
 */
data class VehicleState(
    @SerializedName("battery_level")
    val batteryLevel: Int,

    @SerializedName("battery_range")
    val batteryRange: Double, // km

    @SerializedName("charging_state")
    val chargingState: String?, // "Charging", "Complete", "Disconnected", etc.

    @SerializedName("charge_limit_soc")
    val chargeLimitSoc: Int?,

    @SerializedName("time_to_full_charge")
    val timeToFullCharge: Double?,

    @SerializedName("latitude")
    val latitude: Double?,

    @SerializedName("longitude")
    val longitude: Double?,

    @SerializedName("heading")
    val heading: Int?,

    @SerializedName("speed")
    val speed: Double?,

    @SerializedName("odometer")
    val odometer: Double?,

    @SerializedName("is_climate_on")
    val isClimateOn: Boolean = false,

    @SerializedName("inside_temp")
    val insideTemp: Double?,

    @SerializedName("outside_temp")
    val outsideTemp: Double?,

    @SerializedName("locked")
    val locked: Boolean = true,

    @SerializedName("sentry_mode")
    val sentryMode: Boolean = false,

    @SerializedName("timestamp")
    val timestamp: Long?
)
