package cloud.teplanner.android.hub.quickactions

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import cloud.teplanner.android.automations.CapabilitiesViewModel
import cloud.teplanner.android.automations.RuleDisplay
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonElement

/**
 * Create-or-edit sheet for a HubAction. Mirrors iOS
 * `HubActionEditorSheet.swift`. Multi-step macros: each step picks
 * a capability via a flat DropdownMenu sorted by display name.
 *
 * v1 omits per-step param editing — the seeded defaults (锁车 /
 * 解锁 / 预热 / 后备箱) and most user actions don't carry params.
 * When a capability with params lands as a Quick Action target, the
 * CapabilityParamEditor port will plug into [stepCard] here.
 */
@OptIn(ExperimentalMaterial3Api::class, androidx.compose.ui.ExperimentalComposeUiApi::class)
@Composable
fun HubActionEditorSheet(
    editing: HubAction?,
    onDismiss: () -> Unit,
    viewModel: HubQuickActionsViewModel = hiltViewModel(),
    capabilitiesVm: CapabilitiesViewModel = hiltViewModel(),
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    val capState by capabilitiesVm.state.collectAsState()

    var name by remember { mutableStateOf(editing?.name ?: "") }
    var icon by remember { mutableStateOf(editing?.icon ?: "bolt.fill") }
    var tint by remember { mutableStateOf(editing?.tint ?: HubActionTint.DEFAULT) }
    var confirmRequired by remember { mutableStateOf(editing?.confirmRequired ?: false) }
    val steps = remember {
        mutableStateListOf<HubActionStep>().apply {
            addAll(editing?.steps ?: listOf(HubActionStep(capability = "")))
            if (isEmpty()) add(HubActionStep(capability = ""))
        }
    }
    var showingDeleteConfirm by remember { mutableStateOf(false) }

    val isValid = name.trim().isNotEmpty() &&
        steps.any { it.capability.isNotEmpty() }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        // Pull out the save lambda so the top header + sticky bottom
        // bar share it. iOS uses a top toolbar save; Android's
        // ModalBottomSheet convention puts confirm actions in a
        // sticky bottom row so the user doesn't have to scroll a
        // long form back up.
        val doSave: () -> Unit = {
            scope.launch {
                val validSteps = steps.filter { it.capability.isNotEmpty() }
                val trimmed = name.trim()
                if (editing == null) {
                    viewModel.store.create(
                        name = trimmed,
                        icon = icon,
                        tint = tint,
                        steps = validSteps,
                        confirmRequired = confirmRequired,
                    )
                } else {
                    viewModel.store.update(
                        id = editing.id,
                        name = trimmed,
                        icon = icon,
                        tint = tint,
                        steps = validSteps,
                        confirmRequired = confirmRequired,
                    )
                }
                onDismiss()
            }
        }

        Column(modifier = Modifier.fillMaxWidth().semantics { testTagsAsResourceId = true }) {
        LazyColumn(
            modifier = Modifier
                .padding(horizontal = 16.dp)
                .weight(1f, fill = false),
        ) {
            item {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        if (editing == null) "新建动作" else "编辑动作",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Spacer(Modifier.weight(1f))
                }
                Spacer(Modifier.height(8.dp))
            }

            // Name + meta section
            item {
                OutlinedTextField(
                    value = name,
                    onValueChange = { newValue ->
                        // Soft cap at 6 chars — Hub tiles wrap badly above.
                        name = newValue.take(6)
                    },
                    label = { Text("动作名称（最多 6 字）") },
                    singleLine = true,
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("hub_action_editor_name"),
                )
                Spacer(Modifier.height(12.dp))
            }

            // Icon picker (horizontal scroll of 32 icons in 4-col rows)
            item {
                Text("图标", style = MaterialTheme.typography.labelLarge)
                Spacer(Modifier.height(6.dp))
                LazyVerticalGrid(
                    columns = GridCells.Fixed(8),
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(max = 220.dp)
                        .testTag("hub_action_editor_icon"),
                ) {
                    items(HubIconLibrary.all) { sym ->
                        val selected = sym == icon
                        Box(
                            modifier = Modifier
                                .padding(2.dp)
                                .size(40.dp)
                                .clip(RoundedCornerShape(8.dp))
                                .background(
                                    if (selected) tintColor(tint)
                                    else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f)
                                )
                                .clickable { icon = sym }
                                .testTag("hub_icon_picker_$sym"),
                            contentAlignment = Alignment.Center,
                        ) {
                            Icon(
                                imageVector = HubIconLibrary.resolve(sym),
                                contentDescription = sym,
                                tint = if (selected) Color.White else MaterialTheme.colorScheme.onSurface,
                                modifier = Modifier.size(22.dp),
                            )
                        }
                    }
                }
                Spacer(Modifier.height(12.dp))
            }

            // Tint picker
            item {
                Text("颜色", style = MaterialTheme.typography.labelLarge)
                Spacer(Modifier.height(6.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    HubActionTint.values().forEach { t ->
                        Box(
                            modifier = Modifier
                                .size(36.dp)
                                .clip(CircleShape)
                                .background(tintColor(t))
                                .border(
                                    width = if (tint == t) 3.dp else 0.dp,
                                    color = Color.White,
                                    shape = CircleShape,
                                )
                                .clickable { tint = t }
                                .testTag("hub_action_editor_tint_${t.name.lowercase()}"),
                        )
                    }
                }
                Spacer(Modifier.height(16.dp))
                HorizontalDivider()
                Spacer(Modifier.height(12.dp))
            }

            // Steps
            item {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("执行步骤", style = MaterialTheme.typography.titleMedium)
                    Spacer(Modifier.weight(1f))
                    if (steps.size < 5) {
                        OutlinedButton(
                            onClick = { steps.add(HubActionStep(capability = "")) },
                            modifier = Modifier.testTag("hub_action_editor_add_step"),
                        ) {
                            Icon(Icons.Filled.Add, contentDescription = null, modifier = Modifier.size(18.dp))
                            Spacer(Modifier.width(4))
                            Text("添加步骤")
                        }
                    }
                }
                Spacer(Modifier.height(8.dp))
            }

            items(steps.size) { idx ->
                stepCard(
                    index = idx,
                    step = steps[idx],
                    capabilities = capState.capabilities,
                    onCapabilityChange = { capId ->
                        steps[idx] = steps[idx].copy(
                            capability = capId,
                            // Reset params when capability changes — the
                            // previous capability's defaults don't apply.
                            params = emptyMap<String, JsonElement>(),
                        )
                    },
                    onRemove = if (steps.size > 1) {
                        { steps.removeAt(idx) }
                    } else null,
                )
                Spacer(Modifier.height(8.dp))
            }

            // Confirm toggle
            item {
                Spacer(Modifier.height(8.dp))
                HorizontalDivider()
                Spacer(Modifier.height(8.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("执行前需要确认")
                    Spacer(Modifier.weight(1f))
                    Switch(
                        checked = confirmRequired,
                        onCheckedChange = { confirmRequired = it },
                        modifier = Modifier.testTag("hub_action_editor_confirm"),
                    )
                }
                Text(
                    "对解锁、启动空调等敏感动作建议保持开启。",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(Modifier.height(16.dp))
            }

            // Delete (non-system only)
            if (editing != null && !editing.isSystem) {
                item {
                    Button(
                        onClick = { showingDeleteConfirm = true },
                        colors = ButtonDefaults.buttonColors(
                            containerColor = MaterialTheme.colorScheme.errorContainer,
                            contentColor = MaterialTheme.colorScheme.onErrorContainer,
                        ),
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("hub_action_editor_delete"),
                    ) {
                        Icon(Icons.Filled.Delete, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(6))
                        Text("删除此动作")
                    }
                    Spacer(Modifier.height(24.dp))
                }
            } else {
                item { Spacer(Modifier.height(24.dp)) }
            }
        }

        // Sticky bottom row with 取消 + 保存. Stays in view even
        // when the editor's LazyColumn is scrolled deep into the
        // step cards — no need to scroll back up to commit.
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
        ) {
            TextButton(onClick = onDismiss) { Text("取消") }
            Spacer(Modifier.weight(1f))
            Button(
                onClick = { doSave() },
                enabled = isValid,
                modifier = Modifier.testTag("hub_action_editor_save"),
            ) {
                Text("保存")
            }
        }
        } // end outer Column
    }

    if (showingDeleteConfirm && editing != null) {
        AlertDialog(
            onDismissRequest = { showingDeleteConfirm = false },
            title = { Text("删除此动作？") },
            text = { Text("如果它被分配在某个槽位，槽位会被清空。") },
            confirmButton = {
                TextButton(onClick = {
                    showingDeleteConfirm = false
                    scope.launch {
                        viewModel.store.delete(editing.id)
                        onDismiss()
                    }
                }) { Text("删除") }
            },
            dismissButton = {
                TextButton(onClick = { showingDeleteConfirm = false }) { Text("取消") }
            },
        )
    }
}

