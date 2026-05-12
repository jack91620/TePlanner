package cloud.teplanner.android.departure

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.unit.dp
import cloud.teplanner.android.core.network.ScheduledDepartureResponse
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter

/**
 * 下次出行 sheet — Android port of iOS ScheduledDepartureSheet.
 *
 * Uses ModalBottomSheet (not AlertDialog) so the testTagsAsResourceId
 * opt-in at the content root propagates to every nested testTagged
 * element. AlertDialog's confirmButton/dismissButton render in
 * sibling subtrees of the Dialog and would each need its own opt-in.
 *
 * Time selection diverges from iOS (preset chips vs DatePicker) but
 * other affordances share the iOS testTag set so cross-platform
 * Maestro flows work:
 *   departure_picker / departure_label_field / departure_lead_slider /
 *   departure_save_button / departure_clear_button
 */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalComposeUiApi::class)
@Composable
fun ScheduledDepartureSheet(
    current: ScheduledDepartureResponse?,
    onSave: (ZonedDateTime, leadMin: Int, targetSoc: Int?, label: String?) -> Unit,
    onClear: () -> Unit,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val now = remember { ZonedDateTime.now() }
    val presets = remember {
        listOf(
            "+30 分钟" to now.plusMinutes(30),
            "+1 小时" to now.plusHours(1),
            "+2 小时" to now.plusHours(2),
            "明早 7:30" to nextMorning(now, 7, 30),
            "明早 8:30" to nextMorning(now, 8, 30),
            "今晚 22:00" to todayOrTomorrow(now, 22, 0),
        )
    }
    var selected by remember {
        mutableStateOf<ZonedDateTime>(nextMorning(now, 8, 0))
    }
    var label by remember { mutableStateOf(current?.label ?: "") }
    var leadMin by remember { mutableIntStateOf(current?.leadMinutes ?: 15) }
    var targetSoc by remember { mutableIntStateOf(current?.targetChargeSoc ?: 80) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .semantics { testTagsAsResourceId = true }
                .padding(horizontal = 20.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                "下次出行",
                style = MaterialTheme.typography.titleLarge,
            )
            current?.let {
                Text(
                    "当前: ${ScheduledDepartureViewModel.displayLocal(it.departureAtUtc)}" +
                    " · 提前 ${it.leadMinutes} 分钟" +
                    (it.targetChargeSoc?.let { soc -> " · 目标 ${soc}%" } ?: ""),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Spacer(Modifier.height(4.dp))
            Text("出发时间", style = MaterialTheme.typography.titleSmall)
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("departure_picker"),
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    presets.take(3).forEach { (lbl, dt) ->
                        OutlinedButton(onClick = { selected = dt }) {
                            Text(lbl, style = MaterialTheme.typography.labelSmall)
                        }
                    }
                }
                Row(
                    modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    presets.drop(3).forEach { (lbl, dt) ->
                        OutlinedButton(onClick = { selected = dt }) {
                            Text(lbl, style = MaterialTheme.typography.labelSmall)
                        }
                    }
                }
                Spacer(Modifier.height(8.dp))
                Text(
                    "✓ ${DateTimeFormatter.ofPattern("MM-dd HH:mm").format(selected)}",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.primary,
                )
            }
            Spacer(Modifier.height(4.dp))
            OutlinedTextField(
                value = label,
                onValueChange = { label = it },
                placeholder = { Text("备注（选填）") },
                singleLine = true,
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("departure_label_field"),
            )
            Spacer(Modifier.height(8.dp))
            Text("提前 $leadMin 分钟预热")
            Slider(
                value = leadMin.toFloat(),
                onValueChange = { leadMin = it.toInt() },
                valueRange = 5f..60f,
                steps = 10,
                modifier = Modifier.testTag("departure_lead_slider"),
            )
            Spacer(Modifier.height(4.dp))
            Text("目标电量 $targetSoc%")
            Slider(
                value = targetSoc.toFloat(),
                onValueChange = { targetSoc = it.toInt() },
                valueRange = 50f..100f,
                steps = 9,
            )
            Spacer(Modifier.height(8.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End,
            ) {
                if (current != null) {
                    TextButton(
                        onClick = { onClear(); onDismiss() },
                        modifier = Modifier.testTag("departure_clear_button"),
                    ) { Text("清除", color = MaterialTheme.colorScheme.error) }
                    Spacer(Modifier.padding(end = 8.dp))
                }
                TextButton(onClick = onDismiss) { Text("取消") }
                Spacer(Modifier.padding(end = 8.dp))
                TextButton(
                    onClick = {
                        onSave(selected, leadMin, targetSoc, label.takeIf { it.isNotBlank() })
                        onDismiss()
                    },
                    modifier = Modifier.testTag("departure_save_button"),
                ) { Text("保存") }
            }
            Spacer(Modifier.height(12.dp))
        }
    }
}

private fun nextMorning(now: ZonedDateTime, h: Int, m: Int): ZonedDateTime {
    val today = now.toLocalDate().atTime(h, m).atZone(now.zone)
    return if (today.isAfter(now)) today else today.plusDays(1)
}

private fun todayOrTomorrow(now: ZonedDateTime, h: Int, m: Int): ZonedDateTime {
    val today = now.toLocalDate().atTime(h, m).atZone(now.zone)
    return if (today.isAfter(now)) today else today.plusDays(1)
}
