package cloud.teplanner.android.automations

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.int
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Wire-format pinning for the spec build/decode round-trip. The
 * backend interpreter is byte-sensitive — these tests guarantee the
 * shape iOS RuleBuilderView.buildSpec() emits is preserved on
 * Android.
 *
 * Sister to iOS RuleSpecTests / RuleBuilderViewTests. Adding a new
 * trigger type or capability id? Add a test here too.
 */
class RuleBuilderSpecTest {

    private fun emptyParams(): JsonObject = JsonObject(emptyMap())

    @Test
    fun `state_duration with keeper_mode = camp builds expected spec`() {
        val spec = buildSpec(
            triggerType = TriggerType.STATE_DURATION,
            entity = VehicleEntity.CLIMATE_KEEPER,
            compareInt = 3, compareBool = true, toString_ = "Complete",
            numericOp = NumericOp.LT, numericValue = 30,
            forMinutes = 60,
            cronHour = 7, cronMinute = 30,
            cronWeekdays = setOf(1, 2, 3, 4, 5),
            geofenceLat = null, geofenceLng = null,
            geofenceRadiusM = 200, geofenceEvent = GeofenceEvent.ENTER,
            actionType = ActionType.NOTIFY,
            actionTitle = "露营超时", actionBody = "已 1 小时",
            actionSeverity = AlertSeverity.INFO,
            primaryActionLabel = "", selectedCapabilityId = "",
            paramOverrides = emptyParams(),
        )
        assertEquals("campMode", (spec["kind"] as JsonPrimitive).content)
        val trigger = spec["trigger"] as JsonObject
        assertEquals("state_duration", (trigger["type"] as JsonPrimitive).content)
        assertEquals("vehicle.climate.keeper_mode", (trigger["entity"] as JsonPrimitive).content)
        assertEquals(3, (trigger["equals"] as JsonPrimitive).int)
        assertEquals(60, (trigger["for_minutes"] as JsonPrimitive).int)
        assertEquals("user:campMode:startedAt", (trigger["state_key"] as JsonPrimitive).content)
        // state_duration uses actions_above[0] + empty actions_below[].
        val above = spec["actions_above"] as JsonArray
        assertEquals(1, above.size)
        val action = above[0] as JsonObject
        assertEquals("notify", (action["type"] as JsonPrimitive).content)
        assertEquals("露营超时", (action["title"] as JsonPrimitive).content)
        assertNull(action["capability"])
    }

    @Test
    fun `state_transition with chargeComplete uses to + dismissed_key`() {
        val spec = buildSpec(
            triggerType = TriggerType.STATE_TRANSITION,
            entity = VehicleEntity.CHARGING_STATE,
            compareInt = 0, compareBool = true, toString_ = "Complete",
            numericOp = NumericOp.LT, numericValue = 0,
            forMinutes = 0,
            cronHour = 7, cronMinute = 30, cronWeekdays = setOf(),
            geofenceLat = null, geofenceLng = null,
            geofenceRadiusM = 0, geofenceEvent = GeofenceEvent.ENTER,
            actionType = ActionType.NOTIFY,
            actionTitle = "充电完成", actionBody = "",
            actionSeverity = AlertSeverity.INFO,
            primaryActionLabel = "", selectedCapabilityId = "",
            paramOverrides = emptyParams(),
        )
        assertEquals("chargeComplete", (spec["kind"] as JsonPrimitive).content)
        val trigger = spec["trigger"] as JsonObject
        assertEquals("state_transition", (trigger["type"] as JsonPrimitive).content)
        assertEquals("Complete", (trigger["to"] as JsonPrimitive).content)
        assertTrue((trigger["reset_when_not_to"] as JsonPrimitive).boolean)
        assertNotNull(trigger["dismissed_key"])
        // state_transition uses single actions[] bucket (no above/below).
        assertNotNull(spec["actions"])
        assertNull(spec["actions_above"])
    }

    @Test
    fun `cron weekday preheat builds 5-field expression`() {
        val spec = buildSpec(
            triggerType = TriggerType.CRON,
            entity = VehicleEntity.CLIMATE_KEEPER,
            compareInt = 0, compareBool = true, toString_ = "",
            numericOp = NumericOp.LT, numericValue = 0,
            forMinutes = 0,
            cronHour = 7, cronMinute = 30,
            cronWeekdays = setOf(1, 3, 5),
            geofenceLat = null, geofenceLng = null,
            geofenceRadiusM = 0, geofenceEvent = GeofenceEvent.ENTER,
            actionType = ActionType.NOTIFY,
            actionTitle = "工作日预热", actionBody = "",
            actionSeverity = AlertSeverity.INFO,
            primaryActionLabel = "", selectedCapabilityId = "",
            paramOverrides = emptyParams(),
        )
        assertEquals("weekdayPreheat", (spec["kind"] as JsonPrimitive).content)
        val trigger = spec["trigger"] as JsonObject
        assertEquals("30 7 * * 1,3,5", (trigger["expr"] as JsonPrimitive).content)
        assertEquals("Asia/Shanghai", (trigger["tz"] as JsonPrimitive).content)
        // No entity field — cron doesn't observe an entity.
        assertNull(trigger["entity"])
    }

