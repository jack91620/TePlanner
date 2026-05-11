package cloud.teplanner.android.automations

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject

/**
 * Port of iOS RuleBuilderView (≈70% surface). Custom-rule authoring
 * for the three trigger types that cover the existing 8 presets:
 *   - 持续状态 (state_duration): camp/sentry/cabin/parked/charging/battery
 *   - 状态变化 (state_transition): chargeComplete
 *   - 定时 (cron): weekday preheat
 *
 * Skipped from the iOS surface (follow-up):
 *   - geofence trigger (requires GeofenceMapPicker)
 *   - notify_and_offer action with capability picker (30+ caps)
 *   - capability param overrides
 *
 * Backend POST /automations spec format follows iOS buildSpec()
 * byte-for-byte — the interpreter (server-side) accepts both.
 *
 * Reachable from AutomationsListScreen "+" toolbar button (creates
 * a fresh rule) and from RuleDetailScreen "编辑" (loads `initial`).
 */

enum class TriggerType(val raw: String, val label: String) {
    STATE_DURATION("state_duration", "持续状态"),
    STATE_TRANSITION("state_transition", "状态变化"),
    CRON("cron", "定时"),
    GEOFENCE("geofence", "进出区域"),
}

enum class GeofenceEvent(val raw: String, val label: String) {
    ENTER("enter", "进入"), EXIT("exit", "离开"),
}

enum class VehicleEntity(
    val raw: String,
    val label: String,
    val valueKind: ValueKind,
) {
    CLIMATE_KEEPER("vehicle.climate.keeper_mode", "露营/宠物/保持模式", ValueKind.KEEPER),
    SENTRY("vehicle.sentry_mode_on", "哨兵模式", ValueKind.BOOL),
    CABIN_OVERHEAT("vehicle.cabin_overheat_protection_on", "座舱过热保护", ValueKind.BOOL),
    CHARGING_STATE("vehicle.charging.state", "充电状态", ValueKind.STRING),
    PARKED_UNLOCKED("vehicle.parked_unlocked", "停车后未锁车", ValueKind.BOOL),
    PARKED_DOOR_OPEN("vehicle.parked_with_door_open", "停车后车门开", ValueKind.BOOL),
    PARKED_WINDOW_OPEN("vehicle.parked_with_window_open", "停车后车窗开", ValueKind.BOOL),
    PARKED_FRUNK_OPEN("vehicle.parked_with_frunk_open", "停车后前备箱开", ValueKind.BOOL),
    PARKED_TRUNK_OPEN("vehicle.parked_with_trunk_open", "停车后后备箱开", ValueKind.BOOL),
    BATTERY_LEVEL("vehicle.battery_level", "电量百分比", ValueKind.NUMERIC);

    enum class ValueKind { KEEPER, BOOL, STRING, NUMERIC }
}

enum class NumericOp(val raw: String, val label: String) {
    LT("<", "低于"), LTE("<=", "不超过"), EQ("==", "等于"),
    GTE(">=", "不低于"), GT(">", "高于"),
}

enum class KeeperModeChoice(val value: Int, val label: String) {
    OFF(0, "关闭"), KEEP(1, "保持"), DOG(2, "宠物模式"), CAMP(3, "露营模式"),
}

enum class AlertSeverity(val raw: String, val label: String) {
    INFO("info", "信息"), CRITICAL("critical", "严重"),
}


