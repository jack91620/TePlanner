package cloud.teplanner.android.core.network

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import retrofit2.http.Body
import retrofit2.http.POST

@Serializable
data class RegisterDeviceRequest(
    val token: String,
    @SerialName("bundle_id") val bundleId: String? = null,
    val platform: String = "jpush",
    @SerialName("provider_token") val providerToken: String? = null,
)

@Serializable
data class RegisterDeviceResponse(
    val success: Boolean,
    @SerialName("device_id") val deviceId: Int,
)

interface DevicesApi {

    @POST("api/v1/devices/register")
    suspend fun register(@Body request: RegisterDeviceRequest): RegisterDeviceResponse
}