    @Test
    fun `geofence enter emits lat lng radius and event`() {
        val spec = buildSpec(
            triggerType = TriggerType.GEOFENCE,
            entity = VehicleEntity.CLIMATE_KEEPER,
            compareInt = 0, compareBool = true, toString_ = "",
            numericOp = NumericOp.LT, numericValue = 0,
            forMinutes = 0, cronHour = 0, cronMinute = 0,
            cronWeekdays = setOf(),
            geofenceLat = 31.2304, geofenceLng = 121.4737,
            geofenceRadiusM = 300, geofenceEvent = GeofenceEvent.EXIT,
            actionType = ActionType.NOTIFY,
            actionTitle = "离开公司", actionBody = "",
            actionSeverity = AlertSeverity.INFO,
            primaryActionLabel = "", selectedCapabilityId = "",
            paramOverrides = emptyParams(),
        )
        assertEquals("geofenceExit", (spec["kind"] as JsonPrimitive).content)
        val trigger = spec["trigger"] as JsonObject
        assertEquals("geofence", (trigger["type"] as JsonPrimitive).content)
        assertEquals(300, (trigger["radius_m"] as JsonPrimitive).int)
        assertEquals("exit", (trigger["event"] as JsonPrimitive).content)
        assertEquals(
            "user:geo:geofenceExit",
            (trigger["state_key"] as JsonPrimitive).content,
        )
    }

    @Test
    fun `notify_and_offer with capability emits capability + params`() {
        val params = buildJsonObject {
            put("mode", JsonPrimitive(0))
        }
        val spec = buildSpec(
            triggerType = TriggerType.STATE_DURATION,
            entity = VehicleEntity.CLIMATE_KEEPER,
            compareInt = 3, compareBool = true, toString_ = "",
            numericOp = NumericOp.LT, numericValue = 0,
            forMinutes = 60, cronHour = 0, cronMinute = 0,
            cronWeekdays = setOf(),
            geofenceLat = null, geofenceLng = null,
            geofenceRadiusM = 0, geofenceEvent = GeofenceEvent.ENTER,
            actionType = ActionType.NOTIFY_AND_OFFER,
            actionTitle = "露营超时", actionBody = "",
            actionSeverity = AlertSeverity.CRITICAL,
            primaryActionLabel = "关闭露营",
            selectedCapabilityId = "tesla.climate.set_keeper_mode",
            paramOverrides = params,
        )
        val action = (spec["actions_above"] as JsonArray)[0] as JsonObject
        assertEquals("notify_and_offer", (action["type"] as JsonPrimitive).content)
        assertEquals("关闭露营", (action["primary_action_label"] as JsonPrimitive).content)
        assertEquals(
            "tesla.climate.set_keeper_mode",
            (action["capability"] as JsonPrimitive).content,
        )
        val p = action["params"] as JsonObject
        assertEquals(0, (p["mode"] as JsonPrimitive).int)
        assertEquals("critical", (action["severity"] as JsonPrimitive).content)
    }

    @Test
    fun `notify_and_offer with empty capability uses automation_dismiss sentinel`() {
        val spec = buildSpec(
            triggerType = TriggerType.STATE_DURATION,
            entity = VehicleEntity.SENTRY,
            compareInt = 0, compareBool = true, toString_ = "",
            numericOp = NumericOp.LT, numericValue = 0,
            forMinutes = 30, cronHour = 0, cronMinute = 0,
            cronWeekdays = setOf(),
            geofenceLat = null, geofenceLng = null,
            geofenceRadiusM = 0, geofenceEvent = GeofenceEvent.ENTER,
            actionType = ActionType.NOTIFY_AND_OFFER,
            actionTitle = "哨兵开着", actionBody = "",
            actionSeverity = AlertSeverity.INFO,
            primaryActionLabel = "知道了",
            selectedCapabilityId = "",
            paramOverrides = emptyParams(),
        )
        val action = (spec["actions_above"] as JsonArray)[0] as JsonObject
        assertEquals(
            "automation.dismiss",
            (action["capability"] as JsonPrimitive).content,
        )
        // params not emitted when empty.
        assertNull(action["params"])
    }

