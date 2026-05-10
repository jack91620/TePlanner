package cloud.teplanner.android.core.network

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class ScheduledDepartureRequest(
    @SerialName("departure_at_utc") val departureAtUtc: String,
    @SerialName("lead_minutes") val leadMinutes: Int = 15,
    val label: String? = null,
    @SerialName("vehicle_id") val vehicleId: String? = null,
    @SerialName("target_charge_soc") val targetChargeSoc: Int? = null,
    val enabled: Boolean = true,
)

@Serializable
data class ScheduledDepartureResponse(
    val id: Int,
    @SerialName("departure_at_utc") val departureAtUtc: String,
    @SerialName("lead_minutes") val leadMinutes: Int,
    val label: String? = null,
    @SerialName("vehicle_id") val vehicleId: String? = null,
    @SerialName("target_charge_soc") val targetChargeSoc: Int? = null,
    val enabled: Boolean,
    @SerialName("fire_at_utc") val fireAtUtc: String,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("updated_at") val updatedAt: String? = null,
)

@Serializable
data class ClearResponse(val success: Boolean)
