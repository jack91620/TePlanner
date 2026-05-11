package cloud.teplanner.android.automations

import android.os.Bundle
import android.util.Log
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import cloud.teplanner.android.core.network.PlaceResult
import cloud.teplanner.android.core.network.RoutesApi
import cloud.teplanner.android.util.CoordConverter
import com.amap.api.maps.AMap
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.amap.api.maps.CameraUpdateFactory
import com.amap.api.maps.MapView
import com.amap.api.maps.MapsInitializer
import com.amap.api.maps.model.CircleOptions
import com.amap.api.maps.model.LatLng
import com.amap.api.services.core.ServiceSettings

@HiltViewModel
class GeofenceSearchViewModel @Inject constructor(
    private val routesApi: RoutesApi,
) : ViewModel() {
    data class State(
        val results: List<PlaceResult> = emptyList(),
        val isSearching: Boolean = false,
        val error: String? = null,
    )

    private val _state = MutableStateFlow(State())
    val state: StateFlow<State> = _state.asStateFlow()

    fun search(keyword: String) {
        val q = keyword.trim()
        if (q.isEmpty()) {
            _state.update { State() }
            return
        }
        _state.update { it.copy(isSearching = true) }
        viewModelScope.launch {
            runCatching { routesApi.searchPlaces(keyword = q) }
                .onSuccess { resp ->
                    _state.update {
                        State(results = resp.results.take(8), isSearching = false)
                    }
                }
                .onFailure { err ->
                    _state.update {
                        it.copy(isSearching = false, error = err.message)
                    }
                }
        }
    }

    fun clear() = _state.update { State() }
}


