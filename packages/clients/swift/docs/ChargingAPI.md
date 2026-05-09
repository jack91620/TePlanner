# ChargingAPI

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getStationApiV1ChargingStationsStationIdGet**](ChargingAPI.md#getstationapiv1chargingstationsstationidget) | **GET** /api/v1/charging/stations/{station_id} | Get Station
[**searchNearbyStationsApiV1ChargingNearbyGet**](ChargingAPI.md#searchnearbystationsapiv1chargingnearbyget) | **GET** /api/v1/charging/nearby | Search Nearby Stations
[**searchStationsApiV1ChargingStationsGet**](ChargingAPI.md#searchstationsapiv1chargingstationsget) | **GET** /api/v1/charging/stations | Search Stations


# **getStationApiV1ChargingStationsStationIdGet**
```swift
    open class func getStationApiV1ChargingStationsStationIdGet(stationId: String, completion: @escaping (_ data: ChargingStation?, _ error: Error?) -> Void)
```

Get Station

获取充电站详情.  Args:     station_id: 充电站ID

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let stationId = "stationId_example" // String | 

// Get Station
ChargingAPI.getStationApiV1ChargingStationsStationIdGet(stationId: stationId) { (response, error) in
    guard error == nil else {
        print(error)
        return
    }

    if (response) {
        dump(response)
    }
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **stationId** | **String** |  | 

### Return type

[**ChargingStation**](ChargingStation.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **searchNearbyStationsApiV1ChargingNearbyGet**
```swift
    open class func searchNearbyStationsApiV1ChargingNearbyGet(latitude: Double, longitude: Double, type: String? = nil, radius: Double? = nil, completion: @escaping (_ data: StationSearchResponse?, _ error: Error?) -> Void)
```

Search Nearby Stations

搜索附近充电站 (前端兼容接口).  Args:     latitude: 中心点纬度     longitude: 中心点经度     type: 充电站类型     radius: 搜索半径，默认50公里

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let latitude = 987 // Double | 中心点纬度
let longitude = 987 // Double | 中心点经度
let type = "type_example" // String | 类型: supercharger/destination/service/all (optional)
let radius = 987 // Double | 搜索半径(公里) (optional) (default to 50)

// Search Nearby Stations
ChargingAPI.searchNearbyStationsApiV1ChargingNearbyGet(latitude: latitude, longitude: longitude, type: type, radius: radius) { (response, error) in
    guard error == nil else {
        print(error)
        return
    }

    if (response) {
        dump(response)
    }
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **latitude** | **Double** | 中心点纬度 | 
 **longitude** | **Double** | 中心点经度 | 
 **type** | **String** | 类型: supercharger/destination/service/all | [optional] 
 **radius** | **Double** | 搜索半径(公里) | [optional] [default to 50]

### Return type

[**StationSearchResponse**](StationSearchResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **searchStationsApiV1ChargingStationsGet**
```swift
    open class func searchStationsApiV1ChargingStationsGet(lat: Double, lng: Double, radiusKm: Double? = nil, minPowerKw: Int? = nil, _operator: String? = nil, completion: @escaping (_ data: StationSearchResponse?, _ error: Error?) -> Void)
```

Search Stations

搜索附近充电站.  Args:     lat: 中心点纬度     lng: 中心点经度     radius_km: 搜索半径，默认10公里     min_power_kw: 最小充电功率筛选     operator: 运营商筛选

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let lat = 987 // Double | 中心点纬度
let lng = 987 // Double | 中心点经度
let radiusKm = 987 // Double | 搜索半径(公里) (optional) (default to 10)
let minPowerKw = 987 // Int | 最小充电功率(kW) (optional)
let _operator = "_operator_example" // String | 运营商筛选 (optional)

// Search Stations
ChargingAPI.searchStationsApiV1ChargingStationsGet(lat: lat, lng: lng, radiusKm: radiusKm, minPowerKw: minPowerKw, _operator: _operator) { (response, error) in
    guard error == nil else {
        print(error)
        return
    }

    if (response) {
        dump(response)
    }
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **lat** | **Double** | 中心点纬度 | 
 **lng** | **Double** | 中心点经度 | 
 **radiusKm** | **Double** | 搜索半径(公里) | [optional] [default to 10]
 **minPowerKw** | **Int** | 最小充电功率(kW) | [optional] 
 **_operator** | **String** | 运营商筛选 | [optional] 

### Return type

[**StationSearchResponse**](StationSearchResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

