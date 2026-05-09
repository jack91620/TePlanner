package cloud.teplanner.android.core.network

import okhttp3.Interceptor
import okhttp3.Response

/**
 * Phase F.1 — adds Bearer JWT to every outbound request from the
 * stored token. /auth/login + /auth/register skip this so the
 * unauthenticated bootstrap calls work cleanly. iOS equivalent is
 * [APIService.perform] reading [tokenProvider].
 */
class AuthInterceptor(private val tokenStore: TokenStore) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val original = chain.request()
        val path = original.url.encodedPath
        if (path.endsWith("/auth/login") || path.endsWith("/auth/register")) {
            return chain.proceed(original)
        }
        val token = tokenStore.accessToken
            ?: return chain.proceed(original)
        return chain.proceed(
            original.newBuilder()
                .header("Authorization", "Bearer $token")
                .build()
        )
    }
}
