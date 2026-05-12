package cloud.teplanner.android.hub.quickactions

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.RemoveCircleOutline
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
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
 * 2×4 grid of customizable tiles for one-tap Tesla commands. Mirrors
 * iOS `HubQuickActionsSection`. Each tile is either:
 *   - filled (assigned to a HubAction): icon + name + tap-to-run
 *   - empty: dashed border + plus icon
 *
 * v1 of the Android skeleton intentionally omits long-press menu,
 * drag-to-reorder, manage sheet — those come in subsequent slices.
 * What's here is enough to validate the data layer + per-tile run
 * dispatch + testTag plumbing for Maestro.
 *
 * testTag values mirror iOS accessibilityIdentifier strings exactly:
 *   - hub_quick_actions_section (whole container)
 *   - hub_quick_actions_manage (header "管理" button)
 *   - hub_quick_action_slot_<idx> (filled tile)
 *   - hub_quick_action_empty_<idx> (empty tile placeholder)
 */
@Composable
fun HubQuickActionsSection(
    vehicleId: String?,
    modifier: Modifier = Modifier,
    viewModel: HubQuickActionsViewModel = hiltViewModel(),
    onManageTap: () -> Unit = {},
) {
    val actions by viewModel.store.actions.collectAsState()
    val slots by viewModel.store.slots.collectAsState()

    var editingAction by remember { mutableStateOf<HubAction?>(null) }
    var creatingNew by remember { mutableStateOf(false) }
    // Slot picker state: the slot index the user tapped to open the
    // picker. Used to know where to assign the chosen action.
    var assigningSlotIndex by remember { mutableStateOf<Int?>(null) }
    var showingManageSheet by remember { mutableStateOf(false) }
    // Long-press menu state: the (action, slotIndex) pair the user
    // long-pressed. Drives the ModalBottomSheet rendering.
    var longPressTarget by remember { mutableStateOf<LongPressTarget?>(null) }
    var pendingDeleteAction by remember { mutableStateOf<HubAction?>(null) }
    val scope = rememberCoroutineScope()

    val shareVm: ShareViewModel = hiltViewModel()
    val createState by shareVm.createState.collectAsState()

    Column(modifier = modifier.fillMaxWidth().testTag("hub_quick_actions_section")) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                "快捷操作",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
            )
            Spacer(modifier = Modifier.weight(1f))
            // 管理 button — mirrors iOS's section-header rename in
            // commit 4ebe038. Opens HubActionsManageSheet (phase 2).
            Text(
                "管理",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier
                    .testTag("hub_quick_actions_manage")
                    .clickable {
                        onManageTap()
                        showingManageSheet = true
                    }
                    .padding(horizontal = 8.dp, vertical = 4.dp),
            )
        }
        Spacer(Modifier.height(8.dp))
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
                            FilledTile(
                                action = action,
                                disabled = vehicleId == null,
                                onTap = { viewModel.runAction(action.id, vehicleId) },
                                onLongPress = {
                                    longPressTarget = LongPressTarget(action, idx)
                                },
                                modifier = Modifier.testTag("hub_quick_action_slot_$idx"),
                            )
                        } else {
                            EmptyTile(
                                onTap = { assigningSlotIndex = idx },
                                modifier = Modifier.testTag("hub_quick_action_empty_$idx"),
                            )
                        }
                    }
                }
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
    if (showingManageSheet) {
        HubActionsManageSheet(
            onDismiss = { showingManageSheet = false },
            viewModel = viewModel,
        )
    }
    longPressTarget?.let { target ->
        LongPressMenu(
            action = target.action,
            slotIndex = target.slotIndex,
            onDismiss = { longPressTarget = null },
            onEdit = {
                editingAction = target.action
                longPressTarget = null
            },
            onClearSlot = {
                scope.launch {
                    viewModel.store.assignSlot(target.slotIndex, actionId = null)
                }
                longPressTarget = null
            },
            onShare = {
                val a = longPressTarget?.action
                longPressTarget = null
                if (a != null) {
                    shareVm.createShareForAction(a)
                }
            },
            onRequestDelete = {
                pendingDeleteAction = target.action
                longPressTarget = null
            },
        )
    }
    // Render the share code sheet on success of the createShareForAction call.
    (createState as? ShareViewModel.CreateState.Success)?.let { ok ->
        ShareCodeSheet(
            code = ok.detail.code,
            expiresAt = ok.detail.expiresAt,
            onDismiss = { shareVm.resetCreate() },
        )
    }
    (createState as? ShareViewModel.CreateState.Failed)?.let { fail ->
        AlertDialog(
            onDismissRequest = { shareVm.resetCreate() },
            title = { Text("分享失败") },
            text = { Text(fail.message) },
            confirmButton = {
                TextButton(onClick = { shareVm.resetCreate() }) { Text("好") }
            },
        )
    }

    pendingDeleteAction?.let { action ->
        AlertDialog(
            onDismissRequest = { pendingDeleteAction = null },
            title = { Text("删除「${action.name}」？") },
            text = { Text("此动作会被永久删除，已分配的槽位将清空。") },
            confirmButton = {
                TextButton(
                    onClick = {
                        scope.launch { viewModel.store.delete(action.id) }
                        pendingDeleteAction = null
                    },
                    modifier = Modifier.testTag("hub_action_delete_confirm"),
                ) { Text("删除") }
            },
            dismissButton = {
                TextButton(onClick = { pendingDeleteAction = null }) { Text("取消") }
            },
        )
    }
}

