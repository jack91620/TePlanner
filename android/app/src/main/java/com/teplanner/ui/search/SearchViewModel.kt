package com.teplanner.ui.search

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.teplanner.map.PoiSearchManager
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class SearchUiState(
    val query: String = "",
    val results: List<SearchResult> = emptyList(),
    val isLoading: Boolean = false,
    val searchDone: Boolean = false,
    val error: String? = null
)

@HiltViewModel
class SearchViewModel @Inject constructor(
    private val poiSearchManager: PoiSearchManager
) : ViewModel() {

    private val _uiState = MutableStateFlow(SearchUiState())
    val uiState: StateFlow<SearchUiState> = _uiState.asStateFlow()

    private var searchJob: Job? = null

    fun onQueryChange(query: String) {
        _uiState.update { it.copy(query = query, searchDone = false) }

        // Cancel previous search
        searchJob?.cancel()

        if (query.isBlank()) {
            _uiState.update { it.copy(results = emptyList(), isLoading = false) }
            return
        }

        // Debounce search
        searchJob = viewModelScope.launch {
            delay(300) // 300ms debounce
            performSearch(query)
        }
    }

    fun search() {
        val query = _uiState.value.query
        if (query.isNotBlank()) {
            searchJob?.cancel()
            searchJob = viewModelScope.launch {
                performSearch(query)
            }
        }
    }

    private fun performSearch(query: String) {
        _uiState.update { it.copy(isLoading = true) }
        android.util.Log.d("SearchViewModel", "performSearch: query=$query")

        poiSearchManager.searchPOI(
            keyword = query,
            city = "", // Search in all cities
            onResult = { poiItems ->
                android.util.Log.d("SearchViewModel", "POI search returned ${poiItems.size} items")
                val results = poiItems.map { item ->
                    android.util.Log.d("SearchViewModel", "POI: ${item.title}, latLonPoint=${item.latLonPoint}, lat=${item.latLonPoint?.latitude}, lng=${item.latLonPoint?.longitude}")
                    SearchResult(
                        id = item.poiId ?: "",
                        name = item.title ?: "",
                        address = item.snippet ?: item.cityName ?: "",
                        latitude = item.latLonPoint?.latitude ?: 0.0,
                        longitude = item.latLonPoint?.longitude ?: 0.0,
                        distance = null // Distance not available for keyword search
                    )
                }
                android.util.Log.d("SearchViewModel", "Mapped ${results.size} results")
                _uiState.update {
                    it.copy(
                        results = results,
                        isLoading = false,
                        searchDone = true
                    )
                }
            },
            onError = { errorCode, errorMsg ->
                _uiState.update {
                    it.copy(
                        results = emptyList(),
                        isLoading = false,
                        searchDone = true,
                        error = errorMsg
                    )
                }
            }
        )
    }

    fun clearSearch() {
        searchJob?.cancel()
        _uiState.update {
            SearchUiState()
        }
    }
}
