# VehiclesApi

All URIs are relative to *http://localhost*

| Method | HTTP request | Description |
| ------------- | ------------- | ------------- |
| [**cancelQueuedCommandApiV1VehiclesCommandsQueuedQueuedIdDelete**](VehiclesApi.md#cancelQueuedCommandApiV1VehiclesCommandsQueuedQueuedIdDelete) | **DELETE** api/v1/vehicles/commands/queued/{queued_id} | Cancel Queued Command |
| [**getVehicleApiV1VehiclesVehicleIdGet**](VehiclesApi.md#getVehicleApiV1VehiclesVehicleIdGet) | **GET** api/v1/vehicles/{vehicle_id} | Get Vehicle |
| [**getVehicleStateApiV1VehiclesVehicleIdStateGet**](VehiclesApi.md#getVehicleStateApiV1VehiclesVehicleIdStateGet) | **GET** api/v1/vehicles/{vehicle_id}/state | Get Vehicle State |
| [**listChargingSessionsApiV1VehiclesVehicleIdSessionsGet**](VehiclesApi.md#listChargingSessionsApiV1VehiclesVehicleIdSessionsGet) | **GET** api/v1/vehicles/{vehicle_id}/sessions | List Charging Sessions |
| [**listPendingCommandsApiV1VehiclesCommandsPendingGet**](VehiclesApi.md#listPendingCommandsApiV1VehiclesCommandsPendingGet) | **GET** api/v1/vehicles/commands/pending | List Pending Commands |
| [**listQueuedCommandsApiV1VehiclesCommandsQueuedGet**](VehiclesApi.md#listQueuedCommandsApiV1VehiclesCommandsQueuedGet) | **GET** api/v1/vehicles/commands/queued | List Queued Commands |
| [**listVehiclesApiV1VehiclesGet**](VehiclesApi.md#listVehiclesApiV1VehiclesGet) | **GET** api/v1/vehicles/ | List Vehicles |
| [**navigateVehicleAddressApiV1VehiclesVehicleIdNavigateAddressPost**](VehiclesApi.md#navigateVehicleAddressApiV1VehiclesVehicleIdNavigateAddressPost) | **POST** api/v1/vehicles/{vehicle_id}/navigate/address | Navigate Vehicle Address |
| [**navigateVehicleApiV1VehiclesVehicleIdNavigatePost**](VehiclesApi.md#navigateVehicleApiV1VehiclesVehicleIdNavigatePost) | **POST** api/v1/vehicles/{vehicle_id}/navigate | Navigate Vehicle |
| [**preheatVehicleApiV1VehiclesVehicleIdPreheatPost**](VehiclesApi.md#preheatVehicleApiV1VehiclesVehicleIdPreheatPost) | **POST** api/v1/vehicles/{vehicle_id}/preheat | Preheat Vehicle |
| [**setChargeLimitApiV1VehiclesVehicleIdChargeLimitPost**](VehiclesApi.md#setChargeLimitApiV1VehiclesVehicleIdChargeLimitPost) | **POST** api/v1/vehicles/{vehicle_id}/charge-limit | Set Charge Limit |
| [**setClimateKeeperModeApiV1VehiclesVehicleIdClimateKeeperModePost**](VehiclesApi.md#setClimateKeeperModeApiV1VehiclesVehicleIdClimateKeeperModePost) | **POST** api/v1/vehicles/{vehicle_id}/climate-keeper-mode | Set Climate Keeper Mode |
| [**setPrimaryVehicleApiV1VehiclesVehicleIdSetPrimaryPost**](VehiclesApi.md#setPrimaryVehicleApiV1VehiclesVehicleIdSetPrimaryPost) | **POST** api/v1/vehicles/{vehicle_id}/set-primary | Set Primary Vehicle |
| [**setSentryModeApiV1VehiclesVehicleIdSentryModePost**](VehiclesApi.md#setSentryModeApiV1VehiclesVehicleIdSentryModePost) | **POST** api/v1/vehicles/{vehicle_id}/sentry-mode | Set Sentry Mode |
| [**suggestChargeLimitEndpointApiV1VehiclesVehicleIdSuggestChargeLimitPost**](VehiclesApi.md#suggestChargeLimitEndpointApiV1VehiclesVehicleIdSuggestChargeLimitPost) | **POST** api/v1/vehicles/{vehicle_id}/suggest-charge-limit | Suggest Charge Limit Endpoint |
| [**upsertChargingSessionApiV1VehiclesVehicleIdSessionsPost**](VehiclesApi.md#upsertChargingSessionApiV1VehiclesVehicleIdSessionsPost) | **POST** api/v1/vehicles/{vehicle_id}/sessions | Upsert Charging Session |
| [**wakeVehicleApiV1VehiclesVehicleIdWakePost**](VehiclesApi.md#wakeVehicleApiV1VehiclesVehicleIdWakePost) | **POST** api/v1/vehicles/{vehicle_id}/wake | Wake Vehicle |



Cancel Queued Command

Cancel a still-queued command before it drains. 404 if the user doesn&#39;t own it; 409 if it&#39;s already been sent/dropped.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(VehiclesApi::class.java)
val queuedId : kotlin.Int = 56 // kotlin.Int | 

launch(Dispatchers.IO) {
    val result : kotlin.Any = webService.cancelQueuedCommandApiV1VehiclesCommandsQueuedQueuedIdDelete(queuedId)
}
```

### Parameters
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **queuedId** | **kotlin.Int**|  | |

### Return type

[**kotlin.Any**](kotlin.Any.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json


Get Vehicle

Get specific vehicle details.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(VehiclesApi::class.java)
val vehicleId : kotlin.String = vehicleId_example // kotlin.String | 

launch(Dispatchers.IO) {
    val result : VehicleResponse = webService.getVehicleApiV1VehiclesVehicleIdGet(vehicleId)
}
```

### Parameters
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **vehicleId** | **kotlin.String**|  | |

### Return type

[**VehicleResponse**](VehicleResponse.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json


Get Vehicle State

Get vehicle state (battery, location, etc.).  Returns real-time vehicle data including: - Battery level and range - Current location (GPS) - Charging state - Climate status

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(VehiclesApi::class.java)
val vehicleId : kotlin.String = vehicleId_example // kotlin.String | 

launch(Dispatchers.IO) {
    val result : VehicleStateResponse = webService.getVehicleStateApiV1VehiclesVehicleIdStateGet(vehicleId)
}
```

### Parameters
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **vehicleId** | **kotlin.String**|  | |

### Return type

[**VehicleStateResponse**](VehicleStateResponse.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json


List Charging Sessions

Most-recent-first session list. Default limit 50 covers ~6 weeks of typical daily-charging owners; clients pass &#x60;?limit&#x3D;N&#x60; to dig further. Strict per-user filter so a vehicle_id collision (Tesla sometimes recycles ids across accounts) can&#39;t leak rows.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(VehiclesApi::class.java)
val vehicleId : kotlin.String = vehicleId_example // kotlin.String | 
val limit : kotlin.Int = 56 // kotlin.Int | 

launch(Dispatchers.IO) {
    val result : ChargingSessionListResponse = webService.listChargingSessionsApiV1VehiclesVehicleIdSessionsGet(vehicleId, limit)
}
```

### Parameters
| **vehicleId** | **kotlin.String**|  | |
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **limit** | **kotlin.Int**|  | [optional] [default to 50] |

### Return type

[**ChargingSessionListResponse**](ChargingSessionListResponse.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json


List Pending Commands

Phase 9 — what VCP commands sent in the last few minutes are still awaiting telemetry confirmation, plus the most recently resolved ones for the iOS UI to flip to \&quot;已关闭\&quot; / \&quot;超时\&quot;.  The resolver runs server-side on every Telemetry frame, so a well-timed poll right after dispatch will see the row transition pending → confirmed within ~1-2 s of the actual state change.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(VehiclesApi::class.java)
val limit : kotlin.Int = 56 // kotlin.Int | 

launch(Dispatchers.IO) {
    val result : PendingCommandListResponse = webService.listPendingCommandsApiV1VehiclesCommandsPendingGet(limit)
}
```

### Parameters
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **limit** | **kotlin.Int**|  | [optional] [default to 20] |

### Return type

[**PendingCommandListResponse**](PendingCommandListResponse.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json


List Queued Commands

Return commands waiting on the car&#39;s next CONNECTED telemetry event, plus recently-resolved ones for the iOS UI to flip badges.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(VehiclesApi::class.java)
val limit : kotlin.Int = 56 // kotlin.Int | 

launch(Dispatchers.IO) {
    val result : QueuedCommandListResponse = webService.listQueuedCommandsApiV1VehiclesCommandsQueuedGet(limit)
}
```

### Parameters
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **limit** | **kotlin.Int**|  | [optional] [default to 20] |

### Return type

[**QueuedCommandListResponse**](QueuedCommandListResponse.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json


List Vehicles

List user&#39;s Tesla vehicles, syncing the local Vehicle table. Logic in services/vehicle_sync_service.sync_vehicles.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(VehiclesApi::class.java)

launch(Dispatchers.IO) {
    val result : VehicleListResponse = webService.listVehiclesApiV1VehiclesGet()
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**VehicleListResponse**](VehicleListResponse.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json


Navigate Vehicle Address

Send navigation destination by address to vehicle.  Sends address string to the vehicle&#39;s navigation system. Vehicle must be online.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(VehiclesApi::class.java)
val vehicleId : kotlin.String = vehicleId_example // kotlin.String | 
val navigationAddressRequest : NavigationAddressRequest =  // NavigationAddressRequest | 

launch(Dispatchers.IO) {
    val result : kotlin.Any = webService.navigateVehicleAddressApiV1VehiclesVehicleIdNavigateAddressPost(vehicleId, navigationAddressRequest)
}
```

### Parameters
| **vehicleId** | **kotlin.String**|  | |
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **navigationAddressRequest** | [**NavigationAddressRequest**](NavigationAddressRequest.md)|  | |

### Return type

[**kotlin.Any**](kotlin.Any.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json


Navigate Vehicle

Send GPS coordinates to vehicle nav. Dispatches through capability registry. Uses numeric vehicle_id (not VIN) since navigation_gps_request is one of the few endpoints not on the VCP-signed path.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(VehiclesApi::class.java)
val vehicleId : kotlin.String = vehicleId_example // kotlin.String | 
val navigationRequest : NavigationRequest =  // NavigationRequest | 

launch(Dispatchers.IO) {
    val result : kotlin.Any = webService.navigateVehicleApiV1VehiclesVehicleIdNavigatePost(vehicleId, navigationRequest)
}
```

### Parameters
| **vehicleId** | **kotlin.String**|  | |
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **navigationRequest** | [**NavigationRequest**](NavigationRequest.md)|  | |

### Return type

[**kotlin.Any**](kotlin.Any.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json


Preheat Vehicle

Start HVAC (auto_conditioning_start) so the cabin is at temperature on arrival. Used by 出发前预热. Dispatches through capability registry.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(VehiclesApi::class.java)
val vehicleId : kotlin.String = vehicleId_example // kotlin.String | 

launch(Dispatchers.IO) {
    val result : kotlin.Any = webService.preheatVehicleApiV1VehiclesVehicleIdPreheatPost(vehicleId)
}
```

### Parameters
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **vehicleId** | **kotlin.String**|  | |

### Return type

[**kotlin.Any**](kotlin.Any.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json


Set Charge Limit

Set the vehicle&#39;s charge limit SOC percent (50..100). Dispatches through capability registry.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(VehiclesApi::class.java)
val vehicleId : kotlin.String = vehicleId_example // kotlin.String | 
val chargeLimitRequest : ChargeLimitRequest =  // ChargeLimitRequest | 

launch(Dispatchers.IO) {
    val result : kotlin.Any = webService.setChargeLimitApiV1VehiclesVehicleIdChargeLimitPost(vehicleId, chargeLimitRequest)
}
```

### Parameters
| **vehicleId** | **kotlin.String**|  | |
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **chargeLimitRequest** | [**ChargeLimitRequest**](ChargeLimitRequest.md)|  | |

### Return type

[**kotlin.Any**](kotlin.Any.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json


Set Climate Keeper Mode

Set climate keeper mode. 0&#x3D;off / 1&#x3D;keep / 2&#x3D;dog / 3&#x3D;camp. Dispatches through capability registry.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(VehiclesApi::class.java)
val vehicleId : kotlin.String = vehicleId_example // kotlin.String | 
val climateKeeperModeRequest : ClimateKeeperModeRequest =  // ClimateKeeperModeRequest | 

launch(Dispatchers.IO) {
    val result : kotlin.Any = webService.setClimateKeeperModeApiV1VehiclesVehicleIdClimateKeeperModePost(vehicleId, climateKeeperModeRequest)
}
```

### Parameters
| **vehicleId** | **kotlin.String**|  | |
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **climateKeeperModeRequest** | [**ClimateKeeperModeRequest**](ClimateKeeperModeRequest.md)|  | |

### Return type

[**kotlin.Any**](kotlin.Any.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json


Set Primary Vehicle

Set vehicle as primary for the user.  Only one vehicle can be primary at a time.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(VehiclesApi::class.java)
val vehicleId : kotlin.String = vehicleId_example // kotlin.String | 

launch(Dispatchers.IO) {
    val result : kotlin.Any = webService.setPrimaryVehicleApiV1VehiclesVehicleIdSetPrimaryPost(vehicleId)
}
```

### Parameters
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **vehicleId** | **kotlin.String**|  | |

### Return type

[**kotlin.Any**](kotlin.Any.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json


Set Sentry Mode

Toggle sentry mode. Dispatches through capability registry.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(VehiclesApi::class.java)
val vehicleId : kotlin.String = vehicleId_example // kotlin.String | 
val sentryModeRequest : SentryModeRequest =  // SentryModeRequest | 

launch(Dispatchers.IO) {
    val result : kotlin.Any = webService.setSentryModeApiV1VehiclesVehicleIdSentryModePost(vehicleId, sentryModeRequest)
}
```

### Parameters
| **vehicleId** | **kotlin.String**|  | |
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **sentryModeRequest** | [**SentryModeRequest**](SentryModeRequest.md)|  | |

### Return type

[**kotlin.Any**](kotlin.Any.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json


Suggest Charge Limit Endpoint

Server-side mirror of iOS ChargeLimitSuggester. Reads the user&#39;s currently-stored ScheduledDeparture (A.3) to find any upcoming trip; daily/trip preferences come from the request body (Phase D will read them from /user/settings instead).

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(VehiclesApi::class.java)
val vehicleId : kotlin.String = vehicleId_example // kotlin.String | 
val suggestChargeLimitRequest : SuggestChargeLimitRequest =  // SuggestChargeLimitRequest | 

launch(Dispatchers.IO) {
    val result : SuggestChargeLimitResponse = webService.suggestChargeLimitEndpointApiV1VehiclesVehicleIdSuggestChargeLimitPost(vehicleId, suggestChargeLimitRequest)
}
```

### Parameters
| **vehicleId** | **kotlin.String**|  | |
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **suggestChargeLimitRequest** | [**SuggestChargeLimitRequest**](SuggestChargeLimitRequest.md)|  | |

### Return type

[**SuggestChargeLimitResponse**](SuggestChargeLimitResponse.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json


Upsert Charging Session

Create or update a charging session.  iOS POSTs once on plug-in (ended_at NULL) and again on plug-out (ended_at set). Server upserts on &#x60;&#x60;client_session_id&#x60;&#x60; so retries are safe; if absent (legacy iOS builds), every POST creates a new row — acceptable trade-off but fix client-side first.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(VehiclesApi::class.java)
val vehicleId : kotlin.String = vehicleId_example // kotlin.String | 
val chargingSessionRequest : ChargingSessionRequest =  // ChargingSessionRequest | 

launch(Dispatchers.IO) {
    val result : ChargingSessionResponse = webService.upsertChargingSessionApiV1VehiclesVehicleIdSessionsPost(vehicleId, chargingSessionRequest)
}
```

### Parameters
| **vehicleId** | **kotlin.String**|  | |
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **chargingSessionRequest** | [**ChargingSessionRequest**](ChargingSessionRequest.md)|  | |

### Return type

[**ChargingSessionResponse**](ChargingSessionResponse.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json


Wake Vehicle

Wake up the vehicle.  Sends wake-up command and waits for vehicle to come online. May take 10-30 seconds.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(VehiclesApi::class.java)
val vehicleId : kotlin.String = vehicleId_example // kotlin.String | 

launch(Dispatchers.IO) {
    val result : WakeResponse = webService.wakeVehicleApiV1VehiclesVehicleIdWakePost(vehicleId)
}
```

### Parameters
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **vehicleId** | **kotlin.String**|  | |

### Return type

[**WakeResponse**](WakeResponse.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

