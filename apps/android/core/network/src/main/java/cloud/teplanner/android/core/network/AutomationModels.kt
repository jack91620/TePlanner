package cloud.teplanner.android.core.network

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonObject

/**
 * Phase F.2 — automation rule wire shapes mirroring backend
 * `app/api/v1/automations.py` schemas. RuleSpec is treated as opaque
 * JSON (JsonObject) — iOS does the same since D.6, evaluation is
 * fully server-side.
 */
@Serializable
data class RuleResponse(
    val id: String,
    @SerialName("preset_id") val presetId: String? = null,
    val name: String,
    val enabled: Boolean,
    val spec: JsonObject,
    val version: Int = 1,
    @SerialName("last_fired_at") val lastFiredAt: String? = null,
    @SerialName("display_order") val displayOrder: Int? = null,
)

@Serializable
data class RuleListResponse(
    val rules: List<RuleResponse>,
)

@Serializable
data class RuleUpdateRequest(
    val name: String? = null,
    val enabled: Boolean? = null,
    val spec: JsonObject? = null,
)

@Serializable
data class SnoozeListResponse(
    val snoozes: List<SnoozeRecord>,
)

@Serializable
data class SnoozeRecord(
    @SerialName("rule_id") val ruleId: String,
    @SerialName("snoozed_until_utc") val snoozedUntilUtc: String,
    val reason: String? = null,
    @SerialName("created_at") val createdAt: String,
)

@Serializable
data class SnoozeRequest(
    val hours: Double? = null,
    val until: String? = null,
    val reason: String? = null,
)

@Serializable
data class BaseResponse(
    val success: Boolean,
    val message: String? = null,
)

@Serializable
data class ReorderRequest(
    @SerialName("rule_ids") val ruleIds: List<String>,
    val clear: Boolean = false,
)