@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RuleBuilderScreen(
    initialRuleId: String?,
    onBack: () -> Unit,
    onSaved: () -> Unit,
    vm: AutomationsViewModel = hiltViewModel(),
) {
    val initial = initialRuleId?.let { vm.rule(it) }
    val state by vm.state.collectAsState()
    val scope = rememberCoroutineScope()
    val isEditing = initial != null

    // ---- Meta ----
    var name by remember { mutableStateOf(initial?.name ?: "") }
    var enabled by remember { mutableStateOf(initial?.enabled ?: true) }

    // ---- Trigger ----
    val seeded = remember(initial) { decodeInitial(initial?.spec) }
    var triggerType by remember { mutableStateOf(seeded.triggerType) }
    var entity by remember { mutableStateOf(seeded.entity) }
    var compareInt by remember { mutableIntStateOf(seeded.compareInt) }
    var compareBool by remember { mutableStateOf(seeded.compareBool) }
    var toString by remember { mutableStateOf(seeded.toString_) }
    var numericOp by remember { mutableStateOf(seeded.numericOp) }
    var numericValue by remember { mutableIntStateOf(seeded.numericValue) }
    var forMinutes by remember { mutableIntStateOf(seeded.forMinutes) }
    var cronHour by remember { mutableIntStateOf(seeded.cronHour) }
    var cronMinute by remember { mutableIntStateOf(seeded.cronMinute) }
    var cronWeekdays by remember { mutableStateOf(seeded.cronWeekdays) }

    var geofenceLat by remember { mutableStateOf(seeded.geofenceLat) }
    var geofenceLng by remember { mutableStateOf(seeded.geofenceLng) }
    var geofenceRadiusM by remember { mutableIntStateOf(seeded.geofenceRadiusM) }
    var geofenceEvent by remember { mutableStateOf(seeded.geofenceEvent) }
    var showingGeofencePicker by remember { mutableStateOf(false) }

    // ---- Action ----
    var actionTitle by remember { mutableStateOf(seeded.actionTitle) }
    var actionBody by remember { mutableStateOf(seeded.actionBody) }
    var actionSeverity by remember { mutableStateOf(seeded.actionSeverity) }

    var saving by remember { mutableStateOf(false) }
    var saveError by remember { mutableStateOf<String?>(null) }

    val geofenceReady = triggerType != TriggerType.GEOFENCE ||
        (geofenceLat != null && geofenceLng != null)
    val canSave = name.isNotBlank() && actionTitle.isNotBlank() && geofenceReady && !saving

    if (showingGeofencePicker) {
        GeofencePickerScreen(
            initialLat = geofenceLat,
            initialLng = geofenceLng,
            initialRadiusM = geofenceRadiusM,
            onCancel = { showingGeofencePicker = false },
            onConfirm = { lat, lng, r ->
                geofenceLat = lat
                geofenceLng = lng
                geofenceRadiusM = r
                showingGeofencePicker = false
            },
        )
        return
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (isEditing) "编辑自动化" else "新建自动化") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "返回")
                    }
                },
                actions = {
                    TextButton(
                        onClick = {
                            scope.launch {
                                saving = true
                                saveError = null
                                val spec = buildSpec(
                                    triggerType = triggerType,
                                    entity = entity,
                                    compareInt = compareInt,
                                    compareBool = compareBool,
                                    toString_ = toString,
                                    numericOp = numericOp,
                                    numericValue = numericValue,
                                    forMinutes = forMinutes,
                                    cronHour = cronHour,
                                    cronMinute = cronMinute,
                                    cronWeekdays = cronWeekdays,
                                    geofenceLat = geofenceLat,
                                    geofenceLng = geofenceLng,
                                    geofenceRadiusM = geofenceRadiusM,
                                    geofenceEvent = geofenceEvent,
                                    actionTitle = actionTitle,
                                    actionBody = actionBody,
                                    actionSeverity = actionSeverity,
                                )
                                val ok = if (isEditing && initial != null) {
                                    vm.updateSpec(initial.id, name, enabled, spec)
                                } else {
                                    vm.create(name, enabled, spec) != null
                                }
                                saving = false
                                if (ok) onSaved() else saveError = state.error ?: "保存失败"
                            }
                        },
                        enabled = canSave,
                        modifier = Modifier.testTag("rule_save_button"),
                    ) { Text(if (saving) "保存中…" else "保存") }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 12.dp)
                .testTag("rule_builder_view"),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            // META
            Section("基本信息") {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("名称") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth().testTag("rule_name_field"),
                )
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("启用", modifier = Modifier.weight(1f))
                    Switch(
                        checked = enabled,
                        onCheckedChange = { enabled = it },
                        modifier = Modifier.testTag("rule_enabled_switch"),
                    )
                }
            }

            // TRIGGER TYPE
            Section("触发类型") {
                TriggerType.entries.forEach { t ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("trigger_type_${t.raw}"),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        RadioButton(
                            selected = triggerType == t,
                            onClick = { triggerType = t },
                        )
                        Text(t.label)
                    }
                }
            }

            // TRIGGER DETAILS — per type
            when (triggerType) {
                TriggerType.STATE_DURATION -> Section("观察什么") {
                    EntityPicker(selected = entity, onSelect = { entity = it })
                    Spacer(Modifier.height(8.dp))
                    valueEditor(
                        entity = entity,
                        compareInt = compareInt, onCompareInt = { compareInt = it },
                        compareBool = compareBool, onCompareBool = { compareBool = it },
                        toString_ = toString, onToString = { toString = it },
                        numericOp = numericOp, onNumericOp = { numericOp = it },
                        numericValue = numericValue, onNumericValue = { numericValue = it },
                    )
                    Spacer(Modifier.height(8.dp))
                    Stepper(
                        label = "持续时间",
                        value = forMinutes,
                        min = 1, max = 720, step = 5,
                        suffix = formatMinutes(forMinutes),
                        onChange = { forMinutes = it },
                        testTag = "stepper_for_minutes",
                    )
                }

                TriggerType.STATE_TRANSITION -> Section("观察什么") {
                    EntityPicker(selected = entity, onSelect = { entity = it })
                    Spacer(Modifier.height(8.dp))
                    OutlinedTextField(
                        value = toString,
                        onValueChange = { toString = it },
                        label = { Text("目标值") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth().testTag("transition_to_field"),
                    )
                    Text(
                        "首次进入此状态时触发，例如「充电状态变为 Complete」。",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }

                TriggerType.GEOFENCE -> Section("区域") {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("事件类型", modifier = Modifier.weight(1f))
                        GeofenceEvent.entries.forEach { e ->
                            FilterChip(
                                selected = geofenceEvent == e,
                                onClick = { geofenceEvent = e },
                                label = { Text(e.label) },
                                modifier = Modifier
                                    .padding(start = 4.dp)
                                    .testTag("geofence_event_${e.raw}"),
                            )
                        }
                    }
                    Spacer(Modifier.height(8.dp))
                    val coordLabel = if (geofenceLat != null && geofenceLng != null) {
                        "%.5f, %.5f · 半径 ${geofenceRadiusM} m".format(geofenceLat, geofenceLng)
                    } else "未选择 — 点击选择地点"
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("geofence_pick_card"),
                        onClick = { showingGeofencePicker = true },
                    ) {
                        Row(
                            modifier = Modifier.padding(14.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Icon(
                                Icons.Filled.LocationOn,
                                null,
                                tint = MaterialTheme.colorScheme.primary,
                            )
                            Text(
                                coordLabel,
                                modifier = Modifier.padding(start = 8.dp).weight(1f),
                                style = MaterialTheme.typography.bodyMedium,
                            )
                        }
                    }
                }

                TriggerType.CRON -> Section("什么时候") {
                    Stepper(
                        label = "小时",
                        value = cronHour, min = 0, max = 23, step = 1,
                        suffix = "$cronHour 时",
                        onChange = { cronHour = it },
                        testTag = "stepper_cron_hour",
                    )
                    Stepper(
                        label = "分钟",
                        value = cronMinute, min = 0, max = 59, step = 5,
                        suffix = "$cronMinute 分",
                        onChange = { cronMinute = it },
                        testTag = "stepper_cron_minute",
                    )
                    Spacer(Modifier.height(8.dp))
                    Text("星期", style = MaterialTheme.typography.titleSmall)
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        listOf(1 to "一", 2 to "二", 3 to "三", 4 to "四",
                               5 to "五", 6 to "六", 7 to "日").forEach { (idx, label) ->
                            FilterChip(
                                selected = idx in cronWeekdays,
                                onClick = {
                                    cronWeekdays = if (idx in cronWeekdays) cronWeekdays - idx
                                                    else cronWeekdays + idx
                                },
                                label = { Text(label) },
                                modifier = Modifier.testTag("weekday_$idx"),
                            )
                        }
                    }
                }
            }

            // ACTION
            Section("通知内容") {
                OutlinedTextField(
                    value = actionTitle,
                    onValueChange = { actionTitle = it },
                    label = { Text("通知标题") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth().testTag("action_title_field"),
                )
                OutlinedTextField(
                    value = actionBody,
                    onValueChange = { actionBody = it },
                    label = { Text("通知正文") },
                    modifier = Modifier.fillMaxWidth().testTag("action_body_field"),
                )
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("重要程度", modifier = Modifier.weight(1f))
                    AlertSeverity.entries.forEach { s ->
                        FilterChip(
                            selected = actionSeverity == s,
                            onClick = { actionSeverity = s },
                            label = { Text(s.label) },
                            modifier = Modifier.padding(start = 4.dp).testTag("severity_${s.raw}"),
                        )
                    }
                }
            }

            saveError?.let { msg ->
                Text(msg, color = MaterialTheme.colorScheme.error)
            }
            Spacer(Modifier.height(24.dp))
        }
    }
}


