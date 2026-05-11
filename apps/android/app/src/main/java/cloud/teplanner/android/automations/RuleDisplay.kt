package cloud.teplanner.android.automations

import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

/**
 * Port of iOS RuleDisplay (capability name + category subset).
 * Source-of-truth for the user-facing string of each Tesla capability
 * id and the section it belongs to in the picker.
 *
 * Sync with iOS `Sources/TePlannerKit/Automations/Interpreters/RuleDisplay.swift`
 * + the backend `services/capabilities/tesla/` registry whenever a
 * new capability is added.
 */
object RuleDisplay {

    fun capabilityName(id: String): String = when (id) {
        // Climate
        "tesla.climate.set_keeper_mode" -> "调整空调保持模式"
        "tesla.climate.preheat" -> "启动预热"
        "tesla.climate.stop" -> "关闭空调"
        "tesla.climate.set_temps" -> "设置温度"
        "tesla.climate.set_preconditioning_max" -> "切换最大预热"
        "tesla.climate.set_cabin_overheat" -> "切换座舱过热保护"
        // Charging
        "tesla.charging.set_limit" -> "调整充电限额"
        "tesla.charging.start" -> "开始充电"
        "tesla.charging.stop" -> "停止充电"
        "tesla.charging.port_open" -> "打开充电口"
        "tesla.charging.port_close" -> "关闭充电口"
        "tesla.charging.set_amps" -> "调整充电电流"
        // Security
        "tesla.security.set_sentry" -> "切换哨兵模式"
        "tesla.security.door_lock" -> "锁车"
        "tesla.security.door_unlock" -> "解锁"
        "tesla.security.actuate_frunk" -> "打开前备箱"
        "tesla.security.actuate_trunk" -> "操作后备箱"
        // Closures
        "tesla.closures.window_vent" -> "通风开窗"
        "tesla.closures.window_close" -> "关闭车窗"
        "tesla.closures.sun_roof_vent" -> "通风开天窗"
        "tesla.closures.sun_roof_close" -> "关闭天窗"
        // Comfort
        "tesla.comfort.set_seat_heater" -> "设置座椅加热"
        "tesla.comfort.set_steering_wheel_heater" -> "切换方向盘加热"
        // Media
        "tesla.media.toggle_playback" -> "切换车机播放"
        "tesla.media.set_volume" -> "设置车机音量"
        "tesla.media.next_track" -> "下一首"
        "tesla.media.prev_track" -> "上一首"
        // Navigation
        "tesla.navigation.send" -> "发送导航目的地"
        "tesla.navigation.send_address" -> "发送地址到车"
        // Attention
        "tesla.attention.flash_lights" -> "闪灯"
        "tesla.attention.honk_horn" -> "鸣笛"
        "tesla.attention.trigger_homelink" -> "触发 HomeLink"
        "automation.dismiss", "" -> "仅关闭提醒"
        else -> id
    }

    enum class CapabilityCategory(val label: String) {
        CLIMATE("空调与温度"),
        CHARGING("充电"),
        SECURITY("安全与门窗"),
        COMFORT("座椅与方向盘"),
        MEDIA("车机媒体"),
        NAVIGATION("导航"),
        ATTENTION("提示与车辆控制"),
        OTHER("其他"),
    }

    fun capabilityCategory(id: String): CapabilityCategory = when {
        id.startsWith("tesla.climate.") -> CapabilityCategory.CLIMATE
        id.startsWith("tesla.charging.") -> CapabilityCategory.CHARGING
        id.startsWith("tesla.security.") || id.startsWith("tesla.closures.") ->
            CapabilityCategory.SECURITY
        id.startsWith("tesla.comfort.") -> CapabilityCategory.COMFORT
        id.startsWith("tesla.media.") -> CapabilityCategory.MEDIA
        id.startsWith("tesla.navigation.") -> CapabilityCategory.NAVIGATION
        id.startsWith("tesla.attention.") -> CapabilityCategory.ATTENTION
        else -> CapabilityCategory.OTHER
    }
}


