package cloud.teplanner.android.core.network

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.PUT
import retrofit2.http.Path
import retrofit2.http.Query

/**
 * Phase F.2 — backend automation surface (mirrors iOS APIService
 * Phase A.1 + D.x methods). F.2 scope: list / toggle enabled /
 * delete + snooze. Builder POSTs land in F.4 along with capability
 * picker.
 */
interface AutomationsApi {
    @GET("api/v1/automations/")
    suspend fun list(): RuleListResponse

    @PUT("api/v1/automations/{id}")
    suspend fun update(@Path("id") id: String, @Body body: RuleUpdateRequest): RuleResponse

    @DELETE("api/v1/automations/{id}")
    suspend fun delete(@Path("id") id: String): BaseResponse

    @GET("api/v1/automations/snoozes")
    suspend fun listSnoozes(): SnoozeListResponse

    @POST("api/v1/automations/{id}/snooze")
    suspend fun snooze(@Path("id") id: String, @Body body: SnoozeRequest): SnoozeRecord

    @DELETE("api/v1/automations/{id}/snooze")
    suspend fun unsnooze(@Path("id") id: String): BaseResponse

    @PUT("api/v1/automations/order")
    suspend fun reorder(@Body body: ReorderRequest): RuleListResponse

    /// 触发历史 — recent rule-fire timeline. Backend caps `limit`.
    @GET("api/v1/automations/recent-fires")
    suspend fun recentFires(@Query("limit") limit: Int = 50): RecentFiresResponse
}

@Serializable
data class RecentFireEntry(
    val kind: String,
    @SerialName("pushed_at") val pushedAt: String,
    @SerialName("cleared_at") val clearedAt: String? = null,
)

@Serializable
data class RecentFiresResponse(val fires: List<RecentFireEntry> = emptyList())