@Composable
private fun Section(title: String, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            title,
            style = MaterialTheme.typography.titleSmall,
            color = MaterialTheme.colorScheme.primary,
        )
        content()
        HorizontalDivider()
    }
}


@Composable
private fun EntityPicker(
    selected: VehicleEntity,
    onSelect: (VehicleEntity) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    Column(modifier = Modifier.fillMaxWidth().testTag("entity_picker")) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { expanded = true }
                .padding(vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("实体", modifier = Modifier.weight(1f))
            Text(
                selected.label,
                color = MaterialTheme.colorScheme.primary,
            )
        }
        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
        ) {
            VehicleEntity.entries.forEach { ent ->
                DropdownMenuItem(
                    text = { Text(ent.label) },
                    onClick = { onSelect(ent); expanded = false },
                )
            }
        }
    }
}


@Composable
private fun valueEditor(
    entity: VehicleEntity,
    compareInt: Int, onCompareInt: (Int) -> Unit,
    compareBool: Boolean, onCompareBool: (Boolean) -> Unit,
    toString_: String, onToString: (String) -> Unit,
    numericOp: NumericOp, onNumericOp: (NumericOp) -> Unit,
    numericValue: Int, onNumericValue: (Int) -> Unit,
) {
    when (entity.valueKind) {
        VehicleEntity.ValueKind.KEEPER -> {
            Text("模式等于", style = MaterialTheme.typography.bodyMedium)
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                KeeperModeChoice.entries.forEach { k ->
                    FilterChip(
                        selected = compareInt == k.value,
                        onClick = { onCompareInt(k.value) },
                        label = { Text(k.label) },
                        modifier = Modifier.testTag("keeper_${k.value}"),
                    )
                }
            }
        }
        VehicleEntity.ValueKind.BOOL -> {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("当条件为", modifier = Modifier.weight(1f))
                FilterChip(
                    selected = compareBool,
                    onClick = { onCompareBool(true) },
                    label = { Text("是") },
                )
                Spacer(Modifier.width(6.dp))
                FilterChip(
                    selected = !compareBool,
                    onClick = { onCompareBool(false) },
                    label = { Text("否") },
                )
            }
        }
        VehicleEntity.ValueKind.STRING -> {
            OutlinedTextField(
                value = toString_,
                onValueChange = onToString,
                label = { Text("目标值") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
        }
        VehicleEntity.ValueKind.NUMERIC -> {
            Row(verticalAlignment = Alignment.CenterVertically) {
                NumericOp.entries.forEach { op ->
                    FilterChip(
                        selected = numericOp == op,
                        onClick = { onNumericOp(op) },
                        label = { Text(op.label) },
                        modifier = Modifier.padding(end = 4.dp),
                    )
                }
            }
            Spacer(Modifier.height(4.dp))
            Stepper(
                label = "阈值",
                value = numericValue, min = 0, max = 100, step = 5,
                suffix = "$numericValue%",
                onChange = onNumericValue,
                testTag = "stepper_numeric_value",
            )
        }
    }
}


