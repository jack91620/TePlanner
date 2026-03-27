package com.teplanner.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.hilt.navigation.compose.hiltViewModel
import com.amap.api.maps.AMap
import com.amap.api.maps.CameraUpdateFactory
import com.amap.api.maps.MapView
import com.amap.api.maps.model.LatLng
import com.amap.api.maps.model.MyLocationStyle
import com.teplanner.R
import com.teplanner.data.model.ChargingStation
import com.teplanner.ui.components.*
import com.teplanner.ui.theme.*

@Composable
fun HomeScreen(
    onNavigateToSearch: () -> Unit,
    onNavigateToVehicleBinding: () -> Unit,
    onNavigateToProfile: () -> Unit,
    onNavigateToSettings: () -> Unit,
    selectedDestination: com.teplanner.ui.search.SearchResult? = null,
    viewModel: HomeViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsState()

    // Handle selected destination from search
    LaunchedEffect(selectedDestination) {
        if (selectedDestination != null) {
            android.util.Log.d("HomeScreen", "Processing destination: ${selectedDestination.name}, lat=${selectedDestination.latitude}, lng=${selectedDestination.longitude}")
            viewModel.setDestination(
                name = selectedDestination.name,
                latitude = selectedDestination.latitude,
                longitude = selectedDestination.longitude,
                address = selectedDestination.address
            )
        }
    }

    when {
        uiState.isLoading -> {
            LoadingScreen(message = "连接中...")
        }
        !uiState.vehicleConnected -> {
            LoginScreen(onConnectTesla = onNavigateToVehicleBinding)
        }
        else -> {
            ConnectedHomeContent(
                uiState = uiState,
                viewModel = viewModel,
                onNavigateToSearch = onNavigateToSearch,
                onNavigateToProfile = onNavigateToProfile
            )
        }
    }
}

@Composable
private fun ConnectedHomeContent(
    uiState: HomeUiState,
    viewModel: HomeViewModel,
    onNavigateToSearch: () -> Unit,
    onNavigateToProfile: () -> Unit
) {
    var panelState by remember { mutableStateOf(PanelState.HALF) }
    var activeTab by remember { mutableStateOf(HomeTab.NEARBY) }
    var activeFilter by remember { mutableStateOf(StationFilterType.SUPERCHARGER) }

    Box(modifier = Modifier.fillMaxSize()) {
        // Full Screen Map
        AMapView(
            modifier = Modifier.fillMaxSize(),
            onMapReady = { aMap -> viewModel.onMapReady(aMap) }
        )

        // Top Overlay
        TopOverlay(
            pageState = uiState.pageState,
            vehicleName = uiState.vehicleDisplayState?.displayName ?: "Tesla",
            isConnected = uiState.vehicleConnected,
            destinationName = null, // TODO: Add destination when in route preview
            onBackClick = { viewModel.cancelRoute() },
            onConnectionClick = onNavigateToProfile,
            modifier = Modifier
                .align(Alignment.TopCenter)
                .statusBarsPadding()
        )

        // Right Side Controls (top right corner)
        RightSideControls(
            onNavigationClick = onNavigateToSearch,
            onCenterClick = { viewModel.centerOnVehicle() },
            modifier = Modifier
                .align(Alignment.TopEnd)
                .statusBarsPadding()
                .padding(top = 56.dp, end = 16.dp)
        )

        // Bottom Draggable Panel
        if (uiState.pageState != HomePageState.SEARCHING) {
            DraggableBottomSheet(
                panelState = panelState,
                onStateChange = { panelState = it },
                collapsedHeight = 140.dp,
                halfHeight = 400.dp,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .navigationBarsPadding()
            ) {
                // Search Bar
                SearchBar(
                    placeholder = "搜索目的地",
                    onClick = onNavigateToSearch
                )

                Spacer(modifier = Modifier.height(16.dp))

                when (uiState.pageState) {
                    HomePageState.IDLE -> {
                        // Tabs
                        HomeTabRow(
                            selectedTab = activeTab,
                            onTabSelected = { activeTab = it }
                        )

                        Spacer(modifier = Modifier.height(8.dp))

                        when (activeTab) {
                            HomeTab.RECENT -> {
                                RecentTripsContent(
                                    recentTrips = uiState.recentTrips,
                                    onTripClick = { trip -> viewModel.navigateToTrip(trip) }
                                )
                            }
                            HomeTab.NEARBY -> {
                                NearbyStationsContent(
                                    activeFilter = activeFilter,
                                    onFilterChange = { activeFilter = it },
                                    stations = uiState.nearbyStations,
                                    isLoading = uiState.isLoadingStations,
                                    onStationClick = { station -> viewModel.navigateToStation(station) }
                                )
                            }
                        }
                    }
                    HomePageState.ROUTE_PREVIEW -> {
                        RoutePreviewContent(
                            routeData = uiState.routeData,
                            departureSOC = uiState.departureSOC,
                            onStartNavigation = { viewModel.startNavigation() },
                            onEditRoute = { viewModel.editRoute() },
                            onEditDepartureSOC = { viewModel.editDepartureSOC() },
                            onSendToVehicle = { viewModel.sendToVehicle() },
                            onCancel = { viewModel.cancelRoute() }
                        )
                    }
                    HomePageState.SEARCHING -> {
                        // Handled by search screen
                    }
                }
            }
        }
    }
}

