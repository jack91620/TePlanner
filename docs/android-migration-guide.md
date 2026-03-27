# TePlanner 原生Android迁移指南

## 一、方案选择理由

| 对比项 | 原生Android | Flutter |
|--------|------------|---------|
| 沿途搜索充电站 | 原生支持 `TypeChargeStation` | 不支持，需后端多点搜索 |
| 高德SDK功能 | 完整功能 | 仅地图展示+定位 |
| 开发复杂度 | 直接调用SDK | 需要Web API或Platform Channel |

**结论**: 原生Android可直接使用高德SDK的沿途搜索充电站功能，开发更简单直接。

---

## 二、架构概览

```
Android App:
  ├── 地图展示 (高德Android SDK)
  ├── POI搜索 (高德搜索SDK)
  ├── Geocode (高德搜索SDK)
  ├── 驾车路线规划 (高德搜索SDK)
  ├── 沿途搜索充电站 (高德搜索SDK - RoutePOISearch)
  │
  └── 后端API调用
        ├── Tesla车辆API
        ├── 用户认证
        └── 充电规划算法(可选，可移到前端)

后端:
  ├── Tesla OAuth + 车辆控制
  ├── 用户认证
  └── 充电站数据库(补充高德数据)
```

---

## 三、技术栈

| 层级 | 技术选择 |
|------|---------|
| 语言 | Kotlin |
| UI框架 | Jetpack Compose |
| 架构 | MVVM + Clean Architecture |
| 依赖注入 | Hilt |
| 网络 | Retrofit + OkHttp |
| 异步 | Coroutines + Flow |
| 地图 | 高德地图SDK |
| 搜索 | 高德搜索SDK |
| 定位 | 高德定位SDK |
| 本地存储 | DataStore + Room |

---

## 四、高德SDK关键API

### 4.1 沿途搜索充电站

```kotlin
// RoutePOISearch - 核心功能
val query = RoutePOISearchQuery(
    startPoint,      // 起点
    endPoint,        // 终点
    RoutePOISearch.RoutePOISearchMode.DRIVING,
    RoutePOISearch.RoutePOISearchType.TypeChargeStation,  // 充电站
    250              // 搜索范围(米)
)
val search = RoutePOISearch(context, query)
search.setPolyline(polylinePoints)  // 设置路线点
search.searchRoutePOIAsyn()
```

### 4.2 支持的搜索类型

```kotlin
RoutePOISearchType.TypeChargeStation   // 充电站
RoutePOISearchType.TypeServiceArea     // 服务区
RoutePOISearchType.TypeGasStation      // 加油站
RoutePOISearchType.TypeFillingStation  // 加气站
RoutePOISearchType.TypeFood            // 美食
RoutePOISearchType.TypeHotel           // 酒店
RoutePOISearchType.TypeATM             // 自助银行
RoutePOISearchType.TypeMaintenanceStation // 维修站
RoutePOISearchType.TypeToilet          // 卫生间
```

### 4.3 驾车路线规划

```kotlin
val routeSearch = RouteSearch(context)
val fromAndTo = RouteSearch.FromAndTo(startPoint, endPoint)
val query = RouteSearch.DriveRouteQuery(
    fromAndTo,
    RouteSearch.DRIVING_SINGLE_DEFAULT,
    null,
    null,
    ""
)
routeSearch.calculateDriveRouteAsyn(query)
```

---

## 五、项目结构

