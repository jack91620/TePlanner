package cloud.teplanner.android.core.network

import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.PUT

interface UserApi {

    @GET("api/v1/user/scheduled-departure")
    suspend fun getScheduledDeparture(): ScheduledDepartureResponse?

    @PUT("api/v1/user/scheduled-departure")
    suspend fun upsertScheduledDeparture(
        @Body request: ScheduledDepartureRequest,
    ): ScheduledDepartureResponse

    @DELETE("api/v1/user/scheduled-departure")
    suspend fun clearScheduledDeparture(): ClearResponse
}
