package cloud.teplanner.android.automations

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import kotlinx.serialization.json.Json

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RuleDetailScreen(
    ruleId: String,
    onBack: () -> Unit,
    vm: AutomationsViewModel = hiltViewModel(),
) {
    val state by vm.state.collectAsState()
    val rule = state.rules.firstOrNull { it.id == ruleId }
    val snooze = state.snoozes[ruleId]
    var showSnoozeDialog by remember { mutableStateOf(false) }
    var showDeleteConfirm by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(rule?.name ?: "规则详情") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "返回")
                    }
                },
            )
        },
    ) { padding ->
        if (rule == null) {
            Column(
                Modifier.fillMaxSize().padding(padding),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally,
            ) { Text("规则未找到") }
            return@Scaffold
        }
        Column(
            modifier = Modifier
                .padding(padding)
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // Enabled card
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp)) {
                    androidx.compose.foundation.layout.Row(
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text("启用", style = MaterialTheme.typography.titleMedium)
                            Text(
                                if (rule.enabled) "规则正在生效" else "已暂停，不会触发提醒",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        Switch(
                            checked = rule.enabled,
                            onCheckedChange = { vm.toggleEnabled(rule.id, it) },
                        )
                    }
                }
            }

            // Snooze card
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = if (snooze != null)
                    CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.tertiaryContainer)
                else CardDefaults.cardColors(),
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text("静音", style = MaterialTheme.typography.titleMedium)
                    Spacer(Modifier.height(4.dp))
                    if (snooze != null) {
                        Text(
                            "已静音至 ${snooze.snoozedUntilUtc.take(16).replace('T', ' ')}",
                            style = MaterialTheme.typography.bodyMedium,
                        )
                        Spacer(Modifier.height(8.dp))
                        OutlinedButton(onClick = { vm.unsnooze(rule.id) }) {
                            Text("取消静音")
                        }
                    } else {
                        Text(
                            "静音期间不会推送通知",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Spacer(Modifier.height(8.dp))
                        OutlinedButton(onClick = { showSnoozeDialog = true }) {
                            Text("静音…")
                        }
                    }
                }
            }

            // Spec dump (read-only). Builder lands in F.4.
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text("规则定义 (只读)", style = MaterialTheme.typography.titleMedium)
                    Spacer(Modifier.height(8.dp))
                    Text(
                        Json { prettyPrint = true; encodeDefaults = true }.encodeToString(
                            kotlinx.serialization.json.JsonObject.serializer(),
                            rule.spec,
                        ),
                        style = MaterialTheme.typography.bodySmall,
                        fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
                    )
                }
            }

            // Delete (presets disable delete server-side; user-authored only)
            if (rule.presetId == null) {
                Spacer(Modifier.height(8.dp))
                Button(
                    onClick = { showDeleteConfirm = true },
                    modifier = Modifier.fillMaxWidth(),
                    colors = androidx.compose.material3.ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.errorContainer,
                        contentColor = MaterialTheme.colorScheme.onErrorContainer,
                    ),
                ) { Text("删除规则") }
            }
        }
    }

    if (showSnoozeDialog) {
        AlertDialog(
            onDismissRequest = { showSnoozeDialog = false },
            title = { Text("静音多久？") },
            text = {
                Column {
                    listOf("1 小时" to 1.0, "4 小时" to 4.0, "12 小时" to 12.0, "至明天 8 点" to 8.0)
                        .forEach { (label, hours) ->
                            TextButton(onClick = {
                                vm.snooze(ruleId, hours)
                                showSnoozeDialog = false
                            }) { Text(label) }
                        }
                }
            },
            confirmButton = {},
            dismissButton = {
                TextButton(onClick = { showSnoozeDialog = false }) { Text("取消") }
            },
        )
    }

    if (showDeleteConfirm) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirm = false },
            title = { Text("删除规则") },
            text = { Text("确定要删除「${rule?.name ?: ""}」？此操作不可撤销。") },
            confirmButton = {
                TextButton(onClick = {
                    vm.delete(ruleId)
                    showDeleteConfirm = false
                    onBack()
                }) { Text("删除", color = Color.Red) }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirm = false }) { Text("取消") }
            },
        )
    }
}
