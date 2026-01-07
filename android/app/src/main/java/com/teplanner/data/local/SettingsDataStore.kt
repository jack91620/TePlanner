package com.teplanner.data.local

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.*
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "settings")

@Singleton
class SettingsDataStore @Inject constructor(
    private val context: Context
) {
    private object Keys {
        val AUTH_TOKEN = stringPreferencesKey("auth_token")
        val REFRESH_TOKEN = stringPreferencesKey("refresh_token")
        val USER_ID = stringPreferencesKey("user_id")
        val TESLA_LINKED = booleanPreferencesKey("tesla_linked")
        val TARGET_ARRIVAL_SOC = intPreferencesKey("target_arrival_soc")
        val MIN_CHARGING_SOC = intPreferencesKey("min_charging_soc")
        val PREFER_SUPERCHARGER = booleanPreferencesKey("prefer_supercharger")
        val DISTANCE_UNIT = stringPreferencesKey("distance_unit") // "km" or "mi"
    }

    // ============ Auth Token ============

    val authToken: Flow<String?> = context.dataStore.data.map { preferences ->
        preferences[Keys.AUTH_TOKEN]
    }

    suspend fun setAuthToken(token: String?) {
        context.dataStore.edit { preferences ->
            if (token != null) {
                preferences[Keys.AUTH_TOKEN] = token
            } else {
                preferences.remove(Keys.AUTH_TOKEN)
            }
        }
    }

    val refreshToken: Flow<String?> = context.dataStore.data.map { preferences ->
        preferences[Keys.REFRESH_TOKEN]
    }

    suspend fun setRefreshToken(token: String?) {
        context.dataStore.edit { preferences ->
            if (token != null) {
                preferences[Keys.REFRESH_TOKEN] = token
            } else {
                preferences.remove(Keys.REFRESH_TOKEN)
            }
        }
    }

    // ============ User Info ============

    val userId: Flow<String?> = context.dataStore.data.map { preferences ->
        preferences[Keys.USER_ID]
    }

    suspend fun setUserId(id: String?) {
        context.dataStore.edit { preferences ->
            if (id != null) {
                preferences[Keys.USER_ID] = id
            } else {
                preferences.remove(Keys.USER_ID)
            }
        }
    }

    val teslaLinked: Flow<Boolean> = context.dataStore.data.map { preferences ->
        preferences[Keys.TESLA_LINKED] ?: false
    }

    suspend fun setTeslaLinked(linked: Boolean) {
        context.dataStore.edit { preferences ->
            preferences[Keys.TESLA_LINKED] = linked
        }
    }

    // ============ Route Settings ============

    val targetArrivalSoc: Flow<Int> = context.dataStore.data.map { preferences ->
        preferences[Keys.TARGET_ARRIVAL_SOC] ?: 20
    }

    suspend fun setTargetArrivalSoc(soc: Int) {
        context.dataStore.edit { preferences ->
            preferences[Keys.TARGET_ARRIVAL_SOC] = soc
        }
    }

    val minChargingSoc: Flow<Int> = context.dataStore.data.map { preferences ->
        preferences[Keys.MIN_CHARGING_SOC] ?: 10
    }

    suspend fun setMinChargingSoc(soc: Int) {
        context.dataStore.edit { preferences ->
            preferences[Keys.MIN_CHARGING_SOC] = soc
        }
    }

    val preferSupercharger: Flow<Boolean> = context.dataStore.data.map { preferences ->
        preferences[Keys.PREFER_SUPERCHARGER] ?: true
    }

    suspend fun setPreferSupercharger(prefer: Boolean) {
        context.dataStore.edit { preferences ->
            preferences[Keys.PREFER_SUPERCHARGER] = prefer
        }
    }

    // ============ Display Settings ============

    val distanceUnit: Flow<String> = context.dataStore.data.map { preferences ->
        preferences[Keys.DISTANCE_UNIT] ?: "km"
    }

    suspend fun setDistanceUnit(unit: String) {
        context.dataStore.edit { preferences ->
            preferences[Keys.DISTANCE_UNIT] = unit
        }
    }

    // ============ Clear All ============

    suspend fun clearAll() {
        context.dataStore.edit { preferences ->
            preferences.clear()
        }
    }

    suspend fun clearAuth() {
        context.dataStore.edit { preferences ->
            preferences.remove(Keys.AUTH_TOKEN)
            preferences.remove(Keys.REFRESH_TOKEN)
            preferences.remove(Keys.USER_ID)
            preferences.remove(Keys.TESLA_LINKED)
        }
    }
}