```
app/
├── src/main/
│   ├── java/com/teplanner/
│   │   ├── TePlannerApp.kt              # Application
│   │   │
│   │   ├── di/                          # 依赖注入
│   │   │   ├── AppModule.kt
│   │   │   ├── NetworkModule.kt
│   │   │   └── MapModule.kt
│   │   │
│   │   ├── data/                        # 数据层
│   │   │   ├── model/
│   │   │   │   ├── Vehicle.kt
│   │   │   │   ├── VehicleState.kt
│   │   │   │   ├── ChargingStation.kt
│   │   │   │   ├── RoutePlan.kt
│   │   │   │   └── SearchResult.kt
│   │   │   ├── remote/
│   │   │   │   ├── BackendApi.kt        # 后端API接口
│   │   │   │   └── BackendApiImpl.kt
│   │   │   ├── local/
│   │   │   │   ├── SettingsDataStore.kt
│   │   │   │   └── HistoryDao.kt
│   │   │   └── repository/
│   │   │       ├── VehicleRepository.kt
│   │   │       ├── RouteRepository.kt
│   │   │       └── AuthRepository.kt
│   │   │
│   │   ├── domain/                      # 业务逻辑
│   │   │   ├── usecase/
│   │   │   │   ├── PlanRouteUseCase.kt
│   │   │   │   ├── SearchChargingStationsUseCase.kt
│   │   │   │   └── SendNavigationUseCase.kt
│   │   │   └── service/
│   │   │       └── ChargingPlannerService.kt
│   │   │
│   │   ├── ui/                          # 表现层
│   │   │   ├── theme/
│   │   │   │   ├── Theme.kt
│   │   │   │   └── Color.kt
│   │   │   ├── components/
│   │   │   │   ├── DraggableBottomSheet.kt
│   │   │   │   ├── SearchBar.kt
│   │   │   │   ├── ChargingStationItem.kt
│   │   │   │   ├── StationFilter.kt
│   │   │   │   └── BatteryIndicator.kt
│   │   │   ├── home/
│   │   │   │   ├── HomeScreen.kt
│   │   │   │   ├── HomeViewModel.kt
│   │   │   │   └── MapView.kt
│   │   │   ├── search/
│   │   │   │   ├── SearchScreen.kt
│   │   │   │   └── SearchViewModel.kt
│   │   │   ├── route/
│   │   │   │   ├── RoutePreviewSheet.kt
│   │   │   │   └── RouteViewModel.kt
│   │   │   ├── vehicle/
│   │   │   │   ├── VehicleBindingScreen.kt
│   │   │   │   └── VehicleViewModel.kt
│   │   │   ├── profile/
│   │   │   │   └── ProfileScreen.kt
│   │   │   └── settings/
│   │   │       └── SettingsScreen.kt
│   │   │
│   │   ├── map/                         # 高德地图封装
│   │   │   ├── AMapManager.kt           # 地图管理器
│   │   │   ├── RouteSearchManager.kt    # 路线搜索
│   │   │   ├── RoutePOISearchManager.kt # 沿途搜索
│   │   │   └── MarkerManager.kt         # 标记管理
│   │   │
│   │   └── util/
│   │       ├── CoordinateUtils.kt
│   │       └── FormatUtils.kt
│   │
│   ├── res/
│   │   ├── drawable/                    # 图标资源(从小程序迁移)
│   │   ├── values/
│   │   └── layout/
│   │
│   └── AndroidManifest.xml
│
├── build.gradle.kts
└── proguard-rules.pro
```

---

## 六、核心依赖

**build.gradle.kts (app)**

```kotlin
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.dagger.hilt.android")
    id("kotlin-kapt")
}

android {
    namespace = "com.teplanner"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.teplanner"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
    }

    buildFeatures {
        compose = true
    }

    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.8"
    }
}

dependencies {
    // Kotlin
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")

    // Jetpack Compose
    implementation(platform("androidx.compose:compose-bom:2024.01.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.activity:activity-compose:1.8.2")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.7.0")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.7.0")
    implementation("androidx.navigation:navigation-compose:2.7.6")

    // Hilt
    implementation("com.google.dagger:hilt-android:2.50")
    kapt("com.google.dagger:hilt-compiler:2.50")
    implementation("androidx.hilt:hilt-navigation-compose:1.1.0")

    // Network
    implementation("com.squareup.retrofit2:retrofit:2.9.0")
    implementation("com.squareup.retrofit2:converter-gson:2.9.0")
    implementation("com.squareup.okhttp3:logging-interceptor:4.12.0")

    // Storage
    implementation("androidx.datastore:datastore-preferences:1.0.0")
    implementation("androidx.room:room-runtime:2.6.1")
    implementation("androidx.room:room-ktx:2.6.1")
    kapt("androidx.room:room-compiler:2.6.1")

    // 高德地图SDK
    implementation("com.amap.api:3dmap:latest.integration")
    implementation("com.amap.api:search:latest.integration")
    implementation("com.amap.api:location:latest.integration")

    // WebView (Tesla OAuth)
    implementation("androidx.webkit:webkit:1.9.0")

    // Debug
    debugImplementation("androidx.compose.ui:ui-tooling")
}
```

---

## 七、AndroidManifest.xml 配置

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- 网络权限 -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />

    <!-- 定位权限 -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />

    <!-- 存储权限 -->
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />

    <application
        android:name=".TePlannerApp"
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:theme="@style/Theme.TePlanner">

        <!-- 高德地图 API Key -->
        <meta-data
            android:name="com.amap.api.v2.apikey"
            android:value="YOUR_AMAP_API_KEY" />

        <!-- 高德定位服务 -->
        <service android:name="com.amap.api.location.APSService" />

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:theme="@style/Theme.TePlanner">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

    </application>