    @Test
    fun `decodeInitial round-trips state_duration camp rule`() {
        val spec = buildSpec(
            triggerType = TriggerType.STATE_DURATION,
            entity = VehicleEntity.CLIMATE_KEEPER,
            compareInt = 3, compareBool = true, toString_ = "",
            numericOp = NumericOp.LT, numericValue = 0,
            forMinutes = 45, cronHour = 0, cronMinute = 0,
            cronWeekdays = setOf(),
            geofenceLat = null, geofenceLng = null,
            geofenceRadiusM = 0, geofenceEvent = GeofenceEvent.ENTER,
            actionType = ActionType.NOTIFY,
            actionTitle = "露营 45 分钟", actionBody = "提醒一下",
            actionSeverity = AlertSeverity.CRITICAL,
            primaryActionLabel = "", selectedCapabilityId = "",
            paramOverrides = emptyParams(),
        )
        val seeded = decodeInitial(spec)
        assertEquals(TriggerType.STATE_DURATION, seeded.triggerType)
        assertEquals(VehicleEntity.CLIMATE_KEEPER, seeded.entity)
        assertEquals(3, seeded.compareInt)
        assertEquals(45, seeded.forMinutes)
        assertEquals("露营 45 分钟", seeded.actionTitle)
        assertEquals(AlertSeverity.CRITICAL, seeded.actionSeverity)
        assertEquals(ActionType.NOTIFY, seeded.actionType)
    }

    @Test
    fun `decodeInitial round-trips geofence exit rule`() {
        val spec = buildSpec(
            triggerType = TriggerType.GEOFENCE,
            entity = VehicleEntity.CLIMATE_KEEPER,
            compareInt = 0, compareBool = true, toString_ = "",
            numericOp = NumericOp.LT, numericValue = 0,
            forMinutes = 0, cronHour = 0, cronMinute = 0,
            cronWeekdays = setOf(),
            geofenceLat = 31.2304, geofenceLng = 121.4737,
            geofenceRadiusM = 500, geofenceEvent = GeofenceEvent.EXIT,
            actionType = ActionType.NOTIFY,
            actionTitle = "离开了", actionBody = "",
            actionSeverity = AlertSeverity.INFO,
            primaryActionLabel = "", selectedCapabilityId = "",
            paramOverrides = emptyParams(),
        )
        val seeded = decodeInitial(spec)
        assertEquals(TriggerType.GEOFENCE, seeded.triggerType)
        assertEquals(500, seeded.geofenceRadiusM)
        assertEquals(GeofenceEvent.EXIT, seeded.geofenceEvent)
        assertEquals(31.2304, seeded.geofenceLat!!, 1e-6)
        assertEquals(121.4737, seeded.geofenceLng!!, 1e-6)
    }

    @Test
    fun `cronExpression collapses all-days to wildcard`() {
        assertEquals("0 8 * * *", cronExpression(8, 0, (1..7).toSet()))
        // Empty also falls back to wildcard.
        assertEquals("0 8 * * *", cronExpression(8, 0, emptySet()))
        // Sorted.
        assertEquals("0 8 * * 1,3,5", cronExpression(8, 0, setOf(5, 1, 3)))
    }

    @Test
    fun `inferKind maps each entity correctly`() {
        assertEquals(
            "campMode",
            inferKind(TriggerType.STATE_DURATION, VehicleEntity.CLIMATE_KEEPER),
        )
        assertEquals(
            "sentryMode",
            inferKind(TriggerType.STATE_DURATION, VehicleEntity.SENTRY),
        )
        assertEquals(
            "leftUnlocked",
            inferKind(TriggerType.STATE_DURATION, VehicleEntity.PARKED_UNLOCKED),
        )
        assertEquals(
            "lowBattery",
            inferKind(TriggerType.STATE_DURATION, VehicleEntity.BATTERY_LEVEL),
        )
        assertEquals(
            "geofenceEnter",
            inferKind(TriggerType.GEOFENCE, VehicleEntity.CLIMATE_KEEPER, GeofenceEvent.ENTER),
        )
        assertEquals(
            "geofenceExit",
            inferKind(TriggerType.GEOFENCE, VehicleEntity.CLIMATE_KEEPER, GeofenceEvent.EXIT),
        )
        assertEquals(
            "weekdayPreheat",
            inferKind(TriggerType.CRON, VehicleEntity.CLIMATE_KEEPER),
        )
    }

    @Test
    fun `firstActionCapability hides automation_dismiss as empty`() {
        val spec = buildJsonObject {
            put(
                "actions_above",
                kotlinx.serialization.json.buildJsonArray {
                    add(buildJsonObject {
                        put("type", JsonPrimitive("notify_and_offer"))
                        put("capability", JsonPrimitive("automation.dismiss"))
                    })
                },
            )
        }
        // automation.dismiss is the "no real capability" sentinel — the
        // picker should treat that as 仅关闭提醒, not show "automation
        // .dismiss" literally.
        assertEquals("", firstActionCapability(spec))
        // But real capabilities pass through.
        val spec2 = buildJsonObject {
            put(
                "actions_above",
                kotlinx.serialization.json.buildJsonArray {
                    add(buildJsonObject {
                        put("type", JsonPrimitive("notify_and_offer"))
                        put("capability", JsonPrimitive("tesla.charging.set_limit"))
                    })
                },
            )
        }
        assertEquals("tesla.charging.set_limit", firstActionCapability(spec2))
    }
}
