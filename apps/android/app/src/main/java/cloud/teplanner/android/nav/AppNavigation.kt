package cloud.teplanner.android.nav

import androidx.compose.runtime.Composable
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import cloud.teplanner.android.auth.AuthSession
import cloud.teplanner.android.auth.LoginScreen
import cloud.teplanner.android.automations.AutomationsListScreen
import cloud.teplanner.android.automations.RuleDetailScreen
import cloud.teplanner.android.hub.HubScreen

/**
 * Phase F.2 navigation graph:
 *   Splash (decides) → Login (no token) | Hub
 *   Hub → Automations → RuleDetail
 *
 * Map / scheduled departure / settings land in F.3 / F.4.
 */
object Routes {
    const val SPLASH = "splash"
    const val LOGIN = "login"
    const val HUB = "hub"
    const val AUTOMATIONS = "automations"
    const val RULE_DETAIL_PATTERN = "rules/{id}"
    fun ruleDetail(id: String) = "rules/$id"
}

@Composable
fun AppNavGraph() {
    val nav = rememberNavController()
    NavHost(navController = nav, startDestination = Routes.SPLASH) {
        splash(nav)
        login(nav)
        hub(nav)
        automations(nav)
        ruleDetail(nav)
    }
}

private fun NavGraphBuilder.splash(nav: NavHostController) {
    composable(Routes.SPLASH) {
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
            onAutomations = { nav.navigate(Routes.AUTOMATIONS) },
        )
    }
}

private fun NavGraphBuilder.automations(nav: NavHostController) {
    composable(Routes.AUTOMATIONS) {
        AutomationsListScreen(
            onBack = { nav.popBackStack() },
            onRule = { id -> nav.navigate(Routes.ruleDetail(id)) },
        )
    }
}

private fun NavGraphBuilder.ruleDetail(nav: NavHostController) {
    composable(
        Routes.RULE_DETAIL_PATTERN,
        arguments = listOf(navArgument("id") { type = NavType.StringType }),
    ) { entry ->
        val id = entry.arguments?.getString("id").orEmpty()
        RuleDetailScreen(ruleId = id, onBack = { nav.popBackStack() })
    }
}