</manifest>
```

---

## 八、API职责划分

### Android端 (高德SDK)

| 功能 | SDK/API |
|------|---------|
| 地图展示 | 3D地图SDK - MapView |
| POI搜索 | 搜索SDK - PoiSearch |
| Geocode | 搜索SDK - GeocodeSearch |
| 逆地理编码 | 搜索SDK - RegeocodeQuery |
| 驾车路线 | 搜索SDK - RouteSearch |
| **沿途搜索充电站** | **搜索SDK - RoutePOISearch** |
| 定位 | 定位SDK - AMapLocationClient |
| 输入提示 | 搜索SDK - InputtipsQuery |

### 后端API

| 功能 | 端点 | 说明 |
|------|------|------|
| Tesla OAuth | `GET /auth/tesla/authorize` | 获取OAuth URL |
| Tesla状态检查 | `GET /auth/tesla/status` | 检查绑定状态 |
| 车辆列表 | `GET /vehicles/` | 获取车辆列表 |
| 车辆状态 | `GET /vehicles/{id}/state` | 电量、位置 |
| 唤醒车辆 | `POST /vehicles/{id}/wake` | 唤醒离线车辆 |
| 发送导航 | `POST /vehicles/{id}/navigate` | 发送到车辆 |
| 用户登录 | `POST /auth/login` | 用户认证 |
| 用户注册 | `POST /auth/register` | 用户注册 |
| 充电站补充 | `GET /charging/stations/{id}` | 补充高德数据 |

---

## 九、后端接口变更

### 简化路线规划接口

由于沿途搜索在Android端完成，后端路线规划接口可简化：

**新增接口** (可选):

```
POST /routes/charging-plan

Request:
{
  "charging_stations": [
    {
      "id": "amap_poi_id",
      "name": "国家电网充电站",
      "lat": 39.9,
      "lng": 116.4,
      "distance_from_start_km": 200
    }
  ],
  "total_distance_km": 1200,
  "current_soc": 80,
  "vehicle_id": "tesla_vehicle_id"
}

Response:
{
  "recommended_stops": [
    {
      "station_id": "amap_poi_id",
      "charge_to_soc": 80,
      "charging_minutes": 25,
      "arrival_soc": 15
    }
  ],
  "final_arrival_soc": 25,
  "total_charging_time_minutes": 50
}
```

---

## 十、迁移步骤

### Phase 1: 项目搭建 (1-2天)

- [ ] 创建Android项目 (Kotlin + Compose)
- [ ] 配置Gradle依赖
- [ ] 配置Hilt依赖注入
- [ ] 申请高德API Key (https://lbs.amap.com/)
- [ ] 配置AndroidManifest.xml (权限、Key)
- [ ] 创建目录结构
- [ ] 配置深色主题

### Phase 2: 高德SDK集成 (2-3天)

- [ ] AMapManager - 地图初始化和生命周期管理
- [ ] RouteSearchManager - 驾车路线规划
- [ ] **RoutePOISearchManager - 沿途搜索充电站**
- [ ] PoiSearchManager - POI关键字搜索
- [ ] GeocodeManager - 地理编码
- [ ] MarkerManager - 标记管理
- [ ] 定位功能集成

### Phase 3: 数据层 (2天)

- [ ] 数据模型定义 (Vehicle, VehicleState, ChargingStation, etc.)
- [ ] BackendApi (Retrofit接口定义)
- [ ] Repository实现
- [ ] DataStore配置存储
- [ ] Room数据库 (历史记录)

### Phase 4: 核心页面 (4-5天)

- [ ] HomeScreen (地图+底部面板)
- [ ] DraggableBottomSheet组件
- [ ] 搜索功能 (SearchScreen)
- [ ] 路线规划和展示
- [ ] 沿途充电站展示
- [ ] RoutePreviewSheet

### Phase 5: Tesla集成 (2-3天)

- [ ] VehicleBindingScreen (WebView OAuth)
- [ ] 车辆状态展示
- [ ] 唤醒车辆功能
- [ ] 发送导航到车辆

### Phase 6: 次要页面 (2天)

- [ ] ProfileScreen
- [ ] SettingsScreen
- [ ] 充电站详情页

### Phase 7: 测试优化 (2-3天)

- [ ] 功能测试
- [ ] UI调整
- [ ] 性能优化
- [ ] 错误处理

---

## 十一、关键代码示例

### 11.1 沿途搜索充电站管理器

```kotlin
package com.teplanner.map

