package cloud.teplanner.android.hub.quickactions

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement
import java.util.UUID

/**
 * One step inside a Hub Quick Action. Maps 1:1 to a Tesla capability
 * invocation. Wire format mirrors iOS `HubActionStep` exactly so
 * user_settings.hub.actions round-trips cleanly between platforms.
 *
 * `delayMsAfter` is the gap *after* dispatching this step before the
 * next one fires — useful for "lock the car, wait 5s, then start
 * sentry" sequences. nil = fire next step immediately.
 */
@Serializable
data class HubActionStep(
    val capability: String,
    val params: Map<String, JsonElement> = emptyMap(),
    @SerialName("delay_ms_after") val delayMsAfter: Int? = null,
)

/**
 * Tint colour for a tile. Five preset choices keep the Hub visually
 * coherent. Matches iOS HubActionTint values exactly.
 */
@Serializable
enum class HubActionTint {
    @SerialName("blue") BLUE,
    @SerialName("red") RED,
    @SerialName("orange") ORANGE,
    @SerialName("green") GREEN,
    @SerialName("gray") GRAY,
    ;

    companion object {
        val DEFAULT: HubActionTint = BLUE
    }
}

/**
 * A user-defined (or system-seeded) Hub Quick Action. The list of
 * all actions lives in user_settings["hub.actions"]; the 8 on-screen
 * slots reference them by id (user_settings["hub.slots"]). Decoupled
 * so a user can rearrange slots without losing definitions.
 *
 * `icon` stores the iOS SF Symbol name (so cross-device sync works
 * round-trip); HubIconLibrary on Android maps SF Symbol → Material
 * icon at render time.
 */
@Serializable
data class HubAction(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val icon: String,
    val tint: HubActionTint = HubActionTint.DEFAULT,
    val steps: List<HubActionStep>,
    @SerialName("confirm_required") val confirmRequired: Boolean = false,
    @SerialName("is_system") val isSystem: Boolean = false,
    // NOTE: iOS HubAction has a `createdAt` field for sort order in
    // the manage sheet (Apple-epoch Double in the wire format —
    // ~800268505.86 for early-2026 records). Android doesn't use
    // it; the JSON config's ignoreUnknownKeys flag lets iOS's
    // value pass through harmlessly. Adding a Kotlin field here
    // would require a custom serializer to accept both number
    // and string types (iOS's value type drifted over time).
)

/**
 * User's on-Hub action assignments. Length-8 fixed (2×4 grid).
 * Element null = empty slot; non-null = a HubAction.id.
 * Wire format matches iOS HubSlots: serializes as
 * `{"slots": [id-or-null, ...8 elements]}`.
 */
@Serializable
data class HubSlots(
    val slots: List<String?> = List(COUNT) { null },
) {
    init {
        require(slots.size == COUNT) {
            "HubSlots requires exactly $COUNT slots; got ${slots.size}"
        }
    }

    fun withSlot(index: Int, actionId: String?): HubSlots {
        require(index in 0 until COUNT) { "slot index out of range: $index" }
        return copy(slots = slots.toMutableList().also { it[index] = actionId })
    }

    fun swap(a: Int, b: Int): HubSlots {
        require(a in 0 until COUNT && b in 0 until COUNT) { "swap indices out of range" }
        if (a == b) return this
        return copy(slots = slots.toMutableList().also {
            val tmp = it[a]
            it[a] = it[b]
            it[b] = tmp
        })
    }

    companion object {
        const val COUNT: Int = 8

        /** Forgiving decode helper: shorter arrays pad with nulls,
         *  longer arrays truncate. Mirrors iOS HubSlots.normalize. */
        fun normalized(raw: List<String?>): HubSlots {
            val padded = raw.take(COUNT) + List(maxOf(0, COUNT - raw.size)) { null }
            return HubSlots(padded)
        }
    }
}