@Composable
private fun AMapView(
    modifier: Modifier = Modifier,
    onMapReady: (AMap) -> Unit
) {
    var mapView by remember { mutableStateOf<MapView?>(null) }

    AndroidView(
        modifier = modifier,
        factory = { context ->
            // Wrap MapView in a FrameLayout that intercepts hover events
            // This fixes the Compose bug: "The ACTION_HOVER_EXIT event was not cleared"
            android.widget.FrameLayout(context).apply {
                // Intercept hover events to prevent Compose crash
                setOnHoverListener { _, event ->
                    // Consume all hover events to prevent the crash
                    when (event.action) {
                        android.view.MotionEvent.ACTION_HOVER_ENTER,
                        android.view.MotionEvent.ACTION_HOVER_MOVE,
                        android.view.MotionEvent.ACTION_HOVER_EXIT -> true
                        else -> false
                    }
                }

                val map = MapView(context).apply {
                    onCreate(null)
                    mapView = this

                    map.apply {
                        mapType = AMap.MAP_TYPE_NIGHT
                        uiSettings.apply {
                            isZoomControlsEnabled = false
                            isCompassEnabled = false
                            isScaleControlsEnabled = false
                            isMyLocationButtonEnabled = false
                        }
                        myLocationStyle = MyLocationStyle().apply {
                            myLocationType(MyLocationStyle.LOCATION_TYPE_LOCATION_ROTATE_NO_CENTER)
                            strokeColor(0x00000000)
                            radiusFillColor(0x00000000)
                        }
                        isMyLocationEnabled = true
                        moveCamera(CameraUpdateFactory.newLatLngZoom(LatLng(39.9042, 116.4074), 12f))
                        onMapReady(this)
                    }
                }
                addView(map, android.widget.FrameLayout.LayoutParams(
                    android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
                    android.widget.FrameLayout.LayoutParams.MATCH_PARENT
                ))
            }
        }
    )

    DisposableEffect(Unit) {
        onDispose { mapView?.onDestroy() }
    }
}

@Composable
private fun TopOverlay(
    pageState: HomePageState,
    vehicleName: String,
    isConnected: Boolean,
    destinationName: String?,
    onBackClick: () -> Unit,
    onConnectionClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Back Button (shown during route preview)
        if (pageState == HomePageState.ROUTE_PREVIEW) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(OverlayBackground)
                    .clickable(onClick = onBackClick),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    painter = painterResource(id = R.drawable.ic_back),
                    contentDescription = "Back",
                    tint = TextPrimary,
                    modifier = Modifier.size(18.dp)
                )
            }
        } else {
            Spacer(modifier = Modifier.width(36.dp))
        }

        // Location Name Badge (shown during route preview)
        if (pageState == HomePageState.ROUTE_PREVIEW && destinationName != null) {
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(4.dp))
                    .background(OverlayBackgroundDark)
                    .padding(horizontal = 12.dp, vertical = 6.dp)
            ) {
                Text(
                    text = destinationName,
                    color = TextPrimary,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium
                )
            }
        }

        // Connection Status
        Row(
            modifier = Modifier
                .clip(RoundedCornerShape(12.dp))
                .background(OverlayBackground)
                .clickable(onClick = onConnectionClick)
                .padding(horizontal = 10.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .background(
                        color = if (isConnected) StatusConnected else StatusDisconnected,
                        shape = CircleShape
                    )
            )
            Spacer(modifier = Modifier.width(6.dp))
            Text(
                text = vehicleName,
                color = TextPrimary,
                fontSize = 12.sp
            )
        }
    }
}

