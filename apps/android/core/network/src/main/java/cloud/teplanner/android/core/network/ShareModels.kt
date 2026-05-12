package cloud.teplanner.android.core.network

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement

/**
 * Wire models for `/api/v1/shares` — mirrors iOS
 * apps/ios/Sources/TePlannerKit/Models/ShareModels.swift.
 *
 * Server-side schema in backend/app/api/v1/shares.py and the
 * 0010_shares migration. Two share kinds:
 *   - "action" → a HubAction (icon is the platform-neutral
 *     semantic ID, not the SF Symbol name)
 *   - "rule"   → an automation RuleSpec
 *
 * The `payload` field is intentionally opaque (Map<String,
 * JsonElement>) so the wire format can extend without backend
 * migrations; each platform projects it into its own typed
 * SharedActionPayload / SharedRulePayload at decode time.
 */

@Serializable
enum class ShareType {
    @SerialName("action") ACTION,
    @SerialName("rule") RULE,
}

@Serializable
data class ShareCreateRequest(
    @SerialName("share_type") val shareType: ShareType,
    val payload: Map<String, JsonElement>,
    @SerialName("expires_in_days") val expiresInDays: Int = 30,
    @SerialName("min_app_version") val minAppVersion: String? = null,
)

@Serializable
data class ShareDetailResponse(
    val code: String,
    @SerialName("share_type") val shareType: ShareType,
    @SerialName("created_at") val createdAt: String,
    @SerialName("expires_at") val expiresAt: String,
    @SerialName("view_count") val viewCount: Int,
    @SerialName("min_app_version") val minAppVersion: String? = null,
    val payload: Map<String, JsonElement>,
    val revoked: Boolean = false,
)

@Serializable
data class ShareSummary(
    val code: String,
    @SerialName("share_type") val shareType: ShareType,
    @SerialName("created_at") val createdAt: String,
    @SerialName("expires_at") val expiresAt: String,
    @SerialName("view_count") val viewCount: Int,
    @SerialName("min_app_version") val minAppVersion: String? = null,
    val revoked: Boolean = false,
)

@Serializable
data class ShareListResponse(
    val shares: List<ShareSummary> = emptyList(),
)