@Composable
private fun Stepper(
    label: String,
    value: Int,
    min: Int, max: Int, step: Int,
    suffix: String,
    onChange: (Int) -> Unit,
    testTag: String = "",
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .let { if (testTag.isNotEmpty()) it.testTag(testTag) else it },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, modifier = Modifier.weight(1f))
        FilledTonalIconButton(
            onClick = { if (value > min) onChange(value - step) },
            modifier = Modifier.size(36.dp),
            enabled = value > min,
        ) {
            Icon(Icons.Filled.Remove, "减")
        }
        Box(Modifier.width(72.dp), contentAlignment = Alignment.Center) {
            Text(suffix, style = MaterialTheme.typography.titleMedium)
        }
        FilledTonalIconButton(
            onClick = { if (value < max) onChange(value + step) },
            modifier = Modifier.size(36.dp),
            enabled = value < max,
        ) {
            Icon(Icons.Filled.Add, "加")
        }
    }
}


private fun formatMinutes(m: Int): String {
    if (m < 60) return "$m 分钟"
    val h = m / 60
    val r = m % 60
    return if (r == 0) "$h 小时" else "$h 小时 $r 分钟"
}


// ---- spec build / decode ----

/** Snapshot of all builder fields' values seeded from an initial rule.
 *  Defaults match iOS RuleBuilderView @State defaults. */
