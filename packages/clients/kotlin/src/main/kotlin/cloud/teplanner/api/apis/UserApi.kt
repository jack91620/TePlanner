package cloud.teplanner.api.apis

import cloud.teplanner.api.infrastructure.CollectionFormats.*
import retrofit2.http.*
import retrofit2.Response
import okhttp3.RequestBody
import com.squareup.moshi.Json

import cloud.teplanner.api.models.HTTPValidationError
import cloud.teplanner.api.models.ScheduledDepartureRequest
import cloud.teplanner.api.models.ScheduledDepartureResponse
import cloud.teplanner.api.models.UserSettingsRequest
import cloud.teplanner.api.models.UserSettingsResponse

interface UserApi {
    /**
     * DELETE api/v1/user/scheduled-departure
     * Clear Scheduled Departure
     * Idempotent — clearing a non-existent row is a 200, not 404.
     * Responses:
     *  - 200: Successful Response
     *
     * @return [kotlin.Any]
     */
    @DELETE("api/v1/user/scheduled-departure")
    suspend fun clearScheduledDepartureApiV1UserScheduledDepartureDelete(): Response<kotlin.Any>

    /**
     * GET api/v1/user/scheduled-departure
     * Get Scheduled Departure
     * Fetch the user&#39;s active scheduled departure. Returns &#x60;&#x60;null&#x60;&#x60; when none is set — iOS treats null as \&quot;not scheduled\&quot; and shows the empty card.
     * Responses:
     *  - 200: Successful Response
     *
     * @return [ScheduledDepartureResponse]
     */
    @GET("api/v1/user/scheduled-departure")
    suspend fun getScheduledDepartureApiV1UserScheduledDepartureGet(): Response<ScheduledDepartureResponse>

    /**
     * GET api/v1/user/settings
     * Get User Settings
     * Return the user&#39;s full settings dict. Empty dict when never set. &#x60;updated_at&#x60; is the most recent row update — clients use it to short-circuit re-fetches.
     * Responses:
     *  - 200: Successful Response
     *
     * @return [UserSettingsResponse]
     */
    @GET("api/v1/user/settings")
    suspend fun getUserSettingsApiV1UserSettingsGet(): Response<UserSettingsResponse>

    /**
     * PUT api/v1/user/scheduled-departure
     * Upsert Scheduled Departure
     * Replace the user&#39;s scheduled departure with the supplied row. UNIQUE(user_id) enforces single-row semantics; we update in place when a row already exists rather than relying on the DB unique error to bubble up.  Past departures are accepted — the iOS UI prevents them, but a server reject would race with clock skew and break preheat cancellation flows.
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param scheduledDepartureRequest 
     * @return [ScheduledDepartureResponse]
     */
    @PUT("api/v1/user/scheduled-departure")
    suspend fun upsertScheduledDepartureApiV1UserScheduledDeparturePut(@Body scheduledDepartureRequest: ScheduledDepartureRequest): Response<ScheduledDepartureResponse>

    /**
     * PUT api/v1/user/settings
     * Upsert User Settings
     * Merge &#x60;&#x60;body.settings&#x60;&#x60; into the user&#39;s settings dict (or replace entirely if &#x60;&#x60;replace_all&#x3D;true&#x60;&#x60;). Each value is JSON-encoded for storage. Keys longer than 80 chars or empty are rejected (matches column constraint).
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param userSettingsRequest 
     * @return [UserSettingsResponse]
     */
    @PUT("api/v1/user/settings")
    suspend fun upsertUserSettingsApiV1UserSettingsPut(@Body userSettingsRequest: UserSettingsRequest): Response<UserSettingsResponse>

}
