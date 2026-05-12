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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
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
import kotlinx.coroutines.launch

/**
 * Manage sheet for Hub Quick Actions. Mirrors iOS
 * HubActionsManageSheet.swift (commit 4ebe038). Single entry from
 * the Hub section header "管理" button.
 *
 * Sections:
 *   1. 槽位: 2×4 grid with × badges to clear slots. Empty slots
 *      surface the picker on tap (same path as the Hub tile).
 *   2. 我的动作: library list with "在槽 N / 未分配" tags. Tap a
 *      row to edit; system actions hide the swipe-delete and the
 *      destructive button inside the editor.
 *   3. 重置为默认 destructive button → AlertDialog → wipes
 *      everything + reseeds the 4 system actions.
 *
 * Drag-to-reorder is intentionally deferred from this Android
 * port — Compose's drag-and-drop within a grid requires custom
 * gesture detection that doesn't earn its complexity given (a)
 * the iOS Maestro test for drag was never reliable either, and
 * (b) the swap operation is already covered by HubActionsStore
 * tests on the iOS side.
 *
 * testTag values match iOS exactly so cross_platform Maestro
 * flows can target both clients.
 */
@OptIn(ExperimentalMaterial3Api::class, androidx.compose.ui.ExperimentalComposeUiApi::class)
@Composable
fun HubActionsManageSheet(
    onDismiss: () -> Unit,
    viewModel: HubQuickActionsViewModel = hiltViewModel(),
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()

    val actions by viewModel.store.actions.collectAsState()
    val slots by viewModel.store.slots.collectAsState()

    var editingAction by remember { mutableStateOf<HubAction?>(null) }
    var creatingNew by remember { mutableStateOf(false) }
    var assigningSlotIndex by remember { mutableStateOf<Int?>(null) }
    var pendingResetConfirm by remember { mutableStateOf(false) }
    var pendingDeleteAction by remember { mutableStateOf<HubAction?>(null) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        // ModalBottomSheet renders in a separate Dialog window which
        // doesn't inherit MainActivity's testTagsAsResourceId opt-in.
        // Set it here so Maestro `id:` selectors resolve.
        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .semantics { testTagsAsResourceId = true },
        ) {
            item {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        "管理快捷操作",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Spacer(Modifier.weight(1f))
                    TextButton(
                        onClick = onDismiss,
                        modifier = Modifier.testTag("hub_manage_done_button"),
                    ) { Text("完成") }
                }
                Spacer(Modifier.height(12.dp))
            }

            // Slot grid
            item {
                Text("槽位", style = MaterialTheme.typography.labelLarge)
                Spacer(Modifier.height(8.dp))
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.2f))
                        .padding(12.dp),
                ) {
                    for (row in 0 until 2) {
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                        ) {
                            for (col in 0 until 4) {
                                val idx = row * 4 + col
                                val slotId = slots.slots.getOrNull(idx)
                                val action = slotId?.let { id -> actions.firstOrNull { it.id == id } }
                                Box(modifier = Modifier.weight(1f)) {
                                    if (action != null) {
                                        manageSlotFilled(
                                            slotIndex = idx,
                                            action = action,
                                            onClear = {
                                                scope.launch {
                                                    viewModel.store.assignSlot(idx, null)
                                                }
                                            },
                                        )
                                    } else {
                                        manageSlotEmpty(
                                            slotIndex = idx,
                                            onTap = { assigningSlotIndex = idx },
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                Spacer(Modifier.height(6.dp))
                Text(
                    "点 × 把动作从槽位移走（动作保留在下面的列表里）。点空槽位从列表挑选。",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(Modifier.height(16.dp))
            }

            // Library section header + new action
            item {
                Text("我的动作", style = MaterialTheme.typography.labelLarge)
                Spacer(Modifier.height(8.dp))
                ListItem(
                    headlineContent = {
                        Text(
                            "新建动作",
                            color = MaterialTheme.colorScheme.primary,
                            fontWeight = FontWeight.Medium,
                        )
                    },
                    leadingContent = {
                        Icon(
                            Icons.Filled.Add,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                        )
                    },
                    modifier = Modifier
                        .clickable { creatingNew = true }
                        .testTag("hub_manage_new_action"),
                )
                HorizontalDivider()
            }

            // Library rows
            items(actions, key = { it.id }) { action ->
                libraryRow(
                    action = action,
                    slotLabel = slotLabelFor(action, slots),
                    onTap = { editingAction = action },
                    onLongDelete = if (!action.isSystem) {
                        { pendingDeleteAction = action }
                    } else null,
                )
                HorizontalDivider()
            }

            item {
                Spacer(Modifier.height(4.dp))
                Text(
                    "系统动作不能删除，但可以编辑名字 / 图标 / 颜色。",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(Modifier.height(16.dp))
            }

            // Reset
            item {
                Button(
                    onClick = { pendingResetConfirm = true },
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.errorContainer,
                        contentColor = MaterialTheme.colorScheme.onErrorContainer,
                    ),
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("hub_manage_reset_button"),
                ) {
                    Icon(Icons.Filled.Refresh, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(8.dp))
                    Text("重置为默认")
                }
                Spacer(Modifier.height(8.dp))
                Text(
                    "清空所有自建动作 + 槽位排列，恢复成首次打开时的状态。",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(Modifier.height(32.dp))
            }
        }
    }

    if (editingAction != null) {
        HubActionEditorSheet(
            editing = editingAction,
            onDismiss = { editingAction = null },
            viewModel = viewModel,
        )
    }
    if (creatingNew) {
        HubActionEditorSheet(
            editing = null,
            onDismiss = { creatingNew = false },
            viewModel = viewModel,
        )
    }
    assigningSlotIndex?.let { idx ->
        HubActionSlotPickerSheet(
            slotIndex = idx,
            onPick = { actionId ->
                scope.launch { viewModel.store.assignSlot(idx, actionId) }
                assigningSlotIndex = null
            },
            onCreateNew = {
                assigningSlotIndex = null
                creatingNew = true
            },
            onDismiss = { assigningSlotIndex = null },
            viewModel = viewModel,
        )
    }
    if (pendingResetConfirm) {
        AlertDialog(
            onDismissRequest = { pendingResetConfirm = false },
            title = { Text("重置为默认？") },
            text = {
                Text("所有自建动作 + 槽位排列都会被清空，恢复成默认的锁车 / 解锁 / 预热 / 后备箱。")
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        pendingResetConfirm = false
                        scope.launch { viewModel.store.resetToDefaults() }
                    },
                    modifier = Modifier.testTag("hub_manage_reset_confirm"),
                ) { Text("重置") }
            },
            dismissButton = {
                TextButton(onClick = { pendingResetConfirm = false }) { Text("取消") }
            },
        )
    }
    pendingDeleteAction?.let { a ->
        AlertDialog(
            onDismissRequest = { pendingDeleteAction = null },
            title = { Text("删除「${a.name}」？") },
            text = { Text("此动作会被永久删除，已分配的槽位将清空。") },
            confirmButton = {
                TextButton(
                    onClick = {
                        scope.launch { viewModel.store.delete(a.id) }
                        pendingDeleteAction = null
                    },
                    modifier = Modifier.testTag("hub_manage_delete_confirm"),
                ) { Text("删除") }
            },
            dismissButton = {
                TextButton(onClick = { pendingDeleteAction = null }) { Text("取消") }
            },
        )
    }
}

private fun slotLabelFor(action: HubAction, slots: HubSlots): String {
    val idx = slots.slots.indexOf(action.id)
    return if (idx >= 0) "在槽 ${idx + 1}" else "未分配"
}

@Composable
private fun manageSlotFilled(
    slotIndex: Int,
    action: HubAction,
    onClear: () -> Unit,
) {
    val tint = tintColor(action.tint)
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(72.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(tint.copy(alpha = 0.12f))
            .testTag("hub_manage_slot_$slotIndex"),
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
            modifier = Modifier.fillMaxWidth().padding(vertical = 10.dp),
        ) {
            Icon(
                HubIconLibrary.resolve(action.icon),
                contentDescription = null,
                tint = tint,
                modifier = Modifier.size(26.dp),
            )
            Spacer(Modifier.height(4.dp))
            Text(action.name, style = MaterialTheme.typography.bodySmall, maxLines = 1)
        }
        // × badge top-right.
        IconButton(
            onClick = onClear,
            modifier = Modifier
                .align(Alignment.TopEnd)
                .size(28.dp)
                .testTag("hub_manage_clear_x_$slotIndex"),
        ) {
            Icon(
                Icons.Filled.Cancel,
                contentDescription = "从槽位移除",
                tint = Color.Black.copy(alpha = 0.55f),
                modifier = Modifier.size(20.dp),
            )
        }
    }
}

@Composable
private fun manageSlotEmpty(slotIndex: Int, onTap: () -> Unit) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
        modifier = Modifier
            .fillMaxWidth()
            .height(72.dp)
            .clip(RoundedCornerShape(12.dp))
            .border(
                1.dp,
                MaterialTheme.colorScheme.outline.copy(alpha = 0.4f),
                RoundedCornerShape(12.dp),
            )
            .background(MaterialTheme.colorScheme.surface)
            .clickable { onTap() }
            .padding(vertical = 10.dp)
            .testTag("hub_manage_slot_empty_$slotIndex"),
    ) {
        Icon(
            Icons.Filled.Add,
            contentDescription = "添加",
            tint = MaterialTheme.colorScheme.outline,
            modifier = Modifier.size(22.dp),
        )
        Spacer(Modifier.height(4.dp))
        Text(
            "空",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.outline,
        )
    }
}