private data class SeededFields(
    val triggerType: TriggerType,
    val entity: VehicleEntity,
    val compareInt: Int,
    val compareBool: Boolean,
    val toString_: String,
    val numericOp: NumericOp,
    val numericValue: Int,
    val forMinutes: Int,
    val cronHour: Int,
    val cronMinute: Int,
    val cronWeekdays: Set<Int>,
    val geofenceLat: Double?,
    val geofenceLng: Double?,
    val geofenceRadiusM: Int,
    val geofenceEvent: GeofenceEvent,
    val actionTitle: String,
    val actionBody: String,
    val actionSeverity: AlertSeverity,
)

private fun decodeInitial(spec: JsonObject?): SeededFields {
    val defaults = SeededFields(
        triggerType = TriggerType.STATE_DURATION,
        entity = VehicleEntity.CLIMATE_KEEPER,
        compareInt = 3,
        compareBool = true,
        toString_ = "Complete",
        numericOp = NumericOp.LT,
        numericValue = 30,
        forMinutes = 60,
        cronHour = 7,
        cronMinute = 30,
        cronWeekdays = setOf(1, 2, 3, 4, 5),
        geofenceLat = null,
        geofenceLng = null,
        geofenceRadiusM = 200,
        geofenceEvent = GeofenceEvent.ENTER,
        actionTitle = "",
        actionBody = "",
        actionSeverity = AlertSeverity.INFO,
    )
    if (spec == null) return defaults
    val trigger = (spec["trigger"] as? JsonObject) ?: return defaults
    val rawType = (trigger["type"] as? JsonPrimitive)?.content
    val type = TriggerType.entries.firstOrNull { it.raw == rawType } ?: defaults.triggerType
    val entityRaw = (trigger["entity"] as? JsonPrimitive)?.content
    val ent = VehicleEntity.entries.firstOrNull { it.raw == entityRaw } ?: defaults.entity

    val seeded = defaults.copy(triggerType = type, entity = ent)
    return when (type) {
        TriggerType.STATE_DURATION -> seeded.copy(
            compareInt = (trigger["equals"] as? JsonPrimitive)?.content?.toIntOrNull()
                ?: defaults.compareInt,
            compareBool = (trigger["equals"] as? JsonPrimitive)?.content?.toBooleanStrictOrNull()
                ?: defaults.compareBool,
            toString_ = (trigger["equals"] as? JsonPrimitive)?.content ?: defaults.toString_,
            numericOp = NumericOp.entries.firstOrNull {
                it.raw == (trigger["op"] as? JsonPrimitive)?.content
            } ?: defaults.numericOp,
            numericValue = (trigger["value"] as? JsonPrimitive)?.content?.toIntOrNull()
                ?: defaults.numericValue,
            forMinutes = (trigger["for_minutes"] as? JsonPrimitive)?.content?.toIntOrNull()
                ?: defaults.forMinutes,
            actionTitle = firstActionField(spec, "title"),
            actionBody = firstActionField(spec, "body"),
            actionSeverity = firstActionSeverity(spec),
        )
        TriggerType.STATE_TRANSITION -> seeded.copy(
            toString_ = (trigger["to"] as? JsonPrimitive)?.content ?: defaults.toString_,
            actionTitle = firstActionField(spec, "title"),
            actionBody = firstActionField(spec, "body"),
            actionSeverity = firstActionSeverity(spec),
        )
        TriggerType.CRON -> {
            val parts = ((trigger["expr"] as? JsonPrimitive)?.content ?: "30 7 * * 1,2,3,4,5")
                .split(' ')
            val min = parts.getOrNull(0)?.toIntOrNull() ?: defaults.cronMinute
            val hour = parts.getOrNull(1)?.toIntOrNull() ?: defaults.cronHour
            val dows = parts.getOrNull(4)?.let { part ->
                if (part == "*") (1..7).toSet()
                else part.split(',').mapNotNull { it.toIntOrNull() }.toSet()
            } ?: defaults.cronWeekdays
            seeded.copy(
                cronHour = hour, cronMinute = min, cronWeekdays = dows,
                actionTitle = firstActionField(spec, "title"),
                actionBody = firstActionField(spec, "body"),
                actionSeverity = firstActionSeverity(spec),
            )
        }
        TriggerType.GEOFENCE -> {
            val lat = (trigger["lat"] as? JsonPrimitive)?.content?.toDoubleOrNull()
            val lng = (trigger["lng"] as? JsonPrimitive)?.content?.toDoubleOrNull()
            val r = (trigger["radius_m"] as? JsonPrimitive)?.content?.toIntOrNull()
                ?: defaults.geofenceRadiusM
            val evRaw = (trigger["event"] as? JsonPrimitive)?.content
            val ev = GeofenceEvent.entries.firstOrNull { it.raw == evRaw } ?: defaults.geofenceEvent
            seeded.copy(
                geofenceLat = lat, geofenceLng = lng,
                geofenceRadiusM = r, geofenceEvent = ev,
                actionTitle = firstActionField(spec, "title"),
                actionBody = firstActionField(spec, "body"),
                actionSeverity = firstActionSeverity(spec),
            )
        }
    }
}

