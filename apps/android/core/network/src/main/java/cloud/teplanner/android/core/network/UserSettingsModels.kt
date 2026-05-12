package cloud.teplanner.android.core.network

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement

/**
 * Phase A.5 — `/api/v1/user/settings` opaque KV bag.
 *
 * Mirrors iOS `putUserSettings` shape: settings is a free-form
 * Map<String, JsonElement> so each consumer (Hub Quick Actions,
 * charge-limit prefs, etc.) defines its own key + sub-schema
 * without per-key column migrations on the server side.
 *
 * Wire shape pinned by backend/tests/test_user_settings.py.
 */
@Serializable
data class UserSettingsRequest(
    val settings: Map<String, JsonElement>,
    @SerialName("replace_all") val replaceAll: Boolean = false,
)

@Serializable
data class UserSettingsResponse(
    val settings: Map<String, JsonElement> = emptyMap(),
    @SerialName("updated_at") val updatedAt: String? = null,
)