@Composable
private fun RightSideControls(
    onNavigationClick: () -> Unit,
    onCenterClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        ControlButton(
            iconRes = R.drawable.ic_route,
            contentDescription = "Navigation",
            onClick = onNavigationClick
        )
        ControlButton(
            iconRes = R.drawable.ic_location,
            contentDescription = "Center on vehicle",
            onClick = onCenterClick
        )
    }
}

@Composable
private fun ControlButton(
    iconRes: Int,
    contentDescription: String,
    onClick: () -> Unit
) {
    Box(
        modifier = Modifier
            .size(36.dp)
            .clip(RoundedCornerShape(8.dp))
            .background(OverlayBackground)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            painter = painterResource(id = iconRes),
            contentDescription = contentDescription,
            tint = TextPrimary,
            modifier = Modifier.size(18.dp)
        )
    }
}

@Composable
private fun RecentTripsContent(
    recentTrips: List<RecentTrip>,
    onTripClick: (RecentTrip) -> Unit
) {
    if (recentTrips.isEmpty()) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 30.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = "暂无最近行程",
                color = TextTertiary,
                fontSize = 14.sp
            )
        }
    } else {
        LazyColumn {
            item {
                Text(
                    text = "昨天",
                    color = TextTertiary,
                    fontSize = 12.sp,
                    modifier = Modifier.padding(vertical = 8.dp)
                )
            }
            items(recentTrips) { trip ->
                RecentTripItem(
                    name = trip.destinationName,
                    address = trip.destinationAddress,
                    distanceKm = trip.distanceKm,
                    onClick = { onTripClick(trip) }
                )
                Divider(color = DividerColor, thickness = 1.dp)
            }
        }
    }
}

@Composable
private fun NearbyStationsContent(
    activeFilter: StationFilterType,
    onFilterChange: (StationFilterType) -> Unit,
    stations: List<ChargingStation>,
    isLoading: Boolean,
    onStationClick: (ChargingStation) -> Unit
) {
    Column {
        StationFilter(
            activeFilter = activeFilter,
            onFilterChange = onFilterChange
        )

        if (isLoading) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 30.dp),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator(
                    modifier = Modifier.size(24.dp),
                    color = TeslaBlue,
                    strokeWidth = 2.dp
                )
            }
        } else if (stations.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 30.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "附近暂无充电站",
                    color = TextTertiary,
                    fontSize = 14.sp
                )
            }
        } else {
            LazyColumn {
                items(stations) { station ->
                    ChargingStationItem(
                        station = station,
                        onClick = { onStationClick(station) }
                    )
                    Divider(color = DividerColor, thickness = 1.dp)
                }
            }
        }
    }
}

@Composable
private fun RoutePreviewContent(
    routeData: RouteData?,
    departureSOC: Int,
    onStartNavigation: () -> Unit,
    onEditRoute: () -> Unit,
    onEditDepartureSOC: () -> Unit,
    onSendToVehicle: () -> Unit,
    onCancel: () -> Unit
) {
    Column(modifier = Modifier.fillMaxSize()) {
        // Header
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                modifier = Modifier
                    .clip(RoundedCornerShape(12.dp))
                    .background(DarkSurfaceVariant)
                    .clickable(onClick = onStartNavigation)
                    .padding(horizontal = 12.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "开始导航",
                    color = TextPrimary,
                    fontSize = 14.sp
                )
                Spacer(modifier = Modifier.width(4.dp))
                Text(
                    text = ">",
                    color = TextHint,
                    fontSize = 16.sp
                )
            }
            Text(
                text = "编辑路线",
                color = TeslaBlue,
                fontSize = 14.sp,
                modifier = Modifier.clickable(onClick = onEditRoute)
            )
        }

        // Route Stops - Scrollable
        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
        ) {
            // Origin
            RouteStopItem(
                type = RouteStopType.ORIGIN,
                name = "车辆位置",
                socPercent = departureSOC,
                onEditSOC = onEditDepartureSOC
            )

            // Charging Stops
            routeData?.chargingStops?.forEach { stop ->
                RouteStopItem(
                    type = RouteStopType.CHARGING,
                    name = stop.name,
                    socPercent = stop.arrivalSoc,
                    chargingMinutes = stop.chargingDuration
                )
            }

            // Destination
            routeData?.let {
                RouteStopItem(
                    type = RouteStopType.DESTINATION,
                    name = it.destinationName,
                    socPercent = it.arrivalSoc
                )
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Send to Vehicle Button
        Button(
            onClick = onSendToVehicle,
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp),
            shape = RoundedCornerShape(6.dp),
            colors = ButtonDefaults.buttonColors(containerColor = TeslaBlue)
        ) {
            Text(
                text = "发送到车辆  ${routeData?.totalDuration ?: "--"}  ${routeData?.totalDistanceKm ?: "--"} 公里",
                fontSize = 16.sp,
                fontWeight = FontWeight.Medium
            )
        }

        Spacer(modifier = Modifier.height(8.dp))

        // Cancel Button
        TextButton(
            onClick = onCancel,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(
                text = "取消",
                color = TextSecondary,
                fontSize = 15.sp
            )
        }
    }
}