private fun firstActionField(spec: JsonObject, key: String): String {
    val candidates = listOf("actions", "actions_above", "actions_below")
    for (bucket in candidates) {
        val arr = spec[bucket] as? JsonArray ?: continue
        val first = arr.firstOrNull() as? JsonObject ?: continue
        return (first[key] as? JsonPrimitive)?.content ?: continue
    }
    return ""
}

private fun firstActionSeverity(spec: JsonObject): AlertSeverity {
    val raw = firstActionField(spec, "severity")
    return AlertSeverity.entries.firstOrNull { it.raw == raw } ?: AlertSeverity.INFO
}


private fun inferKind(
    triggerType: TriggerType,
    entity: VehicleEntity,
    geofenceEvent: GeofenceEvent = GeofenceEvent.ENTER,
): String {
    return when (triggerType) {
        TriggerType.CRON -> "weekdayPreheat"
        TriggerType.GEOFENCE ->
            if (geofenceEvent == GeofenceEvent.ENTER) "geofenceEnter" else "geofenceExit"
        else -> when (entity) {
            VehicleEntity.CLIMATE_KEEPER -> "campMode"
            VehicleEntity.SENTRY -> "sentryMode"
            VehicleEntity.CABIN_OVERHEAT -> "cabinOverheat"
            VehicleEntity.CHARGING_STATE -> "chargeComplete"
            VehicleEntity.PARKED_UNLOCKED -> "leftUnlocked"
            VehicleEntity.PARKED_DOOR_OPEN,
            VehicleEntity.PARKED_WINDOW_OPEN,
            VehicleEntity.PARKED_FRUNK_OPEN,
            VehicleEntity.PARKED_TRUNK_OPEN -> "closureLeftOpen"
            VehicleEntity.BATTERY_LEVEL -> "lowBattery"
        }
    }
}