@Composable
private fun libraryRow(
    action: HubAction,
    slotLabel: String,
    onTap: () -> Unit,
    onLongDelete: (() -> Unit)?,
) {
    val tint = tintColor(action.tint)
    ListItem(
        headlineContent = { Text(action.name) },
        supportingContent = {
            Text(
                slotLabel,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        },
        leadingContent = {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(tint.copy(alpha = 0.12f)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    HubIconLibrary.resolve(action.icon),
                    contentDescription = null,
                    tint = tint,
                    modifier = Modifier.size(20.dp),
                )
            }
        },
        trailingContent = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (action.isSystem) {
                    Text(
                        "系统",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Spacer(Modifier.width(6.dp))
                }
                Icon(
                    Icons.Filled.ChevronRight,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.outline,
                )
            }
        },
        modifier = Modifier
            .clickable { onTap() }
            .testTag("hub_manage_library_row_${action.id}"),
    )
}

private fun tintColor(tint: HubActionTint): Color = when (tint) {
    HubActionTint.BLUE -> Color(0xFF2563EB)
    HubActionTint.RED -> Color(0xFFDC2626)
    HubActionTint.ORANGE -> Color(0xFFEA580C)
    HubActionTint.GREEN -> Color(0xFF16A34A)
    HubActionTint.GRAY -> Color(0xFF6B7280)
}