@Composable
private fun stepCard(
    index: Int,
    step: HubActionStep,
    capabilities: List<cloud.teplanner.android.core.network.CapabilityInfo>,
    onCapabilityChange: (String) -> Unit,
    onRemove: (() -> Unit)?,
) {
    var menuExpanded by remember { mutableStateOf(false) }
    val currentName = if (step.capability.isEmpty()) "选择操作"
    else RuleDisplay.capabilityName(step.capability)

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f),
                RoundedCornerShape(10.dp),
            )
            .padding(12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                "第 ${index + 1} 步",
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.weight(1f))
            if (onRemove != null) {
                IconButton(onClick = onRemove) {
                    Icon(
                        Icons.Filled.Close,
                        contentDescription = "移除步骤",
                        modifier = Modifier.size(18.dp),
                    )
                }
            }
        }
        Box {
            OutlinedButton(
                onClick = { menuExpanded = true },
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("hub_action_editor_capability_$index"),
            ) {
                Text(currentName, modifier = Modifier.weight(1f))
                Icon(Icons.Filled.ExpandMore, contentDescription = null, modifier = Modifier.size(18.dp))
            }
            DropdownMenu(
                expanded = menuExpanded,
                onDismissRequest = { menuExpanded = false },
            ) {
                capabilities
                    .sortedBy { RuleDisplay.capabilityName(it.id) }
                    .forEach { cap ->
                        DropdownMenuItem(
                            text = { Text(RuleDisplay.capabilityName(cap.id)) },
                            onClick = {
                                onCapabilityChange(cap.id)
                                menuExpanded = false
                            },
                            trailingIcon = {
                                if (cap.id == step.capability) {
                                    Icon(Icons.Filled.Check, contentDescription = null)
                                }
                            },
                        )
                    }
            }
        }
    }
}

private fun tintColor(tint: HubActionTint): Color = when (tint) {
    HubActionTint.BLUE -> Color(0xFF2563EB)
    HubActionTint.RED -> Color(0xFFDC2626)
    HubActionTint.ORANGE -> Color(0xFFEA580C)
    HubActionTint.GREEN -> Color(0xFF16A34A)
    HubActionTint.GRAY -> Color(0xFF6B7280)
}

private fun Modifier.width(dp: Int): Modifier = this.then(Modifier.size(dp.dp, 0.dp))