@Composable
private fun menuRow(
    text: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    onClick: () -> Unit,
    testTag: String,
    destructive: Boolean = false,
) {
    val color = if (destructive) MaterialTheme.colorScheme.error
                else MaterialTheme.colorScheme.onSurface
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .testTag(testTag)
            .clickable { onClick() }
            .padding(horizontal = 24.dp, vertical = 14.dp),
    ) {
        Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(22.dp))
        Spacer(Modifier.size(16.dp))
        Text(text, color = color, style = MaterialTheme.typography.bodyLarge)
    }
}

private data class LongPressTarget(
    val action: HubAction,
    val slotIndex: Int,
)

@OptIn(ExperimentalMaterial3Api::class, androidx.compose.ui.ExperimentalComposeUiApi::class)
@Composable
private fun LongPressMenu(
    action: HubAction,
    slotIndex: Int,
    onDismiss: () -> Unit,
    onEdit: () -> Unit,
    onClearSlot: () -> Unit,
    onShare: () -> Unit,
    onRequestDelete: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        // ModalBottomSheet renders content in a Dialog window which
        // doesn't inherit MainActivity's testTagsAsResourceId opt-in.
        // Set it here so Maestro's `id:` selector resolves the menu
        // rows below. Mirrors the same opt-in for every Compose
        // ModalBottomSheet body in the app.
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 16.dp)
                .semantics { testTagsAsResourceId = true },
        ) {
            Text(
                "「${action.name}」",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(horizontal = 20.dp, vertical = 12.dp),
            )
            // ListItem internally calls Modifier.semantics(mergeDescendants
            // = true) which absorbs any outer testTag into its merged
            // node — Maestro's findById then can't surface "the row".
            // Use plain Row layouts so testTag stays a top-level
            // accessibility element. Same iOS gesture-conflict pattern
            // we hit on Hub tiles (commit d01bc45).
            menuRow(
                text = "编辑动作",
                icon = Icons.Filled.Edit,
                onClick = onEdit,
                testTag = "hub_action_menu_edit",
            )
            menuRow(
                text = "分享给好友",
                icon = Icons.Filled.Share,
                onClick = onShare,
                testTag = "hub_action_menu_share",
            )
            menuRow(
                text = "从槽位移除",
                icon = Icons.Filled.RemoveCircleOutline,
                onClick = onClearSlot,
                testTag = "hub_action_menu_clear_slot",
            )
            if (!action.isSystem) {
                menuRow(
                    text = "删除动作",
                    icon = Icons.Filled.Delete,
                    onClick = onRequestDelete,
                    testTag = "hub_action_menu_delete",
                    destructive = true,
                )
            }
        }
    }
}

@OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class)
@Composable
private fun FilledTile(
    action: cloud.teplanner.android.hub.quickactions.HubAction,
    disabled: Boolean,
    onTap: () -> Unit,
    onLongPress: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val tint = tintColor(action.tint)
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
        modifier = modifier
            .fillMaxWidth()
            .height(72.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(tint.copy(alpha = 0.12f))
            .combinedClickable(
                enabled = !disabled,
                onClick = onTap,
                onLongClick = onLongPress,
            )
            .padding(vertical = 10.dp),
    ) {
        Icon(
            imageVector = HubIconLibrary.resolve(action.icon),
            contentDescription = null,
            tint = tint,
            modifier = Modifier.size(28.dp),
        )
        Spacer(Modifier.height(4.dp))
        Text(
            action.name,
            style = MaterialTheme.typography.bodySmall,
            maxLines = 1,
        )
    }
}

@Composable
private fun EmptyTile(onTap: () -> Unit, modifier: Modifier = Modifier) {
    val outline = MaterialTheme.colorScheme.outline
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
        modifier = modifier
            .fillMaxWidth()
            .height(72.dp)
            .clip(RoundedCornerShape(12.dp))
            .border(1.dp, outline.copy(alpha = 0.4f), RoundedCornerShape(12.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.15f))
            .clickable { onTap() }
            .padding(vertical = 10.dp),
    ) {
        Icon(
            imageVector = Icons.Filled.Add,
            contentDescription = "添加",
            tint = outline,
            modifier = Modifier.size(24.dp),
        )
        Spacer(Modifier.height(4.dp))
        Text(
            "添加",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.outline,
        )
    }
}

private fun tintColor(tint: HubActionTint): Color = when (tint) {
    HubActionTint.BLUE -> Color(0xFF2563EB)
    HubActionTint.RED -> Color(0xFFDC2626)
    HubActionTint.ORANGE -> Color(0xFFEA580C)
    HubActionTint.GREEN -> Color(0xFF16A34A)
    HubActionTint.GRAY -> Color(0xFF6B7280)
}
