package cloud.teplanner.android.hub.quickactions

import cloud.teplanner.android.core.network.UserApi
import cloud.teplanner.android.core.network.UserSettingsRequest
import cloud.teplanner.android.core.network.UserSettingsResponse
import cloud.teplanner.android.core.network.ScheduledDepartureRequest
import cloud.teplanner.android.core.network.ScheduledDepartureResponse
import cloud.teplanner.android.core.network.ClearResponse
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * Mirror of iOS HubActionsStoreTests. Pins the store's persistence
 * contract + seeding + CRUD + slot operations + import disambiguator
 * + resetToDefaults — same invariants on both platforms.
 */
class HubActionsStoreTest {

    private lateinit var api: FakeUserApi
    private lateinit var store: HubActionsStore

    @Before
    fun setUp() {
        api = FakeUserApi()
        store = HubActionsStore(api)
    }

    // MARK: - Seed defaults

    @Test
    fun `fresh user load seeds four system actions`() = runBlocking {
        store.load()

        assertEquals(4, store.actions.value.size)
        assertTrue(
            "all seeded actions should be marked isSystem",
            store.actions.value.all { it.isSystem },
        )
        assertEquals(HubSlots.COUNT, store.slots.value.slots.size)
        assertNotNull(store.slots.value.slots[0])
        assertNotNull(store.slots.value.slots[3])
        assertNull(store.slots.value.slots[4])
        // Persisted via PUT.
        assertNotNull(api.lastPut)
        assertNotNull(api.lastPut?.settings?.get(HubActionsStore.HUB_ACTIONS_KEY))
        assertNotNull(api.lastPut?.settings?.get(HubActionsStore.HUB_SLOTS_KEY))
    }

    @Test
    fun `load on existing user does not re-seed`() = runBlocking {
        // Pre-seed with empty hub.* keys: user explicitly cleared.
        api.mockSettings = mapOf(
            HubActionsStore.HUB_ACTIONS_KEY to Json.parseToJsonElement("[]"),
            HubActionsStore.HUB_SLOTS_KEY to Json.parseToJsonElement(
                """{"slots":[null,null,null,null,null,null,null,null]}"""
            ),
        )
        store.load()

        assertEquals(0, store.actions.value.size)
        assertTrue(store.slots.value.slots.all { it == null })
        // No re-seed = no PUT call.
        assertNull(api.lastPut)
    }

    // MARK: - importAction disambiguation

    @Test
    fun `import appends 副本 suffix on name collision`() = runBlocking {
        store.load() // seeds the 锁车 system action

        val imported = HubAction(
            name = "锁车",
            icon = "lock.fill",
            tint = HubActionTint.BLUE,
            steps = listOf(HubActionStep(capability = "tesla.security.door_lock")),
            confirmRequired = false,
        )
        store.importAction(imported)

        val names = store.actions.value.map { it.name }
        assertTrue("system 锁车 still there", names.contains("锁车"))
        assertTrue("imported renamed to 锁车 副本", names.contains("锁车 副本"))
        assertEquals(5, store.actions.value.size)
    }

    @Test
    fun `import keeps name when no collision`() = runBlocking {
        store.load()
        val imported = HubAction(
            name = "通勤",
            icon = "house.fill",
            tint = HubActionTint.GREEN,
            steps = listOf(HubActionStep(capability = "tesla.climate.preheat")),
            confirmRequired = false,
        )
        store.importAction(imported)
        assertTrue(store.actions.value.any { it.name == "通勤" })
    }

    @Test
    fun `second collision gets numbered suffix`() = runBlocking {
        store.load()
        val a1 = HubAction(
            name = "锁车", icon = "lock.fill", tint = HubActionTint.BLUE,
            steps = listOf(HubActionStep(capability = "tesla.security.door_lock")),
            confirmRequired = false,
        )
        store.importAction(a1)
        val a2 = HubAction(
            name = "锁车", icon = "lock.fill", tint = HubActionTint.BLUE,
            steps = listOf(HubActionStep(capability = "tesla.security.door_lock")),
            confirmRequired = false,
        )
        store.importAction(a2)
        val names = store.actions.value.map { it.name }.toSet()
        assertTrue(names.contains("锁车"))
        assertTrue(names.contains("锁车 副本"))
        assertTrue(names.contains("锁车 副本 2"))
    }

    @Test
    fun `import always sets isSystem false`() = runBlocking {
        store.load()
        val imported = HubAction(
            name = "Imported",
            icon = "lock.fill",
            tint = HubActionTint.BLUE,
            steps = listOf(HubActionStep(capability = "tesla.security.door_lock")),
            confirmRequired = false,
            isSystem = true,
        )
        store.importAction(imported)
        val row = store.actions.value.firstOrNull { it.name == "Imported" }
        assertEquals(false, row?.isSystem)
    }

