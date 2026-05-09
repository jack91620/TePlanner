package cloud.teplanner.android.core.network

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Phase F.2 — vehicle wire shapes for Hub status card. Backend
 * `app/api/v1/vehicles.py` returns rich state; we model only the
 * fields the Hub card displays + identity. Charging-session and
 * command surfaces ship with F.3 / F.4.
 */
@Serializable
data class VehicleResponse(
    val id: String,
    val vin: String? = null,
    @SerialName("display_name") val displayName: String? = null,
    val model: String? = null,
    val color: String? = null,
    @SerialName("battery_capacity_kwh") val batteryCapacityKwh: Double? = null,
    @SerialName("is_primary") val isPrimary: Boolean = false,
)

@Serializable
data class VehiclesListResponse(
    val vehicles: List<VehicleResponse>,
    val count: Int,
)

@Serializable
data class VehicleStateResponse(
    @SerialName("vehicle_id") val vehicleId: String,
    @SerialName("display_name") val displayName: String? = null,
    val state: String? = null,
    @SerialName("battery_level") val batteryLevel: Int? = null,
    @SerialName("battery_range_km") val batteryRangeKm: Double? = null,
    @SerialName("usable_battery_level") val usableBatteryLevel: Int? = null,
    @SerialName("charging_state") val chargingState: String? = null,
    @SerialName("charge_limit_soc") val chargeLimitSoc: Int? = null,
    val latitude: Double? = null,
    val longitude: Double? = null,
    val heading: Int? = null,
    val speed: Int? = null,
    @SerialName("odometer_km") val odometerKm: Double? = null,
    @SerialName("inside_temp") val insideTemp: Double? = null,
    @SerialName("outside_temp") val outsideTemp: Double? = null,
    @SerialName("locked") val locked: Boolean? = null,
    @SerialName("sentry_mode") val sentryMode: Boolean? = null,
    @SerialName("climate_keeper_mode") val climateKeeperMode: Int? = null,
)
