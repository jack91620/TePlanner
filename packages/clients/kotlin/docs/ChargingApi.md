# ChargingApi

All URIs are relative to *http://localhost*

| Method | HTTP request | Description |
| ------------- | ------------- | ------------- |
| [**getStationApiV1ChargingStationsStationIdGet**](ChargingApi.md#getStationApiV1ChargingStationsStationIdGet) | **GET** api/v1/charging/stations/{station_id} | Get Station |
| [**searchNearbyStationsApiV1ChargingNearbyGet**](ChargingApi.md#searchNearbyStationsApiV1ChargingNearbyGet) | **GET** api/v1/charging/nearby | Search Nearby Stations |
| [**searchStationsApiV1ChargingStationsGet**](ChargingApi.md#searchStationsApiV1ChargingStationsGet) | **GET** api/v1/charging/stations | Search Stations |



Get Station

获取充电站详情.  Args:     station_id: 充电站ID

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
val webService = apiClient.createWebservice(ChargingApi::class.java)
val stationId : kotlin.String = stationId_example // kotlin.String | 

launch(Dispatchers.IO) {
    val result : ChargingStation = webService.getStationApiV1ChargingStationsStationIdGet(stationId)
}
```

### Parameters
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **stationId** | **kotlin.String**|  | |

### Return type

[**ChargingStation**](ChargingStation.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json


Search Nearby Stations

搜索附近充电站 (前端兼容接口).  Args:     latitude: 中心点纬度     longitude: 中心点经度     type: 充电站类型     radius: 搜索半径，默认50公里

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
val webService = apiClient.createWebservice(ChargingApi::class.java)
val latitude : java.math.BigDecimal = 8.14 // java.math.BigDecimal | 中心点纬度
val longitude : java.math.BigDecimal = 8.14 // java.math.BigDecimal | 中心点经度
val type : kotlin.String = type_example // kotlin.String | 类型: supercharger/destination/service/all
val radius : java.math.BigDecimal = 8.14 // java.math.BigDecimal | 搜索半径(公里)

launch(Dispatchers.IO) {
    val result : StationSearchResponse = webService.searchNearbyStationsApiV1ChargingNearbyGet(latitude, longitude, type, radius)
}
```

### Parameters
| **latitude** | **java.math.BigDecimal**| 中心点纬度 | |
| **longitude** | **java.math.BigDecimal**| 中心点经度 | |
| **type** | **kotlin.String**| 类型: supercharger/destination/service/all | [optional] |
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **radius** | **java.math.BigDecimal**| 搜索半径(公里) | [optional] [default to 50] |

### Return type

[**StationSearchResponse**](StationSearchResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json


Search Stations

搜索附近充电站.  Args:     lat: 中心点纬度     lng: 中心点经度     radius_km: 搜索半径，默认10公里     min_power_kw: 最小充电功率筛选     operator: 运营商筛选

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
val webService = apiClient.createWebservice(ChargingApi::class.java)
val lat : java.math.BigDecimal = 8.14 // java.math.BigDecimal | 中心点纬度
val lng : java.math.BigDecimal = 8.14 // java.math.BigDecimal | 中心点经度
val radiusKm : java.math.BigDecimal = 8.14 // java.math.BigDecimal | 搜索半径(公里)
val minPowerKw : kotlin.Int = 56 // kotlin.Int | 最小充电功率(kW)
val `operator` : kotlin.String = `operator`_example // kotlin.String | 运营商筛选

launch(Dispatchers.IO) {
    val result : StationSearchResponse = webService.searchStationsApiV1ChargingStationsGet(lat, lng, radiusKm, minPowerKw, `operator`)
}
```

### Parameters
| **lat** | **java.math.BigDecimal**| 中心点纬度 | |
| **lng** | **java.math.BigDecimal**| 中心点经度 | |
| **radiusKm** | **java.math.BigDecimal**| 搜索半径(公里) | [optional] [default to 10] |
| **minPowerKw** | **kotlin.Int**| 最小充电功率(kW) | [optional] |
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **&#x60;operator&#x60;** | **kotlin.String**| 运营商筛选 | [optional] |

### Return type

[**StationSearchResponse**](StationSearchResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