/**
 * Mirror of iOS GeofenceMapPickerSheet. Pan the map to move the
 * screen-center pin; the green circle overlay tracks the radius
 * slider. Save returns lat / lng (WGS-84) + radius_m to the caller.
 *
 * Coordinate convention follows the rest of the codebase:
 *   - Backend stores WGS-84 (Tesla raw GPS native).
 *   - AMap renders GCJ-02.
 *   - Convert at the AMap ⇄ caller boundary.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GeofencePickerScreen(
    initialLat: Double?,
    initialLng: Double?,
    initialRadiusM: Int,
    onCancel: () -> Unit,
    onConfirm: (lat: Double, lng: Double, radiusM: Int) -> Unit,
    searchVm: GeofenceSearchViewModel = hiltViewModel(),
) {
    val searchState by searchVm.state.collectAsState()
    var searchText by remember { mutableStateOf("") }
    val keyboardController = LocalSoftwareKeyboardController.current
    // External pan-to-result token: when a search hit is tapped we
    // bump this to a new GCJ-02 coord so the map host re-centers.
    var externalRecenter by remember { mutableStateOf<LatLng?>(null) }
    var radiusM by remember { mutableIntStateOf(initialRadiusM.coerceIn(50, 2000)) }
    // Map center in GCJ-02 (display coords). Default to Tiananmen if
    // no initial — same as iOS picker default.
    val seededGcj = remember {
        val wgs = if (initialLat != null && initialLng != null) {
            CoordConverter.LatLng(initialLat, initialLng)
        } else {
            CoordConverter.LatLng(39.9042, 116.4074)
        }
        CoordConverter.wgs84ToGcj02(wgs).let { LatLng(it.lat, it.lng) }
    }
    var centerGcj by remember { mutableStateOf(seededGcj) }
    var addressLabel by remember { mutableStateOf("拖动地图调整中心") }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("选择地点") },
                navigationIcon = {
                    IconButton(onClick = onCancel) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "取消")
                    }
                },
                actions = {
                    TextButton(
                        onClick = {
                            // Convert back to WGS-84 at the boundary.
                            val wgs = CoordConverter.gcj02ToWgs84(
                                CoordConverter.LatLng(centerGcj.latitude, centerGcj.longitude)
                            )
                            onConfirm(wgs.lat, wgs.lng, radiusM)
                        },
                        modifier = Modifier.testTag("geofence_save_button"),
                    ) { Text("使用此位置") }
                },
            )
        },
    ) { padding ->
        Box(
            modifier = Modifier
                .padding(padding)
                .fillMaxSize()
                .testTag("geofence_picker_view"),
        ) {
            GeofenceMapHost(
                initialCenter = seededGcj,
                externalRecenter = externalRecenter,
                radiusM = radiusM,
                onCenterChanged = { newCenter ->
                    centerGcj = newCenter
                    addressLabel = "%.5f, %.5f".format(newCenter.latitude, newCenter.longitude)
                },
            )

            // Fixed center pin — visual anchor.
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center,
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(
                        Icons.Filled.LocationOn,
                        contentDescription = null,
                        tint = Color(0xFF388E3C),
                        modifier = Modifier.size(36.dp),
                    )
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .background(Color(0xFF388E3C).copy(alpha = 0.5f), CircleShape),
                    )
                }
            }

            // Top stack — search bar + address banner + results.
            Column(
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .padding(12.dp)
                    .fillMaxWidth(0.95f),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Card(
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.95f),
                    ),
                    shape = RoundedCornerShape(12.dp),
                ) {
                    OutlinedTextField(
                        value = searchText,
                        onValueChange = {
                            searchText = it
                            if (it.isBlank()) searchVm.clear()
                        },
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(8.dp)
                            .testTag("geofence_search_field"),
                        placeholder = { Text("搜索地址 / POI 名称") },
                        leadingIcon = {
                            if (searchState.isSearching) {
                                CircularProgressIndicator(
                                    modifier = Modifier.size(18.dp),
                                    strokeWidth = 2.dp,
                                )
                            } else {
                                Icon(Icons.Filled.Search, null)
                            }
                        },
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                        keyboardActions = KeyboardActions(
                            onSearch = {
                                keyboardController?.hide()
                                searchVm.search(searchText)
                            },
                        ),
                    )
                }

                Card(
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.9f),
                    ),
                    shape = RoundedCornerShape(12.dp),
                ) {
                    Row(
                        modifier = Modifier.padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(
                            Icons.Filled.LocationOn,
                            contentDescription = null,
                            tint = Color(0xFF388E3C),
                            modifier = Modifier.size(18.dp),
                        )
                        Text(
                            addressLabel,
                            style = MaterialTheme.typography.bodySmall,
                            modifier = Modifier.padding(start = 8.dp),
                        )
                    }
                }

                if (searchState.results.isNotEmpty()) {
                    Card(
                        colors = CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.95f),
                        ),
                        shape = RoundedCornerShape(12.dp),
                    ) {
                        Column {
                            searchState.results.forEach { poi ->
                                PoiResultRow(
                                    poi = poi,
                                    onTap = {
                                        // Backend returns WGS-84; map shows
                                        // GCJ-02. Convert at boundary, same
                                        // as the initial-seed path.
                                        val gcj = CoordConverter.wgs84ToGcj02(
                                            CoordConverter.LatLng(poi.latitude, poi.longitude),
                                        )
                                        externalRecenter = LatLng(gcj.lat, gcj.lng)
                                        addressLabel = poi.address?.takeIf { it.isNotBlank() }
                                            ?.let { "${poi.name} · $it" } ?: poi.name
                                        searchVm.clear()
                                        searchText = ""
                                    },
                                )
                            }
                        }
                    }
                }
            }

            // Radius slider — bottom.
            Card(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(12.dp)
                    .fillMaxWidth(0.95f),
                shape = RoundedCornerShape(16.dp),
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("范围", modifier = Modifier.weight(1f))
                        Text("$radiusM m", style = MaterialTheme.typography.titleSmall)
                    }
                    Slider(
                        value = radiusM.toFloat(),
                        onValueChange = { v -> radiusM = (v / 50f).toInt() * 50 },
                        valueRange = 50f..2000f,
                        steps = ((2000 - 50) / 50) - 1,
                        modifier = Modifier.testTag("geofence_radius_slider"),
                    )
                }
            }
        }
    }
}


@Composable
private fun PoiResultRow(poi: PlaceResult, onTap: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onTap)
            .padding(12.dp),
    ) {
        Text(poi.name, style = MaterialTheme.typography.bodyMedium)
        poi.address?.takeIf { it.isNotBlank() }?.let {
            Text(
                it,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}


@Composable
private fun GeofenceMapHost(
    initialCenter: LatLng,
    externalRecenter: LatLng?,
    radiusM: Int,
    onCenterChanged: (LatLng) -> Unit,
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current

    val mapView = remember {
        try {
            MapsInitializer.updatePrivacyShow(context, true, true)
            MapsInitializer.updatePrivacyAgree(context, true)
            ServiceSettings.updatePrivacyShow(context, true, true)
            ServiceSettings.updatePrivacyAgree(context, true)
            MapView(context).apply { onCreate(Bundle()) }
        } catch (t: Throwable) {
            Log.w("GeofencePicker", "MapView init failed", t)
            null
        }
    }

    if (mapView == null) {
        Surface(modifier = Modifier.fillMaxSize()) {
            Column(
                modifier = Modifier.fillMaxSize().padding(24.dp),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text("地图初始化失败")
            }
        }
        return
    }

    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            try {
                when (event) {
                    Lifecycle.Event.ON_RESUME -> mapView.onResume()
                    Lifecycle.Event.ON_PAUSE -> mapView.onPause()
                    else -> Unit
                }
            } catch (t: Throwable) {
                Log.w("GeofencePicker", "lifecycle $event failed", t)
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    AndroidView(
        factory = { mapView },
        modifier = Modifier.fillMaxSize(),
        update = { view ->
            val map = view.map
            map.uiSettings.isZoomControlsEnabled = false
            map.uiSettings.isCompassEnabled = false
            // Pan to whatever the latest "external" recenter requested
            // (initial seed, or a POI tap), then let the camera
            // listener take over from there.
            val target = externalRecenter ?: initialCenter
            map.moveCamera(CameraUpdateFactory.newLatLngZoom(target, 15f))
            map.setOnCameraChangeListener(object : AMap.OnCameraChangeListener {
                override fun onCameraChange(p: com.amap.api.maps.model.CameraPosition?) {}
                override fun onCameraChangeFinish(p: com.amap.api.maps.model.CameraPosition?) {
                    p?.target?.let { onCenterChanged(it) }
                    // Re-draw circle at new center
                    map.clear()
                    p?.target?.let {
                        map.addCircle(
                            CircleOptions()
                                .center(it)
                                .radius(radiusM.toDouble())
                                .fillColor(android.graphics.Color.argb(46, 76, 175, 80))
                                .strokeColor(android.graphics.Color.argb(165, 56, 142, 60))
                                .strokeWidth(3f),
                        )
                    }
                }
            })
            // Initial circle
            map.clear()
            map.addCircle(
                CircleOptions()
                    .center(initialCenter)
                    .radius(radiusM.toDouble())
                    .fillColor(android.graphics.Color.argb(46, 76, 175, 80))
                    .strokeColor(android.graphics.Color.argb(165, 56, 142, 60))
                    .strokeWidth(3f),
            )
        },
    )
}
