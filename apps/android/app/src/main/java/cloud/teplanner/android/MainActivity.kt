package cloud.teplanner.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import cloud.teplanner.android.nav.AppNavGraph
import cloud.teplanner.android.ui.theme.TautomationTheme
import dagger.hilt.android.AndroidEntryPoint

/**
 * Phase F.1 — single activity hosts the Compose nav graph.
 * Splash decides Login vs Hub based on persisted token.
 */
@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    @OptIn(androidx.compose.ui.ExperimentalComposeUiApi::class)
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            TautomationTheme {
                // 2026-05-11: `testTag` is normally Compose-internal —
                // UIAutomator / Maestro / Espresso (everything reading
                // the platform accessibility tree) can't see it without
                // this opt-in. The platform exposes the testTag as
                // `resource-id` once `testTagsAsResourceId = true`
                // anywhere in the parent semantics chain, so we set
                // it once at the root and all nested testTags become
                // queryable by `id:` in Maestro.
                Scaffold(
                    modifier = Modifier
                        .fillMaxSize()
                        .semantics { testTagsAsResourceId = true }
                ) { _ ->
                    AppNavGraph()
                }
            }
        }
    }
}
