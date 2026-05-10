package cloud.teplanner.android.map

import android.os.Bundle
import android.util.Log
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material.icons.filled.Route
import androidx.compose.material3.BottomSheetScaffold
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SheetValue
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberBottomSheetScaffoldState
import androidx.compose.material3.rememberStandardBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import cloud.teplanner.android.hub.HubViewModel
import com.amap.api.maps.AMap
import com.amap.api.maps.CameraUpdateFactory
import com.amap.api.maps.MapView
import com.amap.api.maps.MapsInitializer
import com.amap.api.maps.model.BitmapDescriptorFactory
import com.amap.api.maps.model.LatLng
import com.amap.api.maps.model.MarkerOptions
import com.amap.api.services.core.ServiceSettings

/**
 * Phase F.3.1 — Compose-friendly AMap MapView wrapper.
 *
 * Mirrors the iOS `AMapVehicleMapView` (UIViewRepresentable). Vehicle
 * marker comes from the shared `HubViewModel.state` so opening the
 * map doesn't re-fetch — Hub's snapshot drives the initial camera +
 * marker. F.3.2 adds nearby chargers; F.3.3 adds polyline + stop pins.
 *
 * AMap MapView is an Android `View` with its own lifecycle hooks
 * (`onCreate/onResume/onPause/onDestroy/onSaveInstanceState`); we
 * mirror those off the host Activity's lifecycle via
 * [LifecycleEventObserver]. Without this the map renders a black
 * tile + leaks Surface backings.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MapScreen(
    onBack: () -> Unit,
    onPlanRoute: () -> Unit,
    hubVm: HubViewModel = hiltViewModel(),
    nearbyVm: NearbyChargersViewModel = hiltViewModel(),
) {
    val hubState by hubVm.state.collectAsState()
    val nearbyState by nearbyVm.state.collectAsState()
    val vehicleLatLng = hubState.vehicleState?.let { vs ->
        val lat = vs.latitude
        val lng = vs.longitude
        if (lat != null && lng != null) LatLng(lat, lng) else null
    }
    val cameraTarget = vehicleLatLng ?: DEFAULT_CAMERA

    androidx.compose.runtime.LaunchedEffect(cameraTarget) {
        nearbyVm.setCenter(cameraTarget.latitude, cameraTarget.longitude)
    }

    val sheetState = rememberStandardBottomSheetState(
        initialValue = SheetValue.PartiallyExpanded,
    )
    val scaffoldState = rememberBottomSheetScaffoldState(bottomSheetState = sheetState)

    BottomSheetScaffold(
        scaffoldState = scaffoldState,
        sheetPeekHeight = 220.dp,
        topBar = {
            TopAppBar(
                title = { Text("充电规划") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "返回")
                    }
                },
            )
        },
        sheetContent = {
            NearbyChargersSheet(
                state = nearbyState,
                onFilterChange = { nearbyVm.setFilter(it) },
                onSelect = { st ->
                    aMapRef.value?.animateCamera(
                        CameraUpdateFactory.newLatLngZoom(
                            LatLng(st.latitude, st.longitude), 16f
                        )
                    )
                },
                modifier = Modifier.fillMaxSize(),
            )
        },
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            AMapHost(
                initialTarget = cameraTarget,
                vehicleLatLng = vehicleLatLng,
                stations = nearbyState.stations,
            )
            Column(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                FloatingActionButton(onClick = {
                    vehicleLatLng?.let { latLng ->
                        aMapRef.value?.animateCamera(
                            CameraUpdateFactory.newLatLngZoom(latLng, 15f)
                        )
                    }
                }) {
                    Icon(Icons.Default.MyLocation, "回到车辆位置")
                }
                FloatingActionButton(onClick = onPlanRoute) {
                    Icon(Icons.Default.Route, "规划路线")
                }
            }
        }
    }
}

private val aMapRef = androidx.compose.runtime.mutableStateOf<AMap?>(null)
private val DEFAULT_CAMERA = LatLng(39.9087, 116.3975)

@Composable
private fun AMapHost(
    initialTarget: LatLng,
    vehicleLatLng: LatLng?,
    stations: List<cloud.teplanner.android.core.network.ChargingStation> = emptyList(),
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
            Log.w("MapScreen", "MapView init failed (likely AMap key invalid)", t)
            null
        }
    }
    if (mapView == null) {
        Column(
            modifier = Modifier.fillMaxSize().padding(24.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text("地图初始化失败", style = androidx.compose.material3.MaterialTheme.typography.titleMedium)
            Text("请检查高德地图 Android key 是否绑定当前签名 SHA1 + 包名",
                 style = androidx.compose.material3.MaterialTheme.typography.bodySmall)
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
                Log.w("MapScreen", "MapView lifecycle event $event failed", t)
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
            // mapView.onDestroy() routinely crashes the native GL thread
            // when the AMap key never validated. We deliberately do NOT
            // call it — Android tears the surface down on activity exit
            // anyway. Trade-off: a small native handle leak per
            // navigate-away when the key is bad. Once the key is
            // validated, restore the explicit destroy.
            aMapRef.value = null
        }
    }

    AndroidView(
        factory = { mapView },
        modifier = Modifier.fillMaxSize(),
        update = { view ->
            val aMap = view.map
            aMapRef.value = aMap
            aMap.uiSettings.isZoomControlsEnabled = false
            aMap.uiSettings.isCompassEnabled = true
            aMap.moveCamera(CameraUpdateFactory.newLatLngZoom(initialTarget, 13f))
            aMap.clear()
            vehicleLatLng?.let { latLng ->
                aMap.addMarker(
                    MarkerOptions()
                        .position(latLng)
                        .title("我的特斯拉")
                        .icon(BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_AZURE))
                )
            }
            stations.forEach { st ->
                aMap.addMarker(
                    MarkerOptions()
                        .position(LatLng(st.latitude, st.longitude))
                        .title(st.name)
                        .snippet(st.address)
                        .icon(BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_GREEN))
                )
            }
        },
    )
}
