package cloud.teplanner.android.core.network

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Phase F.1 wire shapes for backend `/api/v1/auth/login`.
 * Pinned against `packages/clients/openapi.json` snapshot:
 *   - EmailLoginRequest { email, password }
 *   - EmailAuthResponse { access_token, expires_in, user_id, email,
 *                         token_type, nickname?, has_tesla_linked }
 *
 * Phase F.4+ will switch to the generated Kotlin SDK once it's wired
 * into Gradle composite-build; until then a hand-rolled pair keeps
 * the module compiling without external sdk-kotlin dep.
 */
@Serializable
data class EmailLoginRequest(
    val email: String,
    val password: String,
)

@Serializable
data class EmailAuthResponse(
    @SerialName("access_token") val accessToken: String,
    @SerialName("expires_in") val expiresIn: Long,
    @SerialName("user_id") val userId: Long,
    val email: String,
    @SerialName("token_type") val tokenType: String = "Bearer",
    val nickname: String? = null,
    @SerialName("has_tesla_linked") val hasTeslaLinked: Boolean = false,
)

@Serializable
data class EmailRegisterRequest(
    val email: String,
    val password: String,
    val nickname: String? = null,
)
