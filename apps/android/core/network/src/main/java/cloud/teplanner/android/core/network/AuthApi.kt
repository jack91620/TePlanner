package cloud.teplanner.android.core.network

import retrofit2.http.GET
import retrofit2.http.Query

/**
 * Auth Retrofit interface. Tesla OAuth is the only login path.
 *
 * Flow:
 *   1. Client calls `authorizeTesla()` → backend returns
 *      `{url, state, user_id}` (creates an anon user if none).
 *   2. Client loads `url` in a WebView; user authenticates with
 *      Tesla; Tesla redirects to backend `/auth/tesla/callback`.
 *   3. Backend exchanges the code, mints a JWT, and renders an
 *      HTML page with `<div id="auth-data">{token, user_id, ...}`.
 *   4. Client's WebView scrapes the div and stores the JWT.
 *
 * The same redirect_uri is used by iOS + Android (server-rendered
 * callback page, no per-platform deep link).
 */
interface AuthApi {
    @GET("api/v1/auth/tesla/authorize")
    suspend fun authorizeTesla(
        @Query("user_id") userId: Long? = null,
    ): TeslaAuthUrlResponse
}
