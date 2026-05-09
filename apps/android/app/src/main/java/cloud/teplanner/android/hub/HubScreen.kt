package cloud.teplanner.android.hub

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import cloud.teplanner.android.auth.AuthSession

/**
 * Phase F.1 — Hub placeholder. iOS [HubView] is ~800 LOC of status
 * card / alert pill / departure card / charge-limit card / nav links;
 * F.2 will mirror that. F.1 just confirms the navigation contract:
 * after login the user lands here, sees their email, can log out.
 */
@Composable
fun HubScreen(
    onLoggedOut: () -> Unit,
    auth: AuthSession = hiltViewModel(),
) {
    val account by auth.account.collectAsState()
    Surface(
        modifier = Modifier.fillMaxSize(),
        color = MaterialTheme.colorScheme.background,
    ) {
        Column(
            modifier = Modifier.fillMaxSize().padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Text(
                text = "Tautomation",
                style = MaterialTheme.typography.headlineLarge,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = "Phase F.1 — 已登录",
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(24.dp))
            Text(
                text = account?.email ?: "(no account)",
                style = MaterialTheme.typography.bodyLarge,
            )
            account?.userId?.let {
                Text(
                    text = "user_id: $it",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            Spacer(Modifier.height(48.dp))
            Button(
                onClick = {
                    auth.logout()
                    onLoggedOut()
                },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("退出登录")
            }
        }
    }
}
