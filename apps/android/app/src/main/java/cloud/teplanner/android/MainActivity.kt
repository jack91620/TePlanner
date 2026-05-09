package cloud.teplanner.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import cloud.teplanner.android.nav.AppNavGraph
import cloud.teplanner.android.ui.theme.TautomationTheme
import dagger.hilt.android.AndroidEntryPoint

/**
 * Phase F.1 — single activity hosts the Compose nav graph.
 * Splash decides Login vs Hub based on persisted token.
 */
@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            TautomationTheme {
                Scaffold(modifier = Modifier.fillMaxSize()) { _ ->
                    AppNavGraph()
                }
            }
        }
    }
}
