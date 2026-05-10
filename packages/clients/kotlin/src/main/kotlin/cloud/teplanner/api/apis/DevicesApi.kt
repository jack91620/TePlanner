package cloud.teplanner.api.apis

import cloud.teplanner.api.infrastructure.CollectionFormats.*
import retrofit2.http.*
import retrofit2.Response
import okhttp3.RequestBody
import com.squareup.moshi.Json

import cloud.teplanner.api.models.HTTPValidationError
import cloud.teplanner.api.models.RegisterDeviceRequest
import cloud.teplanner.api.models.RegisterDeviceResponse
import cloud.teplanner.api.models.TestPushRequest

interface DevicesApi {
    /**
     * POST api/v1/devices/register
     * Register Device
     * Upsert (user_id, token). Re-registering an existing token just bumps last_seen_at — that lets the polling layer prune stale rows later (e.g. tokens not seen for 30 days are likely uninstalled).
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param registerDeviceRequest 
     * @return [RegisterDeviceResponse]
     */
    @POST("api/v1/devices/register")
    suspend fun registerDeviceApiV1DevicesRegisterPost(@Body registerDeviceRequest: RegisterDeviceRequest): Response<RegisterDeviceResponse>

    /**
     * POST api/v1/devices/run-automation-tick
     * Run Automation Tick
     * Trigger a single polling tick on demand. Used for end-to-end debugging: hit this, watch server.log, verify a push lands. Doesn&#39;t take args — runs the full eligible-user loop.
     * Responses:
     *  - 200: Successful Response
     *
     * @return [kotlin.Any]
     */
    @POST("api/v1/devices/run-automation-tick")
    suspend fun runAutomationTickApiV1DevicesRunAutomationTickPost(): Response<kotlin.Any>

    /**
     * POST api/v1/devices/test-push
     * Test Push
     * Send a debug push to all of this user&#39;s registered devices. Phase E — routes through PushDispatcher so APNs / JPush / Huawei Push Kit all receive it according to each token&#39;s platform field.
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param testPushRequest 
     * @return [kotlin.Any]
     */
    @POST("api/v1/devices/test-push")
    suspend fun testPushApiV1DevicesTestPushPost(@Body testPushRequest: TestPushRequest): Response<kotlin.Any>

}
