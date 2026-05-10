package cloud.teplanner.android.core.network

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Phase F.3.2 — charging-station wire shapes for `/charging/nearby`
 * + `/charging/stations/{id}`. Mirrors backend
 * `ChargingStation` Pydantic model (app/api/v1/charging.py:13).
 */
@Serializable
data class ChargingStation(
    val id: String,
    val name: String,
    val address: String,
    val latitude: Double,
    val longitude: Double,
    @SerialName("distance_km") val distanceKm: Double? = null,
    val operator: String? = null,
    val tel: String? = null,
    @SerialName("power_kw") val powerKw: Int? = null,
    @SerialName("available_ports") val availablePorts: Int? = null,
    @SerialName("total_ports") val totalPorts: Int? = null,
    @SerialName("price_per_kwh") val pricePerKwh: Double? = null,
    @SerialName("open_hours") val openHours: String? = null,
    val category: String? = null,
    val type: String? = null,
)

@Serializable
data class StationSearchResponse(
    val count: Int,
    val stations: List<ChargingStation>,
)
