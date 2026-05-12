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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel

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

    Column(modifier = modifier.fillMaxWidth().testTag("hub_quick_actions_section")) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                "快捷操作",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
            )
            Spacer(modifier = Modifier.weight(1f))
            // 管理 button — mirrors iOS's section-header rename in
            // commit 4ebe038. Tapping opens the manage sheet (Phase 2,
            // not yet ported — caller's onManageTap is a no-op for now).
            Text(
                "管理",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier
                    .testTag("hub_quick_actions_manage")
                    .clickable { onManageTap() }
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
                                modifier = Modifier.testTag("hub_quick_action_slot_$idx"),
                            )
                        } else {
                            EmptyTile(
                                onTap = { creatingNew = true },
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
}

@Composable
private fun FilledTile(
    action: cloud.teplanner.android.hub.quickactions.HubAction,
    disabled: Boolean,
    onTap: () -> Unit,
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
            .clickable(enabled = !disabled) { onTap() }
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