    // MARK: - Slot ops

    @Test
    fun `assignSlot moves action between slots`() = runBlocking {
        store.load()
        // Initial: 锁车 in slot 0, slot 4 empty.
        assertEquals("system_lock", store.slots.value.slots[0])
        assertNull(store.slots.value.slots[4])

        store.assignSlot(index = 4, actionId = "system_lock")
        // Action moved to slot 4; old slot 0 cleared (one slot per action).
        assertNull(store.slots.value.slots[0])
        assertEquals("system_lock", store.slots.value.slots[4])
    }

    @Test
    fun `assignSlot with null clears the slot`() = runBlocking {
        store.load()
        store.assignSlot(index = 0, actionId = null)
        assertNull(store.slots.value.slots[0])
    }

    @Test
    fun `swapSlots swaps two positions`() = runBlocking {
        store.load()
        val sBefore0 = store.slots.value.slots[0]
        val sBefore3 = store.slots.value.slots[3]
        store.swapSlots(0, 3)
        assertEquals(sBefore3, store.slots.value.slots[0])
        assertEquals(sBefore0, store.slots.value.slots[3])
    }

    // MARK: - delete

    @Test
    fun `delete custom action removes from library and clears slot`() = runBlocking {
        store.load()
        val customId = store.create(
            name = "通勤",
            icon = "house.fill",
            tint = HubActionTint.GREEN,
            steps = listOf(HubActionStep(capability = "tesla.climate.preheat")),
            confirmRequired = false,
        )
        // Custom auto-assigned to slot 4 (first empty).
        assertEquals(customId, store.slots.value.slots[4])

        store.delete(customId)
        assertFalse(store.actions.value.any { it.id == customId })
        assertNull(store.slots.value.slots[4])
    }

    @Test
    fun `delete system action is a no-op`() = runBlocking {
        store.load()
        val originalCount = store.actions.value.size
        store.delete("system_lock")
        assertEquals(originalCount, store.actions.value.size)
        // Slot 0 unchanged.
        assertEquals("system_lock", store.slots.value.slots[0])
    }

    // MARK: - resetToDefaults

    @Test
    fun `resetToDefaults wipes custom and reseeds system`() = runBlocking {
        store.load()
        store.create(
            name = "通勤",
            icon = "house.fill",
            tint = HubActionTint.GREEN,
            steps = listOf(HubActionStep(capability = "tesla.climate.preheat")),
            confirmRequired = false,
        )
        assertEquals(5, store.actions.value.size)

        store.resetToDefaults()
        // Back to the 4 seeded system actions only.
        assertEquals(4, store.actions.value.size)
        assertTrue(store.actions.value.all { it.isSystem })
        assertFalse(store.actions.value.any { it.name == "通勤" })
    }

    // MARK: - Slot encoding

    @Test
    fun `slots encode as object with slots array`() = runBlocking {
        store.load()
        val bag = api.lastPut?.settings ?: error("no PUT")
        val slotsEl = bag[HubActionsStore.HUB_SLOTS_KEY]
            as? JsonObject
            ?: error("hub.slots not an object")
        val arr = slotsEl["slots"] ?: error("missing slots array")
        // Manually count the array length via its toString — kxs JsonArray
        // exposes size via the type cast.
        val arrSize = (arr as kotlinx.serialization.json.JsonArray).size
        assertEquals(HubSlots.COUNT, arrSize)
    }
}

/// In-memory fake of UserApi for these tests. Captures the most-
/// recent PUT body so assertions can inspect what was persisted.
private class FakeUserApi : UserApi {
    var mockSettings: Map<String, JsonElement> = emptyMap()
    var lastPut: UserSettingsRequest? = null

    override suspend fun getUserSettings(): UserSettingsResponse =
        UserSettingsResponse(settings = mockSettings, updatedAt = null)

    override suspend fun putUserSettings(request: UserSettingsRequest): UserSettingsResponse {
        lastPut = request
        // Apply merge / replaceAll semantics (replaceAll=false → merge).
        mockSettings = if (request.replaceAll) request.settings
                       else mockSettings + request.settings
        return UserSettingsResponse(settings = mockSettings, updatedAt = "2026-05-12T00:00:00Z")
    }

    override suspend fun getScheduledDeparture(): ScheduledDepartureResponse? = null
    override suspend fun upsertScheduledDeparture(
        request: ScheduledDepartureRequest,
    ): ScheduledDepartureResponse = error("unused in HubActionsStore tests")
    override suspend fun clearScheduledDeparture(): ClearResponse =
        ClearResponse(success = true)
}
