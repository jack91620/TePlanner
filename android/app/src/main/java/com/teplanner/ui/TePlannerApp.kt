package com.teplanner.ui

import androidx.compose.runtime.Composable
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.teplanner.ui.home.HomeScreen
import com.teplanner.ui.search.SearchScreen
import com.teplanner.ui.vehicle.VehicleBindingScreen

sealed class Screen(val route: String) {
    object Home : Screen("home")
    object Search : Screen("search")
    object VehicleBinding : Screen("vehicle_binding")
    object Profile : Screen("profile")
    object Settings : Screen("settings")
    object StationDetail : Screen("station_detail/{stationId}") {
        fun createRoute(stationId: String) = "station_detail/$stationId"
    }
}

@Composable
fun TePlannerApp() {
    val navController = rememberNavController()

    NavHost(
        navController = navController,
        startDestination = Screen.Home.route
    ) {
        composable(Screen.Home.route) {
            HomeScreen(
                onNavigateToSearch = { navController.navigate(Screen.Search.route) },
                onNavigateToVehicleBinding = { navController.navigate(Screen.VehicleBinding.route) },
                onNavigateToProfile = { navController.navigate(Screen.Profile.route) },
                onNavigateToSettings = { navController.navigate(Screen.Settings.route) }
            )
        }

        composable(Screen.Search.route) {
            SearchScreen(
                onNavigateBack = { navController.popBackStack() },
                onSelectDestination = { result ->
                    // Pass result back to HomeScreen via SavedStateHandle
                    navController.previousBackStackEntry?.savedStateHandle?.set("destination", result)
                    navController.popBackStack()
                }
            )
        }

        composable(Screen.VehicleBinding.route) {
            VehicleBindingScreen(
                onNavigateBack = {
                    android.util.Log.d("TePlannerApp", "onNavigateBack called")
                    navController.popBackStack()
                },
                onBindingSuccess = {
                    android.util.Log.d("TePlannerApp", "onBindingSuccess - calling popBackStack()")
                    navController.popBackStack()
                }
            )
        }

        composable(Screen.Profile.route) {
            // TODO: Implement ProfileScreen
            // ProfileScreen(
            //     onNavigateBack = { navController.popBackStack() },
            //     onNavigateToSettings = { navController.navigate(Screen.Settings.route) }
            // )
        }

        composable(Screen.Settings.route) {
            // TODO: Implement SettingsScreen
            // SettingsScreen(
            //     onNavigateBack = { navController.popBackStack() }
            // )
        }
    }
}