enum class RouteStopType {
    ORIGIN, CHARGING, DESTINATION
}

@Composable
private fun RouteStopItem(
    type: RouteStopType,
    name: String,
    socPercent: Int?,
    chargingMinutes: Int? = null,
    onEditSOC: (() -> Unit)? = null
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 10.dp),
        verticalAlignment = Alignment.Top
    ) {
        // Icon
        Box(
            modifier = Modifier
                .size(22.dp)
                .background(
                    color = when (type) {
                        RouteStopType.ORIGIN -> DarkSurfaceVariant
                        RouteStopType.CHARGING -> TeslaRed
                        RouteStopType.DESTINATION -> androidx.compose.ui.graphics.Color.Transparent
                    },
                    shape = CircleShape
                ),
            contentAlignment = Alignment.Center
        ) {
            when (type) {
                RouteStopType.ORIGIN -> {
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .background(TextPrimary, CircleShape)
                    )
                }
                RouteStopType.CHARGING -> {
                    Icon(
                        painter = painterResource(id = R.drawable.ic_lightning),
                        contentDescription = null,
                        tint = TextPrimary,
                        modifier = Modifier.size(12.dp)
                    )
                }
                RouteStopType.DESTINATION -> {
                    Icon(
                        painter = painterResource(id = R.drawable.ic_destination_marker),
                        contentDescription = null,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }
        }

        Spacer(modifier = Modifier.width(10.dp))

        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = name,
                color = TextPrimary,
                fontSize = 15.sp
            )
            Spacer(modifier = Modifier.height(4.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                // Battery indicator
                socPercent?.let { soc ->
                    Box(
                        modifier = Modifier
                            .width(24.dp)
                            .height(10.dp)
                            .background(DarkSurfaceVariant, RoundedCornerShape(2.dp))
                    ) {
                        Box(
                            modifier = Modifier
                                .fillMaxHeight()
                                .fillMaxWidth(soc / 100f)
                                .background(BatteryHigh, RoundedCornerShape(2.dp))
                        )
                    }
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = "$soc%",
                        color = TextSecondary,
                        fontSize = 13.sp
                    )
                }

                if (type == RouteStopType.ORIGIN && onEditSOC != null) {
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = "设置出发电量",
                        color = TeslaBlue,
                        fontSize = 13.sp,
                        modifier = Modifier.clickable(onClick = onEditSOC)
                    )
                }

                chargingMinutes?.let { mins ->
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "${mins}分钟",
                        color = TextHint,
                        fontSize = 13.sp
                    )
                }
            }
        }
    }
}

// Data classes for UI state
enum class HomePageState { IDLE, SEARCHING, ROUTE_PREVIEW }

data class VehicleDisplayState(
    val displayName: String,
    val stateText: String,
    val batteryLevel: Int,
    val rangeKm: Int
)

data class RecentTrip(
    val id: String,
    val destinationName: String,
    val destinationAddress: String?,
    val latitude: Double,
    val longitude: Double,
    val distanceKm: Double
)

data class RouteData(
    val destinationName: String,
    val totalDistanceKm: Double,
    val totalDuration: String,
    val arrivalSoc: Int,
    val chargingStops: List<ChargingStopData>
)

data class ChargingStopData(
    val stationId: String,
    val name: String,
    val arrivalSoc: Int,
    val departureSoc: Int,
    val chargingDuration: Int
)
