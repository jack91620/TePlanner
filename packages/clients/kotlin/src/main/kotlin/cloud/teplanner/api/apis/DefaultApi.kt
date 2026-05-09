package cloud.teplanner.api.apis

import cloud.teplanner.api.infrastructure.CollectionFormats.*
import retrofit2.http.*
import retrofit2.Response
import okhttp3.RequestBody
import com.squareup.moshi.Json

import cloud.teplanner.api.models.HTTPValidationError

interface DefaultApi {
    /**
     * GET health
     * Health Check
     * Health check endpoint. Returns app version + status — the &#x60;version&#x60; field is consumed by &#x60;tests/test_health.py&#x60; and surfaced in the &#x60;ops/server-monitor.sh&#x60; snapshot for cross- referencing post-deploy. Source: &#x60;app.config.settings.APP_VERSION&#x60; if defined, falling back to &#39;0.0.0&#39; for local runs.
     * Responses:
     *  - 200: Successful Response
     *
     * @return [kotlin.Any]
     */
    @GET("health")
    suspend fun healthCheckHealthGet(): Response<kotlin.Any>

    /**
     * GET 
     * Root
     * Root endpoint.
     * Responses:
     *  - 200: Successful Response
     *
     * @return [kotlin.Any]
     */
    @GET("")
    suspend fun rootGet(): Response<kotlin.Any>

    /**
     * GET {filename}
     * Serve Wechat Verification
     * Serve WeChat domain verification files from static directory.
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param filename 
     * @return [kotlin.Any]
     */
    @GET("{filename}")
    suspend fun serveWechatVerificationFilenameGet(@Path("filename") filename: kotlin.String): Response<kotlin.Any>

}
