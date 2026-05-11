package cloud.teplanner.android.automations

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.intOrNull

/**
 * Mirror of iOS CapabilityParamEditor. For a given capability id,
 * render the right inline form rows so the user can override the
 * defaults from [CapabilityDefaults.params].
 *
 * Capabilities not enumerated here render "无需参数" — same as iOS
 * `default:` branch.
 */
@Composable
fun CapabilityParamEditor(
    capabilityId: String,
    params: JsonObject,
    onChange: (JsonObject) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        when (capabilityId) {
            "tesla.climate.set_keeper_mode" ->
                IntPicker(
                    label = "模式", key = "mode", default = 0,
                    options = listOf(0 to "关闭", 1 to "保持", 2 to "宠物模式", 3 to "露营模式"),
                    params = params, onChange = onChange,
                )
            "tesla.security.set_sentry" ->
                BoolSwitch("开启哨兵", "on", false, params, onChange)
            "tesla.charging.set_limit" ->
                IntStepper(
                    label = "限额", key = "percent", default = 80,
                    min = 50, max = 100, step = 5, suffix = "%",
                    params = params, onChange = onChange,
                )
            "tesla.charging.set_amps" ->
                IntStepper(
                    label = "电流", key = "amps", default = 16,
                    min = 5, max = 48, step = 1, suffix = " A",
                    params = params, onChange = onChange,
                )
            "tesla.climate.set_temps" -> {
                DoubleStepper(
                    label = "主驾", key = "driver_temp", default = 22.0,
                    min = 15.0, max = 28.0, step = 0.5, suffix = " °C",
                    params = params, onChange = onChange,
                )
                DoubleStepper(
                    label = "副驾", key = "passenger_temp", default = 22.0,
                    min = 15.0, max = 28.0, step = 0.5, suffix = " °C",
                    params = params, onChange = onChange,
                )
            }
            "tesla.climate.set_preconditioning_max" ->
                BoolSwitch("开启最大预热", "on", true, params, onChange)
            "tesla.climate.set_cabin_overheat" ->
                IntPicker(
                    label = "模式", key = "mode", default = 2,
                    options = listOf(0 to "关闭", 1 to "空调", 2 to "仅风扇"),
                    params = params, onChange = onChange,
                )
            "tesla.comfort.set_seat_heater" -> {
                IntPicker(
                    label = "座位", key = "seat", default = 0,
                    options = listOf(
                        0 to "主驾", 1 to "副驾",
                        2 to "后排左", 4 to "后排中", 5 to "后排右",
                    ),
                    params = params, onChange = onChange,
                )
                IntPicker(
                    label = "档位", key = "level", default = 2,
                    options = listOf(0 to "关闭", 1 to "低", 2 to "中", 3 to "高"),
                    params = params, onChange = onChange,
                )
            }
            "tesla.comfort.set_steering_wheel_heater" ->
                BoolSwitch("开启方向盘加热", "on", true, params, onChange)
            "tesla.media.set_volume" ->
                DoubleStepper(
                    label = "音量", key = "volume", default = 5.0,
                    min = 0.0, max = 11.0, step = 0.5, suffix = "",
                    params = params, onChange = onChange,
                )
            else -> Text(
                "无需参数",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}


@Composable
private fun IntPicker(
    label: String,
    key: String,
    default: Int,
    options: List<Pair<Int, String>>,
    params: JsonObject,
    onChange: (JsonObject) -> Unit,
) {
    val current = (params[key] as? JsonPrimitive)?.intOrNull ?: default
    Column {
        Text(label, style = MaterialTheme.typography.bodyMedium)
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            options.forEach { (v, lbl) ->
                FilterChip(
                    selected = current == v,
                    onClick = { onChange(setInt(params, key, v)) },
                    label = { Text(lbl) },
                )
            }
        }
    }
}


@Composable
private fun BoolSwitch(
    label: String,
    key: String,
    default: Boolean,
    params: JsonObject,
    onChange: (JsonObject) -> Unit,
) {
    val current = (params[key] as? JsonPrimitive)?.booleanOrNull ?: default
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, modifier = Modifier.weight(1f))
        Switch(
            checked = current,
            onCheckedChange = { onChange(setBool(params, key, it)) },
        )
    }
}


@Composable
private fun IntStepper(
    label: String, key: String, default: Int,
    min: Int, max: Int, step: Int, suffix: String,
    params: JsonObject, onChange: (JsonObject) -> Unit,
) {
    val value = (params[key] as? JsonPrimitive)?.intOrNull ?: default
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, modifier = Modifier.weight(1f))
        FilledTonalIconButton(
            onClick = { if (value > min) onChange(setInt(params, key, value - step)) },
            modifier = Modifier.size(32.dp),
            enabled = value > min,
        ) { Icon(Icons.Filled.Remove, "减") }
        Box(Modifier.width(72.dp), contentAlignment = Alignment.Center) {
            Text(
                "$value$suffix",
                style = MaterialTheme.typography.titleSmall,
            )
        }
        FilledTonalIconButton(
            onClick = { if (value < max) onChange(setInt(params, key, value + step)) },
            modifier = Modifier.size(32.dp),
            enabled = value < max,
        ) { Icon(Icons.Filled.Add, "加") }
    }
}


@Composable
private fun DoubleStepper(
    label: String, key: String, default: Double,
    min: Double, max: Double, step: Double, suffix: String,
    params: JsonObject, onChange: (JsonObject) -> Unit,
) {
    val value = (params[key] as? JsonPrimitive)?.doubleOrNull ?: default
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, modifier = Modifier.weight(1f))
        FilledTonalIconButton(
            onClick = { if (value > min) onChange(setDouble(params, key, value - step)) },
            modifier = Modifier.size(32.dp),
            enabled = value > min,
        ) { Icon(Icons.Filled.Remove, "减") }
        Box(Modifier.width(72.dp), contentAlignment = Alignment.Center) {
            Text(
                "%.1f%s".format(value, suffix),
                style = MaterialTheme.typography.titleSmall,
            )
        }
        FilledTonalIconButton(
            onClick = { if (value < max) onChange(setDouble(params, key, value + step)) },
            modifier = Modifier.size(32.dp),
            enabled = value < max,
        ) { Icon(Icons.Filled.Add, "加") }
    }
}


private fun setInt(obj: JsonObject, key: String, v: Int): JsonObject =
    buildJsonObject {
        obj.forEach { (k, value) -> if (k != key) put(k, value) }
        put(key, JsonPrimitive(v))
    }

private fun setBool(obj: JsonObject, key: String, v: Boolean): JsonObject =
    buildJsonObject {
        obj.forEach { (k, value) -> if (k != key) put(k, value) }
        put(key, JsonPrimitive(v))
    }

private fun setDouble(obj: JsonObject, key: String, v: Double): JsonObject =
    buildJsonObject {
        obj.forEach { (k, value) -> if (k != key) put(k, value) }
        put(key, JsonPrimitive(v))
    }
