package cloud.teplanner.android.core.network

import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.Header
import retrofit2.http.POST
import retrofit2.http.Path

/**
 * Cross-platform share codes. Mirrors iOS APIService.createShare /
 * lookupShare / revokeShare / listMyShares. Backend at
 * `backend/app/api/v1/shares.py`.
 *
 * Codes are 6-char base32-friendly strings (no 0/O/1/I/l). Server
 * normalizes case + dashes + whitespace, so the caller can pass
 * raw user input as-typed (e.g. "abcd-ef" or "AB CDE F").
 */
interface SharesApi {

    @POST("api/v1/shares")
    suspend fun create(@Body request: ShareCreateRequest): ShareDetailResponse

    @GET("api/v1/shares/mine")
    suspend fun listMine(): ShareListResponse

    /// X-App-Version header — server returns 412 Precondition Failed
    /// when the importer's version is below the share's
    /// `min_app_version`. iOS sends `Bundle.CFBundleVersion`; Android
    /// sends the app's versionCode/versionName.
    @GET("api/v1/shares/{code}")
    suspend fun lookup(
        @Path("code") code: String,
        @Header("X-App-Version") appVersion: String? = null,
    ): ShareDetailResponse

    @DELETE("api/v1/shares/{code}")
    suspend fun revoke(@Path("code") code: String)
}
