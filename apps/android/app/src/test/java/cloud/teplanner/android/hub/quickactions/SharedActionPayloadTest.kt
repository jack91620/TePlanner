package cloud.teplanner.android.hub.quickactions

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Mirror of iOS SharedActionPayloadTests. Pins the wire format
 * against silent JSON encoding drift — same five invariants
 * (delay round-trip, nil-delay never serialized as 0, mixed-type
 * params, Chinese names, isSystem stripped on import).
 */
class SharedActionPayloadTest {

    private val json: Json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    // MARK: - delayMsAfter Optional Int round-trip

    @Test
    fun `step delay survives encode-decode when set`() {
        val original = SharedActionPayload(
            name = "离家",
            icon = "house",
            tint = HubActionTint.BLUE,
            steps = listOf(
                HubActionStep(
                    capability = "tesla.security.set_sentry",
                    params = mapOf("vehicle.sentry_mode_on" to JsonPrimitive(true)),
                    delayMsAfter = 3000,
                ),
                HubActionStep(capability = "tesla.security.door_lock"),
            ),
            confirmRequired = true,
        )
        val text = json.encodeToString(SharedActionPayload.serializer(), original)
        val decoded = json.decodeFromString(SharedActionPayload.serializer(), text)
        assertEquals(2, decoded.steps.size)
        assertEquals(3000, decoded.steps[0].delayMsAfter)
        assertNull(decoded.steps[1].delayMsAfter)
    }

    @Test
    fun `step delay nil omitted or null on wire — never zero`() {
        val original = SharedActionPayload(
            name = "锁车",
            icon = "lock",
            tint = HubActionTint.BLUE,
            steps = listOf(HubActionStep(capability = "tesla.security.door_lock")),
            confirmRequired = false,
        )
        val text = json.encodeToString(SharedActionPayload.serializer(), original)
        // Either omit the key or send null. Neither should serialize
        // as 0 — that would set a real 0ms wait on import.
        assertFalse(
            "delayMsAfter=null must not serialize as 0",
            text.contains("\"delay_ms_after\":0"),
        )
        val decoded = json.decodeFromString(SharedActionPayload.serializer(), text)
        assertNull(decoded.steps[0].delayMsAfter)
    }

    // MARK: - Step params (JsonElement round-trip)

    @Test
    fun `step params with mixed types round-trip`() {
        val original = SharedActionPayload(
            name = "充电",
            icon = "bolt",
            tint = HubActionTint.ORANGE,
            steps = listOf(
                HubActionStep(
                    capability = "tesla.charging.set_limit",
                    params = mapOf(
                        "vehicle.charge_limit_soc" to JsonPrimitive(80),
                        "vehicle.locked" to JsonPrimitive(true),
                        "vehicle.note" to JsonPrimitive("home"),
                    ),
                ),
            ),
            confirmRequired = false,
        )
        val text = json.encodeToString(SharedActionPayload.serializer(), original)
        val decoded = json.decodeFromString(SharedActionPayload.serializer(), text)
        val params = decoded.steps[0].params
        assertEquals(JsonPrimitive(80), params["vehicle.charge_limit_soc"])
        assertEquals(JsonPrimitive(true), params["vehicle.locked"])
        assertEquals(JsonPrimitive("home"), params["vehicle.note"])
    }

    // MARK: - Chinese names

    @Test
    fun `encodeShareablePayload preserves Chinese name and keys`() {
        val original = SharedActionPayload(
            name = "上下班通勤",
            icon = "house",
            tint = HubActionTint.GREEN,
            steps = listOf(HubActionStep(capability = "tesla.climate.preheat")),
            confirmRequired = false,
        )
        val bag = encodeShareablePayload(original, json)
        assertNotNull("encodeShareablePayload returned null", bag)
        assertEquals(JsonPrimitive("上下班通勤"), bag?.get("name"))
        assertEquals(JsonPrimitive("house"), bag?.get("icon"))
        assertEquals(JsonPrimitive(false), bag?.get("confirm_required"))
    }

    // MARK: - HubAction <-> SharedActionPayload symmetry

    @Test
    fun `HubAction to payload and back preserves steps`() {
        val source = HubAction(
            name = "宠物模式",
            icon = "thermometer.medium",
            tint = HubActionTint.GREEN,
            steps = listOf(
                HubActionStep(
                    capability = "tesla.climate.set_keeper_mode",
                    params = mapOf("vehicle.climate.keeper_mode" to JsonPrimitive(2)),
                    delayMsAfter = null,
                ),
                HubActionStep(
                    capability = "tesla.security.set_sentry",
                    params = mapOf("vehicle.sentry_mode_on" to JsonPrimitive(false)),
                    delayMsAfter = 5000,
                ),
            ),
            confirmRequired = true,
        )
        val payload = SharedActionPayload.from(source)
        val imported = payload.toHubAction()

        assertEquals(source.name, imported.name)
        assertEquals(source.tint, imported.tint)
        assertEquals(source.confirmRequired, imported.confirmRequired)
        assertEquals(source.steps.size, imported.steps.size)
        assertEquals("tesla.climate.set_keeper_mode", imported.steps[0].capability)
        assertEquals(JsonPrimitive(2), imported.steps[0].params["vehicle.climate.keeper_mode"])
        assertNull(imported.steps[0].delayMsAfter)
        assertEquals(5000, imported.steps[1].delayMsAfter)
        // isSystem MUST be false on import even if source was system.
        assertFalse(imported.isSystem)
        // Fresh UUID — must NOT collide with source.
        assertNotEquals(source.id, imported.id)
        // SF Symbol → semantic → SF Symbol round-trip works.
        assertEquals("thermometer.medium", imported.icon)
    }

    @Test
    fun `system action share drops system flag on import`() {
        val source = HubAction(
            name = "锁车",
            icon = "lock.fill",
            tint = HubActionTint.BLUE,
            steps = listOf(HubActionStep(capability = "tesla.security.door_lock")),
            confirmRequired = false,
            isSystem = true,
        )
        val imported = SharedActionPayload.from(source).toHubAction()
        assertFalse(
            "receiver of a shared system action must own it (not inherit the system flag)",
            imported.isSystem,
        )
    }
}
