package com.teplanner.ui.vehicle

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.gson.Gson
import com.google.gson.JsonObject
import com.teplanner.data.local.SettingsDataStore
import com.teplanner.data.remote.BackendApi
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class VehicleBindingUiState(
    val isLoading: Boolean = true,
    val authUrl: String? = null,
    val bindingSuccess: Boolean = false,
    val error: String? = null
)

@HiltViewModel
class VehicleBindingViewModel @Inject constructor(
    private val backendApi: BackendApi,
    private val settingsDataStore: SettingsDataStore
) : ViewModel() {

    private val _uiState = MutableStateFlow(VehicleBindingUiState())
    val uiState: StateFlow<VehicleBindingUiState> = _uiState.asStateFlow()

    private var expectedState: String? = null

    init {
        loadAuthUrl()
    }

    private fun loadAuthUrl() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }
            try {
                val response = backendApi.getTeslaAuthUrl()
                expectedState = response.state

                // Store user_id from backend response (backend creates anonymous user for Android)
                response.user_id?.let { userId ->
                    settingsDataStore.setUserId(userId.toString())
                    android.util.Log.d("VehicleBinding", "Stored user_id from backend: $userId")
                }

                _uiState.update {
                    it.copy(
                        isLoading = false,
                        authUrl = response.url
                    )
                }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        error = e.message ?: "Failed to load Tesla login"
                    )
                }
            }
        }
    }

    private var callbackProcessed = false
    private val gson = Gson()

    fun handleCallback(code: String, state: String, pageContent: String?) {
        // Prevent multiple callback processing
        if (callbackProcessed) {
            android.util.Log.d("VehicleBinding", "Callback already processed, ignoring")
            return
        }

        android.util.Log.d("VehicleBinding", "handleCallback called: code=$code, state=$state, expectedState=$expectedState, pageContent=$pageContent")

        // Verify state matches to prevent CSRF attacks
        if (state != expectedState) {
            android.util.Log.e("VehicleBinding", "State mismatch! expected=$expectedState, got=$state")
            _uiState.update {
                it.copy(error = "Security verification failed. Please try again.")
            }
            return
        }

        callbackProcessed = true
        android.util.Log.d("VehicleBinding", "State verified, processing callback response")

        viewModelScope.launch {
            // Try to parse auth token and user_id from page content
            var authToken: String? = null
            var userId: String? = null

            if (pageContent != null && pageContent.isNotBlank()) {
                try {
                    // Try to parse as JSON
                    val jsonContent = pageContent.trim()
                    if (jsonContent.startsWith("{")) {
                        val json = gson.fromJson(jsonContent, JsonObject::class.java)
                        // Look for common token field names
                        authToken = json.get("token")?.asString
                            ?: json.get("access_token")?.asString
                            ?: json.get("auth_token")?.asString
                        // Look for user_id
                        userId = json.get("user_id")?.asString
                            ?: json.get("userId")?.asString
                        android.util.Log.d("VehicleBinding", "Parsed from JSON: authToken=$authToken, userId=$userId")
                    }
                } catch (e: Exception) {
                    android.util.Log.e("VehicleBinding", "Failed to parse page content as JSON: ${e.message}")
                }
            }

            // Store auth token if found
            if (authToken != null) {
                settingsDataStore.setAuthToken(authToken)
                android.util.Log.d("VehicleBinding", "Auth token stored successfully")
            }

            // Store user_id if found
            if (userId != null) {
                settingsDataStore.setUserId(userId)
                android.util.Log.d("VehicleBinding", "User ID stored successfully: $userId")
            } else {
                android.util.Log.d("VehicleBinding", "No user_id found in response")
            }

            // Mark Tesla as linked
            settingsDataStore.setTeslaLinked(true)
            _uiState.update { it.copy(bindingSuccess = true, isLoading = false) }
            android.util.Log.d("VehicleBinding", "Binding success!")
        }
    }

    fun retry() {
        loadAuthUrl()
    }

    fun onNavigationComplete() {
        _uiState.update { it.copy(bindingSuccess = false) }
    }
}
