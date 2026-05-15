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

    /// Phase A.5 user-settings sync. iOS already consumes this for
    /// hub.actions / hub.slots / charge-limit preferences; Android
    /// now needs it for the Hub Quick Actions parity push.
    /// Backend at /api/v1/user/settings: GET returns full settings
    /// blob; PUT merges (or replaces, see replace_all flag).
    @GET("api/v1/user/settings")
    suspend fun getUserSettings(): UserSettingsResponse

    @PUT("api/v1/user/settings")
    suspend fun putUserSettings(
        @Body request: UserSettingsRequest,
    ): UserSettingsResponse

    /// Apple 5.1.1(v) + Play Store equivalent: permanently delete the
    /// authenticated user's account and all associated server data
    /// (Tesla tokens, vehicles, automations, sessions, settings, ...).
    /// Returns 204 No Content on success; Retrofit raises HttpException
    /// on non-2xx, so a clean return implies the delete went through.
    /// Local Keychain / token store must be cleared by the caller —
    /// see [AuthSession.deleteAccount].
    @DELETE("api/v1/user/me")
    suspend fun deleteAccount()
}