private fun cronExpression(hour: Int, minute: Int, weekdays: Set<Int>): String {
    val wPart = when {
        weekdays.size == 7 || weekdays.isEmpty() -> "*"
        else -> weekdays.sorted().joinToString(",")
    }
    return "$minute $hour * * $wPart"
}


/**
 * Mirror of iOS buildSpec(). Emits the same JSON shape the backend
 * interpreter consumes; only the supported triggers are handled.
 */
private fun buildSpec(
    triggerType: TriggerType,
    entity: VehicleEntity,
    compareInt: Int,
    compareBool: Boolean,
    toString_: String,
    numericOp: NumericOp,
    numericValue: Int,
    forMinutes: Int,
    cronHour: Int,
    cronMinute: Int,
    cronWeekdays: Set<Int>,
    geofenceLat: Double?,
    geofenceLng: Double?,
    geofenceRadiusM: Int,
    geofenceEvent: GeofenceEvent,
    actionTitle: String,
    actionBody: String,
    actionSeverity: AlertSeverity,
): JsonObject {
    val kind = inferKind(triggerType, entity, geofenceEvent)
    val trigger = buildJsonObject {
        put("type", JsonPrimitive(triggerType.raw))
        when (triggerType) {
            TriggerType.STATE_DURATION -> {
                put("entity", JsonPrimitive(entity.raw))
                when (entity.valueKind) {
                    VehicleEntity.ValueKind.KEEPER ->
                        put("equals", JsonPrimitive(compareInt))
                    VehicleEntity.ValueKind.BOOL ->
                        put("equals", JsonPrimitive(compareBool))
                    VehicleEntity.ValueKind.STRING ->
                        put("equals", JsonPrimitive(toString_))
                    VehicleEntity.ValueKind.NUMERIC -> {
                        put("op", JsonPrimitive(numericOp.raw))
                        put("value", JsonPrimitive(numericValue))
                    }
                }
                put("for_minutes", JsonPrimitive(forMinutes))
                put("state_key", JsonPrimitive("user:$kind:startedAt"))
            }
            TriggerType.STATE_TRANSITION -> {
                put("entity", JsonPrimitive(entity.raw))
                put("to", JsonPrimitive(toString_))
                put("first_seen_key", JsonPrimitive("user:$kind:firstSeenAt"))
                put("dismissed_key", JsonPrimitive("user:$kind:dismissedAt"))
                put("reset_when_not_to", JsonPrimitive(true))
            }
            TriggerType.CRON -> {
                put("expr", JsonPrimitive(cronExpression(cronHour, cronMinute, cronWeekdays)))
                put("tz", JsonPrimitive("Asia/Shanghai"))
                put("last_fired_key", JsonPrimitive("user:$kind:lastFiredAt"))
            }
            TriggerType.GEOFENCE -> {
                geofenceLat?.let { put("lat", JsonPrimitive(it)) }
                geofenceLng?.let { put("lng", JsonPrimitive(it)) }
                put("radius_m", JsonPrimitive(geofenceRadiusM))
                put("event", JsonPrimitive(geofenceEvent.raw))
                put("state_key", JsonPrimitive("user:geo:$kind"))
            }
        }
    }

    val action = buildJsonObject {
        put("type", JsonPrimitive("notify"))
        put("title", JsonPrimitive(actionTitle))
        put("body", JsonPrimitive(actionBody))
        put("severity", JsonPrimitive(actionSeverity.raw))
    }

    return buildJsonObject {
        put("kind", JsonPrimitive(kind))
        put("trigger", trigger)
        when (triggerType) {
            TriggerType.STATE_DURATION -> {
                put("actions_above", buildJsonArray { add(action) })
                put("actions_below", buildJsonArray { })
            }
            else -> put("actions", buildJsonArray { add(action) })
        }
    }
}