import android.content.Context
import com.amap.api.services.core.AMapException
import com.amap.api.services.core.LatLonPoint
import com.amap.api.services.routepoisearch.RoutePOIItem
import com.amap.api.services.routepoisearch.RoutePOISearch
import com.amap.api.services.routepoisearch.RoutePOISearchQuery
import com.amap.api.services.routepoisearch.RoutePOISearchResult
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class RoutePOISearchManager @Inject constructor(
    @ApplicationContext private val context: Context
) : RoutePOISearch.OnRoutePOISearchListener {

    private var onResultCallback: ((List<RoutePOIItem>) -> Unit)? = null
    private var onErrorCallback: ((Int) -> Unit)? = null

    /**
     * 沿途搜索充电站
     * @param polyline 路线点列表
     * @param range 搜索范围(米)，默认250米
     * @param onResult 结果回调
     * @param onError 错误回调
     */
    fun searchChargingStationsAlongRoute(
        polyline: List<LatLonPoint>,
        range: Int = 250,
        onResult: (List<RoutePOIItem>) -> Unit,
        onError: ((Int) -> Unit)? = null
    ) {
        if (polyline.size < 2) {
            onResult(emptyList())
            return
        }

        onResultCallback = onResult
        onErrorCallback = onError

        val query = RoutePOISearchQuery(
            polyline.first(),
            polyline.last(),
            RoutePOISearch.RoutePOISearchMode.DRIVING,
            RoutePOISearch.RoutePOISearchType.TypeChargeStation,
            range
        )

        val search = RoutePOISearch(context, query)
        search.setPolyline(polyline)
        search.setRoutePOISearchListener(this)
        search.searchRoutePOIAsyn()
    }

    /**
     * 沿途搜索服务区
     */
    fun searchServiceAreasAlongRoute(
        polyline: List<LatLonPoint>,
        range: Int = 250,
        onResult: (List<RoutePOIItem>) -> Unit
    ) {
        if (polyline.size < 2) {
            onResult(emptyList())
            return
        }

        onResultCallback = onResult

        val query = RoutePOISearchQuery(
            polyline.first(),
            polyline.last(),
            RoutePOISearch.RoutePOISearchMode.DRIVING,
            RoutePOISearch.RoutePOISearchType.TypeServiceArea,
            range
        )

        val search = RoutePOISearch(context, query)
        search.setPolyline(polyline)
        search.setRoutePOISearchListener(this)
        search.searchRoutePOIAsyn()
    }

    override fun onRoutePOISearched(result: RoutePOISearchResult?, errorCode: Int) {
        if (errorCode == AMapException.CODE_AMAP_SUCCESS && result != null) {
            onResultCallback?.invoke(result.routePois ?: emptyList())
        } else {
            onErrorCallback?.invoke(errorCode)
            onResultCallback?.invoke(emptyList())
        }
    }
}
```

### 11.2 路线规划ViewModel

```kotlin
package com.teplanner.ui.route

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.amap.api.services.core.LatLonPoint
import com.amap.api.services.routepoisearch.RoutePOIItem
import com.teplanner.data.model.ChargingStation
import com.teplanner.data.repository.RouteRepository
import com.teplanner.map.RoutePOISearchManager
import com.teplanner.map.RouteSearchManager
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class RouteUiState(
    val isLoading: Boolean = false,
    val origin: LatLonPoint? = null,
    val destination: LatLonPoint? = null,
    val destinationName: String = "",
    val polyline: List<LatLonPoint> = emptyList(),
    val chargingStations: List<RoutePOIItem> = emptyList(),
    val totalDistanceKm: Double = 0.0,
    val totalDurationMinutes: Int = 0,
    val error: String? = null
)

