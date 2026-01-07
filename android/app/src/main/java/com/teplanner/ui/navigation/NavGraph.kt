package com.teplanner.ui.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.teplanner.ui.home.HomeScreen
import com.teplanner.ui.search.SearchScreen
import com.teplanner.ui.vehicle.VehicleBindingScreen

object Routes {
    const val HOME = "home"
    const val SEARCH = "search"
    const val VEHICLE_BINDING = "vehicle_binding"
    const val PROFILE = "profile"
    const val SETTINGS = "settings"
}

@Composable
fun TePlannerNavGraph(
    navController: NavHostController = rememberNavController(),
    startDestination: String = Routes.HOME
) {
    NavHost(
        navController = navController,
        startDestination = startDestination
    ) {
        composable(Routes.HOME) {
            HomeScreen(
                onNavigateToSearch = {
                    navController.navigate(Routes.SEARCH)
                },
                onNavigateToVehicleBinding = {
                    navController.navigate(Routes.VEHICLE_BINDING)
                },
                onNavigateToProfile = {
                    navController.navigate(Routes.PROFILE)
                },
                onNavigateToSettings = {
                    navController.navigate(Routes.SETTINGS)
                }
            )
        }

        composable(Routes.SEARCH) {
            SearchScreen(
                onNavigateBack = {
                    navController.popBackStack()
                },
                onSelectDestination = { result ->
                    // Navigate back with result
                    // In a real app, would use SavedStateHandle to pass result
                    navController.popBackStack()
                }
            )
        }

        composable(Routes.VEHICLE_BINDING) {
            VehicleBindingScreen(
                onNavigateBack = {
                    navController.popBackStack()
                },
                onBindingSuccess = {
                    navController.popBackStack()
                }
            )
        }

        composable(Routes.PROFILE) {
            // Placeholder for ProfileScreen
            // ProfileScreen(onNavigateBack = { navController.popBackStack() })
        }

        composable(Routes.SETTINGS) {
            // Placeholder for SettingsScreen
            // SettingsScreen(onNavigateBack = { navController.popBackStack() })
        }
    }
}
