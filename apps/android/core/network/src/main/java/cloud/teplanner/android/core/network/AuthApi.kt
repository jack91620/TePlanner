package cloud.teplanner.android.core.network

import retrofit2.http.Body
import retrofit2.http.POST

/**
 * Phase F.1 — auth Retrofit interface. The backend exposes 10 auth
 * endpoints (Email login/register, Tesla OAuth flow, WeChat); F.1
 * wires the email-login path only. Tesla pairing lands once the iOS
 * VCP flow is mirrored on Android (F.2 or later, gated on Tesla
 * Mobile App's Android availability).
 */
interface AuthApi {
    @POST("api/v1/auth/login")
    suspend fun login(@Body body: EmailLoginRequest): EmailAuthResponse

    @POST("api/v1/auth/register")
    suspend fun register(@Body body: EmailRegisterRequest): EmailAuthResponse
}
