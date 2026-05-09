package cloud.teplanner.android.nav

import androidx.compose.runtime.Composable
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import cloud.teplanner.android.auth.AuthSession
import cloud.teplanner.android.auth.LoginScreen
import cloud.teplanner.android.hub.HubScreen

/**
 * Phase F.1 navigation graph:
 *   Splash (decides) → Login (if no token) | Hub (if token)
 *
 * iOS [RootView] does the same via `if authSession.isAuthenticated`.
 * Compose Navigation is overkill for 2 destinations but it's the
 * pattern F.2+ will scale on (auto list, rule detail, builder, map,
 * settings).
 */
object Routes {
    const val SPLASH = "splash"
    const val LOGIN = "login"
    const val HUB = "hub"
}

@Composable
fun AppNavGraph() {
    val nav = rememberNavController()
    NavHost(navController = nav, startDestination = Routes.SPLASH) {
        splash(nav)
        login(nav)
        hub(nav)
    }
}

private fun NavGraphBuilder.splash(nav: NavHostController) {
    composable(Routes.SPLASH) {
        // The Splash composable just reads the auth state once and
        // navigates. We use the same hiltViewModel scope so login /
        // logout actions in Login/Hub touch the same instance and
        // navigation reflects the latest state.
        val auth: AuthSession = hiltViewModel()
        val target = if (auth.isAuthenticated) Routes.HUB else Routes.LOGIN
        androidx.compose.runtime.LaunchedEffect(target) {
            nav.navigate(target) {
                popUpTo(Routes.SPLASH) { inclusive = true }
            }
        }
    }
}

private fun NavGraphBuilder.login(nav: NavHostController) {
    composable(Routes.LOGIN) {
        LoginScreen(
            onLoggedIn = {
                nav.navigate(Routes.HUB) {
                    popUpTo(Routes.LOGIN) { inclusive = true }
                }
            },
        )
    }
}

private fun NavGraphBuilder.hub(nav: NavHostController) {
    composable(Routes.HUB) {
        HubScreen(
            onLoggedOut = {
                nav.navigate(Routes.LOGIN) {
                    popUpTo(Routes.HUB) { inclusive = true }
                }
            },
        )
    }
}