/**
 * Static lookup tables — direct port of iOS CapabilityDefaults.
 * When a new capability is added to the backend registry, add a row
 * here too so the picker auto-populates sane defaults + chooses a
 * short button label.
 */
object CapabilityDefaults {

    /** Default `params` dict that auto-seeds when the user picks a
     *  capability for notify_and_offer. */
    val params: Map<String, JsonObject> = mapOf(
        "tesla.climate.set_keeper_mode" to JsonObject(mapOf("mode" to JsonPrimitive(0))),
        "tesla.climate.set_temps" to JsonObject(mapOf(
            "driver_temp" to JsonPrimitive(22.0),
            "passenger_temp" to JsonPrimitive(22.0),
        )),
        "tesla.climate.set_preconditioning_max" to JsonObject(mapOf("on" to JsonPrimitive(true))),
        "tesla.climate.set_cabin_overheat" to JsonObject(mapOf("mode" to JsonPrimitive(2))),
        "tesla.charging.set_limit" to JsonObject(mapOf("percent" to JsonPrimitive(80))),
        "tesla.charging.set_amps" to JsonObject(mapOf("amps" to JsonPrimitive(16))),
        "tesla.security.set_sentry" to JsonObject(mapOf("on" to JsonPrimitive(false))),
        "tesla.comfort.set_seat_heater" to JsonObject(mapOf(
            "seat" to JsonPrimitive(0), "level" to JsonPrimitive(2),
        )),
        "tesla.comfort.set_steering_wheel_heater" to JsonObject(mapOf("on" to JsonPrimitive(true))),
        "tesla.media.set_volume" to JsonObject(mapOf("volume" to JsonPrimitive(5.0))),
    )

    /** Short verb (≤4 Chinese chars) for the inline notification
     *  action button — distinct from `RuleDisplay.capabilityName`
     *  which is descriptive. */
    val buttonLabel: Map<String, String> = mapOf(
        "tesla.climate.set_keeper_mode" to "关闭模式",
        "tesla.climate.preheat" to "预热",
        "tesla.climate.stop" to "关空调",
        "tesla.climate.set_temps" to "调温",
        "tesla.climate.set_preconditioning_max" to "最大预热",
        "tesla.climate.set_cabin_overheat" to "切换",
        "tesla.charging.set_limit" to "调限额",
        "tesla.charging.start" to "开始充电",
        "tesla.charging.stop" to "停止充电",
        "tesla.charging.port_open" to "开充电口",
        "tesla.charging.port_close" to "关充电口",
        "tesla.charging.set_amps" to "调电流",
        "tesla.security.set_sentry" to "切换哨兵",
        "tesla.security.door_lock" to "锁车",
        "tesla.security.door_unlock" to "解锁",
        "tesla.security.actuate_frunk" to "前备箱",
        "tesla.security.actuate_trunk" to "后备箱",
        "tesla.closures.window_vent" to "通风",
        "tesla.closures.window_close" to "关车窗",
        "tesla.closures.sun_roof_vent" to "天窗通风",
        "tesla.closures.sun_roof_close" to "关天窗",
        "tesla.comfort.set_seat_heater" to "座椅加热",
        "tesla.comfort.set_steering_wheel_heater" to "方向盘加热",
        "tesla.media.toggle_playback" to "播/暂停",
        "tesla.media.set_volume" to "调音量",
        "tesla.media.next_track" to "下一首",
        "tesla.media.prev_track" to "上一首",
        "tesla.navigation.send" to "导航",
        "tesla.navigation.send_address" to "导航",
        "tesla.attention.flash_lights" to "闪灯",
        "tesla.attention.honk_horn" to "鸣笛",
        "tesla.attention.trigger_homelink" to "HomeLink",
    )
}
