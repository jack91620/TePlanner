package cloud.teplanner.android.hub.quickactions

import android.util.Log
import cloud.teplanner.android.core.network.UserApi
import cloud.teplanner.android.core.network.UserSettingsRequest
import dagger.hilt.android.scopes.ViewModelScoped
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.util.UUID
import javax.inject.Inject

/**
 * Kotlin port of iOS `HubActionsStore`. Single source of truth for
 * the user's Quick Actions library (`actions`) and on-Hub slot
 * assignments (`slots`). Persists to backend `/user/settings` under
 * keys `hub.actions` + `hub.slots` — same keys iOS uses, so the
 * two clients can share state when the same user signs in on both
 * platforms.
 *
 * Public mutators (create / update / delete / assignSlot / swapSlots /
 * resetToDefaults / importAction) update the StateFlow synchronously
 * then fire off a persistAll() to push to the backend. Loaders are
 * forgiving — unknown keys / malformed JSON fall back to the seeded
 * defaults rather than crashing the Hub.
 */
@ViewModelScoped
class HubActionsStore @Inject constructor(
    private val userApi: UserApi,
) {

    private val json: Json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    private val _actions = MutableStateFlow<List<HubAction>>(emptyList())
    val actions: StateFlow<List<HubAction>> = _actions.asStateFlow()

    private val _slots = MutableStateFlow(HubSlots())
    val slots: StateFlow<HubSlots> = _slots.asStateFlow()

    fun action(id: String): HubAction? = _actions.value.firstOrNull { it.id == id }

    fun slotAction(index: Int): HubAction? {
        val slotId = _slots.value.slots.getOrNull(index) ?: return null
        return action(slotId)
    }

    suspend fun load() {
        val resp = runCatching { userApi.getUserSettings() }.getOrNull()
        val bag = resp?.settings ?: emptyMap()

        if (HUB_ACTIONS_KEY !in bag && HUB_SLOTS_KEY !in bag) {
            seedDefaults()
            persistAll()
            return
        }

        val decodedActions = decodeActions(bag[HUB_ACTIONS_KEY])
        val decodedSlots = decodeSlots(bag[HUB_SLOTS_KEY])
        _actions.value = decodedActions
        _slots.value = decodedSlots
    }

    suspend fun create(
        name: String,
        icon: String,
        tint: HubActionTint,
        steps: List<HubActionStep>,
        confirmRequired: Boolean,
        assignToFirstEmpty: Boolean = true,
    ): String {
        val action = HubAction(
            name = name,
            icon = icon,
            tint = tint,
            steps = steps,
            confirmRequired = confirmRequired,
        )
        _actions.update { it + action }
        if (assignToFirstEmpty) {
            val firstEmpty = _slots.value.slots.indexOfFirst { it == null }
            if (firstEmpty >= 0) {
                _slots.value = _slots.value.withSlot(firstEmpty, action.id)
            }
        }
        persistAll()
        return action.id
    }

    /**
     * Insert an action received via share code. The caller already
     * generated a fresh id (HubAction's default UUID); we only drop
     * it into the library + persist. Imported actions are NEVER
     * auto-assigned to a slot — the user explicitly chooses.
     *
     * Name collision handling: if any existing action (system or
     * custom) shares this name, append "  副本" / " 副本 2" / ... so
     * the picker row stays distinguishable. Mirrors iOS commit
     * cfd6556.
     */
    suspend fun importAction(action: HubAction) {
        val uniqueName = disambiguateImportedName(action.name)
        val idCollision = _actions.value.any { it.id == action.id }
        val importing = action.copy(
            id = if (idCollision) UUID.randomUUID().toString() else action.id,
            name = uniqueName,
            isSystem = false, // imports are always user-owned
        )
        _actions.update { it + importing }
        persistAll()
    }

    fun disambiguateImportedName(base: String): String {
        val taken = _actions.value.map { it.name }.toSet()
        if (base !in taken) return base
        var candidate = "$base 副本"
        var counter = 2
        while (candidate in taken) {
            candidate = "$base 副本 $counter"
            counter += 1
        }
        return candidate
    }

    suspend fun update(
        id: String,
        name: String,
        icon: String,
        tint: HubActionTint,
        steps: List<HubActionStep>,
        confirmRequired: Boolean,
    ) {
        _actions.update { list ->
            list.map { a ->
                if (a.id == id) a.copy(
                    name = name,
                    icon = icon,
                    tint = tint,
                    steps = steps,
                    confirmRequired = confirmRequired,
                ) else a
            }
        }
        persistAll()
    }

    suspend fun delete(id: String) {
        val target = action(id) ?: return
        if (target.isSystem) return
        _actions.update { it.filter { a -> a.id != id } }
        // Clear any slot referencing this action.
        _slots.update { current ->
            val cleared = current.slots.map { if (it == id) null else it }
            HubSlots(cleared)
        }
        persistAll()
    }

    suspend fun assignSlot(index: Int, actionId: String?) {
        if (index !in 0 until HubSlots.COUNT) return
        _slots.update { current ->
            var next = current
            if (actionId != null) {
                // An action can only occupy one slot at a time —
                // clear any other slot already holding it.
                val cleared = current.slots.mapIndexed { i, id ->
                    if (i != index && id == actionId) null else id
                }
                next = HubSlots(cleared)
            }
            next.withSlot(index, actionId)
        }
        persistSlots()
    }

    suspend fun swapSlots(a: Int, b: Int) {
        if (a !in 0 until HubSlots.COUNT || b !in 0 until HubSlots.COUNT || a == b) {
            return
        }
        _slots.update { it.swap(a, b) }
        persistSlots()
    }

    suspend fun resetToDefaults() {
        _actions.value = emptyList()
        _slots.value = HubSlots()
        seedDefaults()
        persistAll()
    }

    // MARK: - Default seeding (mirrors iOS HubActionsStore.seedDefaults)

    private fun seedDefaults() {
        val presets = listOf(
            HubAction(
                id = "system_lock",
                name = "锁车",
                icon = "lock.fill",
                tint = HubActionTint.BLUE,
                steps = listOf(HubActionStep(capability = "tesla.security.door_lock")),
                confirmRequired = false,
                isSystem = true,
            ),
            HubAction(
                id = "system_unlock",
                name = "解锁",
                icon = "lock.open.fill",
                tint = HubActionTint.RED,
                steps = listOf(HubActionStep(capability = "tesla.security.door_unlock")),
                confirmRequired = true,
                isSystem = true,
            ),
            HubAction(
                id = "system_preheat",
                name = "预热",
                icon = "thermometer.medium",
                tint = HubActionTint.ORANGE,
                steps = listOf(HubActionStep(capability = "tesla.climate.preheat")),
                confirmRequired = true,
                isSystem = true,
            ),
            HubAction(
                id = "system_trunk",
                name = "后备箱",
                icon = "suitcase.fill",
                tint = HubActionTint.BLUE,
                steps = listOf(HubActionStep(capability = "tesla.security.actuate_trunk")),
                confirmRequired = true,
                isSystem = true,
            ),
        )
        _actions.value = presets
        _slots.value = HubSlots(
            slots = listOf(
                presets[0].id, presets[1].id, presets[2].id, presets[3].id,
                null, null, null, null,
            )
        )
    }

    // MARK: - Persistence helpers

    private suspend fun persistAll() {
        val bag = mapOf(
            HUB_ACTIONS_KEY to encodeActions(),
            HUB_SLOTS_KEY to encodeSlots(),
        )
        runCatching {
            userApi.putUserSettings(UserSettingsRequest(settings = bag, replaceAll = false))
        }.onFailure { Log.w(TAG, "persistAll failed: ${it.message}") }
    }

    private suspend fun persistSlots() {
        val bag = mapOf(HUB_SLOTS_KEY to encodeSlots())
        runCatching {
            userApi.putUserSettings(UserSettingsRequest(settings = bag, replaceAll = false))
        }.onFailure { Log.w(TAG, "persistSlots failed: ${it.message}") }
    }

    private fun encodeActions(): JsonElement =
        json.encodeToJsonElement(kotlinx.serialization.serializer(), _actions.value)

    private fun encodeSlots(): JsonElement =
        json.encodeToJsonElement(kotlinx.serialization.serializer(), _slots.value)

    private fun <T> Json.encodeToJsonElement(
        serializer: kotlinx.serialization.KSerializer<T>,
        value: T,
    ): JsonElement {
        val text = this.encodeToString(serializer, value)
        return this.parseToJsonElement(text)
    }

    private fun decodeActions(raw: JsonElement?): List<HubAction> {
        if (raw == null) return emptyList()
        return runCatching {
            json.decodeFromJsonElement<List<HubAction>>(
                kotlinx.serialization.serializer(),
                raw,
            )
        }.getOrElse {
            Log.w(TAG, "decodeActions failed: ${it.message}")
            emptyList()
        }
    }

    private fun decodeSlots(raw: JsonElement?): HubSlots {
        if (raw == null) return HubSlots()
        return runCatching {
            // iOS encodes HubSlots as { "slots": [...] }. Tolerate
            // raw arrays too (a previous Android build might have
            // emitted that shape) by checking the wire shape first.
            val obj = raw.jsonObject
            val arr = obj["slots"]?.jsonArray
                ?: return@runCatching HubSlots.normalized(emptyList())
            val ids = arr.map { el ->
                val prim = runCatching { el.jsonPrimitive }.getOrNull()
                if (prim == null || prim.isString.not()) null else prim.content
            }
            HubSlots.normalized(ids)
        }.getOrElse {
            Log.w(TAG, "decodeSlots failed: ${it.message}")
            HubSlots()
        }
    }

    private fun <T> Json.decodeFromJsonElement(
        serializer: kotlinx.serialization.KSerializer<T>,
        element: JsonElement,
    ): T {
        val text = element.toString()
        return this.decodeFromString(serializer, text)
    }

    companion object {
        private const val TAG = "HubActionsStore"
        const val HUB_ACTIONS_KEY = "hub.actions"
        const val HUB_SLOTS_KEY = "hub.slots"
    }
}
