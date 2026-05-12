package cloud.teplanner.android.hub.quickactions

import androidx.compose.foundation.background
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
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

/**
 * Sheet shown when the user taps an empty Hub Quick Action slot.
 * Two paths:
 *   1. "新建动作" → opens the editor for a fresh action; on save
 *      iOS auto-assigns to the slot the user tapped. Android mirrors
 *      this via the create() store call with assignToFirstEmpty
 *      flipped to false + an explicit assignSlot afterwards.
 *   2. Tap an existing library row → assignSlot(slotIndex, that.id).
 *
 * System actions (锁车 / 解锁 / 预热 / 后备箱) and any user-created
 * actions both appear here — every library row, slotted or not,
 * is a candidate. iOS shows the existing-slot tag inline; this v1
 * lists by name + tint for visual consistency with the picker on
 * iOS. The manage sheet (Phase 2) is the proper place for the
 * full library view with "在槽 N / 未分配" tags.
 */
@OptIn(ExperimentalMaterial3Api::class, androidx.compose.ui.ExperimentalComposeUiApi::class)
@Composable
fun HubActionSlotPickerSheet(
    slotIndex: Int,
    onPick: (actionId: String) -> Unit,
    onCreateNew: () -> Unit,
    onDismiss: () -> Unit,
    viewModel: HubQuickActionsViewModel = hiltViewModel(),
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val actions by viewModel.store.actions.collectAsState()

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 16.dp)
                .semantics { testTagsAsResourceId = true },
        ) {
            Text(
                "选择动作",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(horizontal = 20.dp, vertical = 12.dp),
            )

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
                    .clickable { onCreateNew() }
                    .testTag("hub_action_picker_create"),
            )
            HorizontalDivider()

            if (actions.isEmpty()) {
                Text(
                    "暂无已有动作。点 \"新建动作\" 创建第一条。",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(horizontal = 20.dp, vertical = 16.dp),
                )
            } else {
                Text(
                    "从已有动作中选",
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp),
                )
                LazyColumn {
                    items(actions, key = { it.id }) { action ->
                        libraryRow(
                            action = action,
                            onTap = {
                                onPick(action.id)
                            },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun libraryRow(action: HubAction, onTap: () -> Unit) {
    val tint = tintColor(action.tint)
    ListItem(
        headlineContent = { Text(action.name) },
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
        trailingContent = if (action.isSystem) {
            {
                Text(
                    "系统",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        } else null,
        modifier = Modifier
            .clickable { onTap() }
            .testTag("hub_action_picker_row_${action.id}"),
    )
}

private fun tintColor(tint: HubActionTint): Color = when (tint) {
    HubActionTint.BLUE -> Color(0xFF2563EB)
    HubActionTint.RED -> Color(0xFFDC2626)
    HubActionTint.ORANGE -> Color(0xFFEA580C)
    HubActionTint.GREEN -> Color(0xFF16A34A)
    HubActionTint.GRAY -> Color(0xFF6B7280)
}