@HiltViewModel
class RouteViewModel @Inject constructor(
    private val routeSearchManager: RouteSearchManager,
    private val routePOISearchManager: RoutePOISearchManager,
    private val routeRepository: RouteRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(RouteUiState())
    val uiState: StateFlow<RouteUiState> = _uiState.asStateFlow()

    fun planRoute(
        origin: LatLonPoint,
        destination: LatLonPoint,
        destinationName: String
    ) {
        viewModelScope.launch {
            _uiState.update {
                it.copy(
                    isLoading = true,
                    error = null,
                    origin = origin,
                    destination = destination,
                    destinationName = destinationName
                )
            }

            // 1. 获取驾车路线
            routeSearchManager.searchDrivingRoute(
                origin = origin,
                destination = destination,
                onResult = { driveRouteResult ->
                    val path = driveRouteResult?.paths?.firstOrNull()
                    if (path != null) {
                        val polyline = path.steps.flatMap { it.polyline }
                        val distanceKm = path.distance / 1000.0
                        val durationMinutes = (path.duration / 60).toInt()

                        _uiState.update {
                            it.copy(
                                polyline = polyline,
                                totalDistanceKm = distanceKm,
                                totalDurationMinutes = durationMinutes
                            )
                        }

                        // 2. 沿途搜索充电站
                        searchChargingStations(polyline)
                    } else {
                        _uiState.update {
                            it.copy(isLoading = false, error = "路线规划失败")
                        }
                    }
                },
                onError = { errorCode ->
                    _uiState.update {
                        it.copy(isLoading = false, error = "路线规划失败: $errorCode")
                    }
                }
            )
        }
    }

    private fun searchChargingStations(polyline: List<LatLonPoint>) {
        routePOISearchManager.searchChargingStationsAlongRoute(
            polyline = polyline,
            range = 500,  // 道路两侧500米范围
            onResult = { stations ->
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        chargingStations = stations
                    )
                }
            },
            onError = { errorCode ->
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        chargingStations = emptyList(),
                        error = "充电站搜索失败: $errorCode"
                    )
                }
            }
        )
    }

    fun clearRoute() {
        _uiState.update { RouteUiState() }
    }
}
```

### 11.3 后端API接口

```kotlin
package com.teplanner.data.remote

import com.teplanner.data.model.*
import retrofit2.http.*

interface BackendApi {

    // ============ 认证 ============

    @POST("auth/login")
    suspend fun login(@Body request: LoginRequest): AuthResponse

    @POST("auth/register")
    suspend fun register(@Body request: RegisterRequest): AuthResponse

    @GET("auth/tesla/authorize")
    suspend fun getTeslaAuthUrl(): TeslaAuthUrlResponse

    @GET("auth/tesla/status")
    suspend fun checkTeslaStatus(): TeslaStatusResponse

    @POST("auth/tesla/unbind")
    suspend fun unbindTesla(): BaseResponse

    // ============ 车辆 ============

    @GET("vehicles/")
    suspend fun getVehicles(): List<Vehicle>

    @GET("vehicles/{id}/state")
    suspend fun getVehicleState(@Path("id") vehicleId: String): VehicleState

    @POST("vehicles/{id}/wake")
    suspend fun wakeVehicle(@Path("id") vehicleId: String): WakeResponse

    @POST("vehicles/{id}/navigate")
    suspend fun sendNavigation(
        @Path("id") vehicleId: String,
        @Body request: NavigationRequest
    ): BaseResponse

    // ============ 充电规划 ============

    @POST("routes/charging-plan")
    suspend fun getChargingPlan(@Body request: ChargingPlanRequest): ChargingPlanResponse

    @GET("charging/stations/{id}")
    suspend fun getStationDetail(@Path("id") stationId: String): ChargingStation
}
```

---

## 十二、后续iOS方案

完成Android版本后，iOS可选方案：

| 方案 | 优点 | 缺点 |
|------|------|------|
| Kotlin Multiplatform | 共享业务逻辑代码 | UI需重写SwiftUI |
| 原生Swift开发 | 最佳用户体验 | 完全重写代码 |
| Flutter (iOS only) | 快速开发 | 沿途搜索需后端多点方案 |

**建议**: 先完成Android版本验证核心功能，再决定iOS方案。

---

## 十三、关键参考文件

| Android文件 | 小程序参考 |
|------------|-----------|
| `BackendApi.kt` | `miniprogram/utils/api.js` |
| `HomeScreen.kt` | `miniprogram/pages/index/index.js` |
| `DraggableBottomSheet.kt` | `miniprogram/components/draggable-panel/` |
| `VehicleBindingScreen.kt` | `miniprogram/pages/vehicle-binding/` |
| `RoutePreviewSheet.kt` | `miniprogram/pages/route-result/` |

---

## 十四、资源链接

- [高德开放平台](https://lbs.amap.com/)
- [高德Android SDK文档](https://lbs.amap.com/api/android-sdk/summary/)
- [高德搜索SDK - 沿途搜索](https://lbs.amap.com/api/android-sdk/guide/map-data/route-poi-search)
- [Jetpack Compose文档](https://developer.android.com/jetpack/compose)
- [Hilt依赖注入](https://developer.android.com/training/dependency-injection/hilt-android)

---

*文档版本: 1.0*
*创建日期: 2026-01-07*
