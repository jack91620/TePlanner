package cloud.teplanner.android.hub.quickactions

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject

/**
 * Wire-format for a shared HubAction. On-device HubAction has
 * extras we don't share (id, isSystem); this type captures
 * exactly what travels through the share code.
 *
 * Icon is the platform-neutral semantic ID — NOT the SF Symbol
 * name. SemanticIcon.semanticFor() projects on serialize;
 * SemanticIcon.symbolFor() projects on import. Mirrors iOS
 * SharedActionPayload.swift.
 */
@Serializable
data class SharedActionPayload(
    val name: String,
    val icon: String,
    val tint: HubActionTint,
    val steps: List<HubActionStep>,
    @SerialName("confirm_required") val confirmRequired: Boolean,
) {
    fun toHubAction(): HubAction = HubAction(
        name = name,
        icon = SemanticIcon.symbolFor(icon),
        tint = tint,
        steps = steps,
        confirmRequired = confirmRequired,
        isSystem = false, // receiver of a shared system action owns it
    )

    companion object {
        fun from(action: HubAction): SharedActionPayload = SharedActionPayload(
            name = action.name,
            icon = SemanticIcon.semanticFor(action.icon),
            tint = action.tint,
            steps = action.steps,
            confirmRequired = action.confirmRequired,
        )
    }
}

/**
 * Wire-format for a shared automation rule. Mirrors iOS
 * SharedRulePayload.swift. RuleSpec (JsonObject) passes through
 * intact — capability + entity IDs are platform-neutral.
 */
@Serializable
data class SharedRulePayload(
    val name: String,
    val enabled: Boolean,
    val spec: kotlinx.serialization.json.JsonObject,
)

/**
 * Encode a Codable share payload into the Map<String, JsonElement>
 * shape POST /shares accepts. Mirrors iOS encodeShareablePayload().
 */
fun encodeShareablePayload(payload: SharedActionPayload, json: Json): Map<String, JsonElement>? {
    return runCatching {
        val text = json.encodeToString(SharedActionPayload.serializer(), payload)
        val element = json.parseToJsonElement(text)
        element as? kotlinx.serialization.json.JsonObject
    }.getOrNull()?.toMap()
}
