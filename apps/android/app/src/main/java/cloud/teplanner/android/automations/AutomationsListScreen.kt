package cloud.teplanner.android.automations

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.NotificationsOff
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import cloud.teplanner.android.core.network.RuleResponse
import cloud.teplanner.android.core.network.SnoozeRecord
import sh.calvin.reorderable.ReorderableItem
import sh.calvin.reorderable.rememberReorderableLazyListState

/**
 * Phase F.4 polish — automation list with parity to iOS:
 *   - Long-press + drag → reorder rules within the same section
 *   - Swipe trailing edge (left swipe) → delete with confirmation
 *   - Tap row → detail screen
 *
 * Reorder uses sh.calvin.reorderable; delete uses M3 SwipeToDismissBox.
 * Both presets and custom rules are reorderable + deletable to match
 * the user's expectations from the iOS build (backend allows preset
 * delete since the 2026-05-10 change).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AutomationsListScreen(
    onBack: () -> Unit,
    onRule: (String) -> Unit,
    vm: AutomationsViewModel = hiltViewModel(),
) {
    val state by vm.state.collectAsState()
    var pendingDelete by remember { mutableStateOf<RuleResponse?>(null) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("自动化") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "返回")
                    }
                },
            )
        },
    ) { padding ->
        Column(modifier = Modifier.padding(padding).fillMaxSize()) {
            when {
                state.isLoading && state.rules.isEmpty() -> {
                    Column(
                        modifier = Modifier.fillMaxSize(),
                        verticalArrangement = Arrangement.Center,
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) { CircularProgressIndicator() }
                }
                state.error != null && state.rules.isEmpty() -> {
                    Column(
                        modifier = Modifier.fillMaxSize().padding(24.dp),
                        verticalArrangement = Arrangement.Center,
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Text("加载失败：${state.error}", color = MaterialTheme.colorScheme.error)
                    }
                }
                else -> ReorderableList(
                    rules = state.rules,
                    snoozes = state.snoozes,
                    onToggle = { id, on -> vm.toggleEnabled(id, on) },
                    onClick = onRule,
                    onDelete = { rule -> pendingDelete = rule },
                    onReorder = { ordered -> vm.reorder(ordered) },
                )
            }
        }
    }

    pendingDelete?.let { rule ->
        AlertDialog(
            onDismissRequest = { pendingDelete = null },
            title = { Text("删除「${rule.name}」？") },
            text = { Text("删除后无法恢复。如只想暂停，可在右侧关闭开关。") },
            confirmButton = {
                TextButton(onClick = {
                    vm.delete(rule.id)
                    pendingDelete = null
                }) { Text("删除", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { pendingDelete = null }) { Text("取消") }
            },
        )
    }
}

@Composable
private fun ReorderableList(
    rules: List<RuleResponse>,
    snoozes: Map<String, SnoozeRecord>,
    onToggle: (String, Boolean) -> Unit,
    onClick: (String) -> Unit,
    onDelete: (RuleResponse) -> Unit,
    onReorder: (List<String>) -> Unit,
) {
    val lazyListState = rememberLazyListState()
    // Track local order during a drag — committed to backend on drop.
    var localOrder by remember(rules.map { it.id }) { mutableStateOf(rules) }
    LaunchedEffect(rules) { localOrder = rules }

    val reorderState = rememberReorderableLazyListState(lazyListState) { from, to ->
        localOrder = localOrder.toMutableList().apply {
            add(to.index, removeAt(from.index))
        }
        onReorder(localOrder.map { it.id })
    }

    LazyColumn(
        state = lazyListState,
        modifier = Modifier.fillMaxSize(),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(12.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        items(localOrder, key = { it.id }) { rule ->
            ReorderableItem(reorderState, key = rule.id) { isDragging ->
                val snooze = snoozes[rule.id]
                SwipeableRow(
                    rule = rule,
                    snooze = snooze,
                    isDragging = isDragging,
                    dragHandle = Modifier.draggableHandle(),
                    onToggle = { on -> onToggle(rule.id, on) },
                    onClick = { onClick(rule.id) },
                    onDelete = { onDelete(rule) },
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SwipeableRow(
    rule: RuleResponse,
    snooze: SnoozeRecord?,
    isDragging: Boolean,
    dragHandle: Modifier,
    onToggle: (Boolean) -> Unit,
    onClick: () -> Unit,
    onDelete: () -> Unit,
) {
    val dismissState = rememberSwipeToDismissBoxState(
        confirmValueChange = { value ->
            if (value == SwipeToDismissBoxValue.EndToStart) {
                onDelete()
                false  // don't actually dismiss; let the confirmation dialog drive it
            } else false
        },
        positionalThreshold = { it * 0.3f },
    )
    SwipeToDismissBox(
        state = dismissState,
        enableDismissFromStartToEnd = false,
        backgroundContent = {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(MaterialTheme.colorScheme.errorContainer,
                                shape = RoundedCornerShape(12.dp))
                    .padding(horizontal = 24.dp),
                contentAlignment = Alignment.CenterEnd,
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.Delete, contentDescription = "删除",
                         tint = MaterialTheme.colorScheme.onErrorContainer)
                    Spacer(Modifier.size(6.dp))
                    Text("删除",
                         color = MaterialTheme.colorScheme.onErrorContainer,
                         style = MaterialTheme.typography.labelLarge)
                }
            }
        },
    ) {
        RuleRowCard(
            rule = rule,
            snooze = snooze,
            isDragging = isDragging,
            dragHandle = dragHandle,
            onToggle = onToggle,
            onClick = onClick,
        )
    }
}

@Composable
private fun RuleRowCard(
    rule: RuleResponse,
    snooze: SnoozeRecord?,
    isDragging: Boolean,
    dragHandle: Modifier,
    onToggle: (Boolean) -> Unit,
    onClick: () -> Unit,
) {
    val firing = rule.isFiring
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(if (isDragging) 8.dp else 0.dp, RoundedCornerShape(12.dp))
            .clickable(onClick = onClick),
        colors = CardDefaults.cardColors(
            containerColor = when {
                isDragging -> MaterialTheme.colorScheme.surfaceContainerHigh
                firing -> Color(0xFFFFE5E5)  // 12% red wash, mirrors iOS
                else -> MaterialTheme.colorScheme.surfaceVariant
            },
        ),
    ) {
        Row(
            modifier = Modifier.padding(16.dp).then(dragHandle),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .background(
                        if (firing) Color(0xFFD32F2F) else Color.Transparent,
                        shape = RoundedCornerShape(8.dp),
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = when {
                        firing -> Icons.Filled.Warning
                        snooze != null -> Icons.Filled.NotificationsOff
                        else -> Icons.Filled.Notifications
                    },
                    contentDescription = null,
                    tint = when {
                        firing -> Color.White
                        snooze != null -> MaterialTheme.colorScheme.tertiary
                        else -> MaterialTheme.colorScheme.primary
                    },
                    modifier = Modifier.size(if (firing) 22.dp else 28.dp),
                )
            }
            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(rule.name, style = MaterialTheme.typography.bodyLarge)
                    if (firing) {
                        Text(
                            "正在触发",
                            color = Color.White,
                            style = MaterialTheme.typography.labelSmall,
                            modifier = Modifier
                                .background(Color(0xFFD32F2F),
                                            shape = RoundedCornerShape(50))
                                .padding(horizontal = 6.dp, vertical = 2.dp),
                        )
                    }
                }
                if (snooze != null) {
                    Text(
                        "已静音至 ${snooze.snoozedUntilUtc.take(16).replace('T', ' ')}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.tertiary,
                    )
                } else if (rule.presetId != null) {
                    Text("预设规则", style = MaterialTheme.typography.bodySmall,
                         color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            Spacer(modifier = Modifier.size(8.dp))
            Switch(checked = rule.enabled, onCheckedChange = onToggle)
        }
    }
}
