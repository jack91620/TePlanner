# ChargingApi

All URIs are relative to *http://localhost*

| Method | HTTP request | Description |
|------------- | ------------- | -------------|
| [**getStationApiV1ChargingStationsStationIdGet**](ChargingApi.md#getstationapiv1chargingstationsstationidget) | **GET** /api/v1/charging/stations/{station_id} | Get Station |
| [**searchNearbyStationsApiV1ChargingNearbyGet**](ChargingApi.md#searchnearbystationsapiv1chargingnearbyget) | **GET** /api/v1/charging/nearby | Search Nearby Stations |
| [**searchStationsApiV1ChargingStationsGet**](ChargingApi.md#searchstationsapiv1chargingstationsget) | **GET** /api/v1/charging/stations | Search Stations |



## getStationApiV1ChargingStationsStationIdGet

> ChargingStation getStationApiV1ChargingStationsStationIdGet(stationId)

Get Station

获取充电站详情.  Args:     station_id: 充电站ID

### Example

```ts
import {
  Configuration,
  ChargingApi,
} from '@teplanner/sdk';
import type { GetStationApiV1ChargingStationsStationIdGetRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const api = new ChargingApi();

  const body = {
    // string
    stationId: stationId_example,
  } satisfies GetStationApiV1ChargingStationsStationIdGetRequest;

  try {
    const data = await api.getStationApiV1ChargingStationsStationIdGet(body);
    console.log(data);
  } catch (error) {
    console.error(error);
  }
}

// Run the test
example().catch(console.error);
```

### Parameters


| Name | Type | Description  | Notes |
|------------- | ------------- | ------------- | -------------|
| **stationId** | `string` |  | [Defaults to `undefined`] |

### Return type

[**ChargingStation**](ChargingStation.md)

### Authorization

No authorization required

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: `application/json`


### HTTP response details
| Status code | Description | Response headers |
|-------------|-------------|------------------|
| **200** | Successful Response |  -  |
| **422** | Validation Error |  -  |

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


## searchNearbyStationsApiV1ChargingNearbyGet

> StationSearchResponse searchNearbyStationsApiV1ChargingNearbyGet(latitude, longitude, type, radius)

Search Nearby Stations

搜索附近充电站 (前端兼容接口).  Args:     latitude: 中心点纬度     longitude: 中心点经度     type: 充电站类型     radius: 搜索半径，默认50公里

### Example

```ts
import {
  Configuration,
  ChargingApi,
} from '@teplanner/sdk';
import type { SearchNearbyStationsApiV1ChargingNearbyGetRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const api = new ChargingApi();

  const body = {
    // number | 中心点纬度
    latitude: 8.14,
    // number | 中心点经度
    longitude: 8.14,
    // string | 类型: supercharger/destination/service/all (optional)
    type: type_example,
    // number | 搜索半径(公里) (optional)
    radius: 8.14,
  } satisfies SearchNearbyStationsApiV1ChargingNearbyGetRequest;

  try {
    const data = await api.searchNearbyStationsApiV1ChargingNearbyGet(body);
    console.log(data);
  } catch (error) {
    console.error(error);
  }
}

// Run the test
example().catch(console.error);
```

### Parameters


| Name | Type | Description  | Notes |
|------------- | ------------- | ------------- | -------------|
| **latitude** | `number` | 中心点纬度 | [Defaults to `undefined`] |
| **longitude** | `number` | 中心点经度 | [Defaults to `undefined`] |
| **type** | `string` | 类型: supercharger/destination/service/all | [Optional] [Defaults to `undefined`] |
| **radius** | `number` | 搜索半径(公里) | [Optional] [Defaults to `50`] |

### Return type

[**StationSearchResponse**](StationSearchResponse.md)

### Authorization

No authorization required

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: `application/json`


### HTTP response details
| Status code | Description | Response headers |
|-------------|-------------|------------------|
| **200** | Successful Response |  -  |
| **422** | Validation Error |  -  |

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


## searchStationsApiV1ChargingStationsGet

> StationSearchResponse searchStationsApiV1ChargingStationsGet(lat, lng, radiusKm, minPowerKw, operator)

Search Stations

搜索附近充电站.  Args:     lat: 中心点纬度     lng: 中心点经度     radius_km: 搜索半径，默认10公里     min_power_kw: 最小充电功率筛选     operator: 运营商筛选

### Example

```ts
import {
  Configuration,
  ChargingApi,
} from '@teplanner/sdk';
import type { SearchStationsApiV1ChargingStationsGetRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const api = new ChargingApi();

  const body = {
    // number | 中心点纬度
    lat: 8.14,
    // number | 中心点经度
    lng: 8.14,
    // number | 搜索半径(公里) (optional)
    radiusKm: 8.14,
    // number | 最小充电功率(kW) (optional)
    minPowerKw: 56,
    // string | 运营商筛选 (optional)
    operator: operator_example,
  } satisfies SearchStationsApiV1ChargingStationsGetRequest;

  try {
    const data = await api.searchStationsApiV1ChargingStationsGet(body);
    console.log(data);
  } catch (error) {
    console.error(error);
  }
}

// Run the test
example().catch(console.error);
```

### Parameters


| Name | Type | Description  | Notes |
|------------- | ------------- | ------------- | -------------|
| **lat** | `number` | 中心点纬度 | [Defaults to `undefined`] |
| **lng** | `number` | 中心点经度 | [Defaults to `undefined`] |
| **radiusKm** | `number` | 搜索半径(公里) | [Optional] [Defaults to `10`] |
| **minPowerKw** | `number` | 最小充电功率(kW) | [Optional] [Defaults to `undefined`] |
| **operator** | `string` | 运营商筛选 | [Optional] [Defaults to `undefined`] |

### Return type

[**StationSearchResponse**](StationSearchResponse.md)

### Authorization

No authorization required

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: `application/json`


### HTTP response details
| Status code | Description | Response headers |
|-------------|-------------|------------------|
| **200** | Successful Response |  -  |
| **422** | Validation Error |  -  |

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)

