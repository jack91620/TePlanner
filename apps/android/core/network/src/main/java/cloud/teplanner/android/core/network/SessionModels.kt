package cloud.teplanner.android.core.network

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Phase F.4.2 — charging session wire shapes. Mirrors backend
 * ChargingSessionResponse (vehicles.py:713). All numeric fields are
 * nullable because telemetry occasionally drops mid-session and the
 * server ends up with a started_at + nothing else.
 */
@Serializable
data class ChargingSessionResponse(
    val id: Int,
    @SerialName("vehicle_id") val vehicleId: String? = null,
    @SerialName("client_session_id") val clientSessionId: String? = null,
    @SerialName("started_at") val startedAt: String,
    @SerialName("ended_at") val endedAt: String? = null,
    @SerialName("start_soc") val startSoc: Int? = null,
    @SerialName("end_soc") val endSoc: Int? = null,
    @SerialName("start_range_km") val startRangeKm: Double? = null,
    @SerialName("end_range_km") val endRangeKm: Double? = null,
    @SerialName("energy_added_kwh") val energyAddedKwh: Double? = null,
    @SerialName("location_name") val locationName: String? = null,
    val lat: Double? = null,
    val lng: Double? = null,
    @SerialName("ended_as_complete") val endedAsComplete: Boolean? = null,
    val source: String,
    @SerialName("duration_minutes") val durationMinutes: Int? = null,
    @SerialName("range_added_km") val rangeAddedKm: Double? = null,
    @SerialName("soc_delta") val socDelta: Int? = null,
)

@Serializable
data class ChargingSessionListResponse(
    val sessions: List<ChargingSessionResponse>,
)
