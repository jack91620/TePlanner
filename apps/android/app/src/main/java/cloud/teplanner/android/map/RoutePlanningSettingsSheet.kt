package cloud.teplanner.android.map

import android.content.Context
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Remove

/**
 * 路线规划相关偏好的就地编辑入口。Mirror of iOS
 * RoutePlanningSettingsSheet — 目标到达 SOC / 最低充电 SOC /
 * 超充偏好 / 距离单位。本地存储 (SharedPreferences) 持久化；
 * iOS 上对应 UserDefaultsSettingsStore，未来 A.5 接 user_settings
 * 后端时两端一并迁。
 */

enum class DistanceUnit { KM, MI }

class RoutePlanningSettingsStore(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences(
        "route_planning_settings", Context.MODE_PRIVATE
    )

    var targetArrivalSoc: Int
        get() = prefs.getInt(KEY_TARGET_ARRIVAL_SOC, 20)
        set(v) = prefs.edit().putInt(KEY_TARGET_ARRIVAL_SOC, v).apply()

    var minChargingSoc: Int
        get() = prefs.getInt(KEY_MIN_CHARGING_SOC, 10)
        set(v) = prefs.edit().putInt(KEY_MIN_CHARGING_SOC, v).apply()

    var preferSupercharger: Boolean
        get() = prefs.getBoolean(KEY_PREFER_SUPERCHARGER, true)
        set(v) = prefs.edit().putBoolean(KEY_PREFER_SUPERCHARGER, v).apply()

    var distanceUnit: DistanceUnit
        get() = DistanceUnit.valueOf(
            prefs.getString(KEY_DISTANCE_UNIT, DistanceUnit.KM.name) ?: DistanceUnit.KM.name
        )
        set(v) = prefs.edit().putString(KEY_DISTANCE_UNIT, v.name).apply()

    companion object {
        private const val KEY_TARGET_ARRIVAL_SOC = "target_arrival_soc"
        private const val KEY_MIN_CHARGING_SOC = "min_charging_soc"
        private const val KEY_PREFER_SUPERCHARGER = "prefer_supercharger"
        private const val KEY_DISTANCE_UNIT = "distance_unit"
    }
}


@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RoutePlanningSettingsSheet(
    onDismiss: () -> Unit,
) {
    val context = LocalContext.current
    val store = remember { RoutePlanningSettingsStore(context) }

    var targetArrivalSoc by remember { mutableIntStateOf(store.targetArrivalSoc) }
    var minChargingSoc by remember { mutableIntStateOf(store.minChargingSoc) }
    var preferSupercharger by remember { mutableStateOf(store.preferSupercharger) }
    var distanceUnit by remember { mutableStateOf(store.distanceUnit) }

    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        modifier = Modifier.testTag("route_settings_sheet"),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Text("路线规划设置", style = MaterialTheme.typography.titleLarge)

            SectionHeader("电量目标")
            SocStepper(
                label = "目标到达电量",
                value = targetArrivalSoc,
                min = 5, max = 50, step = 5,
                onChange = { targetArrivalSoc = it },
                testTag = "stepper_target_soc",
            )
            SocStepper(
                label = "最低充电电量",
                value = minChargingSoc,
                min = 5, max = 30, step = 5,
                onChange = { minChargingSoc = it },
                testTag = "stepper_min_soc",
            )

            HorizontalDivider()
            SectionHeader("充电站偏好")
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("优先选择超级充电站", modifier = Modifier.weight(1f))
                Switch(
                    checked = preferSupercharger,
                    onCheckedChange = { preferSupercharger = it },
                    modifier = Modifier.testTag("switch_prefer_supercharger"),
                )
            }

            HorizontalDivider()
            SectionHeader("显示")
            DistanceUnit.entries.forEach { unit ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    RadioButton(
                        selected = distanceUnit == unit,
                        onClick = { distanceUnit = unit },
                        modifier = Modifier.testTag("radio_unit_${unit.name.lowercase()}"),
                    )
                    Text(if (unit == DistanceUnit.KM) "公里 (km)" else "英里 (mi)")
                }
            }

            Spacer(Modifier.height(8.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End,
            ) {
                TextButton(onClick = onDismiss) { Text("取消") }
                Spacer(Modifier.width(8.dp))
                TextButton(
                    onClick = {
                        store.targetArrivalSoc = targetArrivalSoc
                        store.minChargingSoc = minChargingSoc
                        store.preferSupercharger = preferSupercharger
                        store.distanceUnit = distanceUnit
                        onDismiss()
                    },
                    modifier = Modifier.testTag("route_settings_save"),
                ) { Text("保存") }
            }
            Spacer(Modifier.height(8.dp))
        }
    }
}


@Composable
private fun SectionHeader(label: String) {
    Text(
        label,
        style = MaterialTheme.typography.titleSmall,
        color = MaterialTheme.colorScheme.primary,
    )
}


@Composable
private fun SocStepper(
    label: String,
    value: Int,
    min: Int,
    max: Int,
    step: Int,
    onChange: (Int) -> Unit,
    testTag: String,
) {
    Row(
        modifier = Modifier.fillMaxWidth().testTag(testTag),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, modifier = Modifier.weight(1f))
        FilledTonalIconButton(
            onClick = { if (value > min) onChange(value - step) },
            modifier = Modifier.size(36.dp),
            enabled = value > min,
        ) {
            androidx.compose.material3.Icon(Icons.Filled.Remove, contentDescription = "减")
        }
        Box(
            modifier = Modifier.width(64.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text("$value%", style = MaterialTheme.typography.titleMedium)
        }
        FilledTonalIconButton(
            onClick = { if (value < max) onChange(value + step) },
            modifier = Modifier.size(36.dp),
            enabled = value < max,
        ) {
            androidx.compose.material3.Icon(Icons.Filled.Add, contentDescription = "加")
        }
    }
}
