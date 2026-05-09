package cloud.teplanner.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import cloud.teplanner.android.ui.theme.TautomationTheme
import dagger.hilt.android.AndroidEntryPoint

/**
 * Phase F.0 — single activity entry-point. The compose graph
 * (login / hub / sub-pages) lands in F.1; for now this just renders
 * a hello-world so the toolchain end-to-end can be verified
 * (gradle sync → emulator → AMap+JPush libs link).
 */
@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            TautomationTheme {
                Scaffold(modifier = Modifier.fillMaxSize()) { padding ->
                    HelloScreen(modifier = Modifier.padding(padding))
                }
            }
        }
    }
}

@Composable
fun HelloScreen(modifier: Modifier = Modifier) {
    Surface(modifier = modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
        Column(
            modifier = Modifier.fillMaxSize().padding(24.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text("Tautomation", style = MaterialTheme.typography.headlineLarge)
            Text("Android Phase F.0 — toolchain ready", style = MaterialTheme.typography.bodyMedium)
        }
    }
}

@Preview(showBackground = true)
@Composable
fun HelloPreview() {
    TautomationTheme { HelloScreen() }
}
