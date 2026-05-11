package cloud.teplanner.android.core.network

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Wire shapes for backend `/api/v1/auth/tesla/authorize`.
 *
 * Tesla OAuth is the only login path — email/password was removed
 * after Android client F.7 to enforce the project-wide rule that
 * Tesla OAuth is the sole trust anchor. The auth URL response also
 * returns a `user_id` (anonymous one created server-side if none
 * was supplied) which we pass through to the eventual JWT response.
 */
@Serializable
data class TeslaAuthUrlResponse(
    val url: String,
    val state: String,
    @SerialName("user_id") val userId: Long? = null,
)
