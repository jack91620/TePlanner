# VehiclesAPI

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**cancelQueuedCommandApiV1VehiclesCommandsQueuedQueuedIdDelete**](VehiclesAPI.md#cancelqueuedcommandapiv1vehiclescommandsqueuedqueuediddelete) | **DELETE** /api/v1/vehicles/commands/queued/{queued_id} | Cancel Queued Command
[**getVehicleApiV1VehiclesVehicleIdGet**](VehiclesAPI.md#getvehicleapiv1vehiclesvehicleidget) | **GET** /api/v1/vehicles/{vehicle_id} | Get Vehicle
[**getVehicleStateApiV1VehiclesVehicleIdStateGet**](VehiclesAPI.md#getvehiclestateapiv1vehiclesvehicleidstateget) | **GET** /api/v1/vehicles/{vehicle_id}/state | Get Vehicle State
[**listChargingSessionsApiV1VehiclesVehicleIdSessionsGet**](VehiclesAPI.md#listchargingsessionsapiv1vehiclesvehicleidsessionsget) | **GET** /api/v1/vehicles/{vehicle_id}/sessions | List Charging Sessions
[**listPendingCommandsApiV1VehiclesCommandsPendingGet**](VehiclesAPI.md#listpendingcommandsapiv1vehiclescommandspendingget) | **GET** /api/v1/vehicles/commands/pending | List Pending Commands
[**listQueuedCommandsApiV1VehiclesCommandsQueuedGet**](VehiclesAPI.md#listqueuedcommandsapiv1vehiclescommandsqueuedget) | **GET** /api/v1/vehicles/commands/queued | List Queued Commands
[**listVehiclesApiV1VehiclesGet**](VehiclesAPI.md#listvehiclesapiv1vehiclesget) | **GET** /api/v1/vehicles/ | List Vehicles
[**navigateVehicleAddressApiV1VehiclesVehicleIdNavigateAddressPost**](VehiclesAPI.md#navigatevehicleaddressapiv1vehiclesvehicleidnavigateaddresspost) | **POST** /api/v1/vehicles/{vehicle_id}/navigate/address | Navigate Vehicle Address
[**navigateVehicleApiV1VehiclesVehicleIdNavigatePost**](VehiclesAPI.md#navigatevehicleapiv1vehiclesvehicleidnavigatepost) | **POST** /api/v1/vehicles/{vehicle_id}/navigate | Navigate Vehicle
[**preheatVehicleApiV1VehiclesVehicleIdPreheatPost**](VehiclesAPI.md#preheatvehicleapiv1vehiclesvehicleidpreheatpost) | **POST** /api/v1/vehicles/{vehicle_id}/preheat | Preheat Vehicle
[**setChargeLimitApiV1VehiclesVehicleIdChargeLimitPost**](VehiclesAPI.md#setchargelimitapiv1vehiclesvehicleidchargelimitpost) | **POST** /api/v1/vehicles/{vehicle_id}/charge-limit | Set Charge Limit
[**setClimateKeeperModeApiV1VehiclesVehicleIdClimateKeeperModePost**](VehiclesAPI.md#setclimatekeepermodeapiv1vehiclesvehicleidclimatekeepermodepost) | **POST** /api/v1/vehicles/{vehicle_id}/climate-keeper-mode | Set Climate Keeper Mode
[**setPrimaryVehicleApiV1VehiclesVehicleIdSetPrimaryPost**](VehiclesAPI.md#setprimaryvehicleapiv1vehiclesvehicleidsetprimarypost) | **POST** /api/v1/vehicles/{vehicle_id}/set-primary | Set Primary Vehicle
[**setSentryModeApiV1VehiclesVehicleIdSentryModePost**](VehiclesAPI.md#setsentrymodeapiv1vehiclesvehicleidsentrymodepost) | **POST** /api/v1/vehicles/{vehicle_id}/sentry-mode | Set Sentry Mode
[**suggestChargeLimitEndpointApiV1VehiclesVehicleIdSuggestChargeLimitPost**](VehiclesAPI.md#suggestchargelimitendpointapiv1vehiclesvehicleidsuggestchargelimitpost) | **POST** /api/v1/vehicles/{vehicle_id}/suggest-charge-limit | Suggest Charge Limit Endpoint
[**upsertChargingSessionApiV1VehiclesVehicleIdSessionsPost**](VehiclesAPI.md#upsertchargingsessionapiv1vehiclesvehicleidsessionspost) | **POST** /api/v1/vehicles/{vehicle_id}/sessions | Upsert Charging Session
[**wakeVehicleApiV1VehiclesVehicleIdWakePost**](VehiclesAPI.md#wakevehicleapiv1vehiclesvehicleidwakepost) | **POST** /api/v1/vehicles/{vehicle_id}/wake | Wake Vehicle


# **cancelQueuedCommandApiV1VehiclesCommandsQueuedQueuedIdDelete**
```swift
    open class func cancelQueuedCommandApiV1VehiclesCommandsQueuedQueuedIdDelete(queuedId: Int, completion: @escaping (_ data: AnyCodable?, _ error: Error?) -> Void)
```

Cancel Queued Command

Cancel a still-queued command before it drains. 404 if the user doesn't own it; 409 if it's already been sent/dropped.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let queuedId = 987 // Int | 

// Cancel Queued Command
VehiclesAPI.cancelQueuedCommandApiV1VehiclesCommandsQueuedQueuedIdDelete(queuedId: queuedId) { (response, error) in
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
 **queuedId** | **Int** |  | 

### Return type

**AnyCodable**

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getVehicleApiV1VehiclesVehicleIdGet**
```swift
    open class func getVehicleApiV1VehiclesVehicleIdGet(vehicleId: String, completion: @escaping (_ data: VehicleResponse?, _ error: Error?) -> Void)
```

Get Vehicle

Get specific vehicle details.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let vehicleId = "vehicleId_example" // String | 

// Get Vehicle
VehiclesAPI.getVehicleApiV1VehiclesVehicleIdGet(vehicleId: vehicleId) { (response, error) in
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
 **vehicleId** | **String** |  | 

### Return type

[**VehicleResponse**](VehicleResponse.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getVehicleStateApiV1VehiclesVehicleIdStateGet**
```swift
    open class func getVehicleStateApiV1VehiclesVehicleIdStateGet(vehicleId: String, completion: @escaping (_ data: VehicleStateResponse?, _ error: Error?) -> Void)
```

Get Vehicle State

Get vehicle state (battery, location, etc.).  Returns real-time vehicle data including: - Battery level and range - Current location (GPS) - Charging state - Climate status

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let vehicleId = "vehicleId_example" // String | 

// Get Vehicle State
VehiclesAPI.getVehicleStateApiV1VehiclesVehicleIdStateGet(vehicleId: vehicleId) { (response, error) in
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
 **vehicleId** | **String** |  | 

### Return type

[**VehicleStateResponse**](VehicleStateResponse.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listChargingSessionsApiV1VehiclesVehicleIdSessionsGet**
```swift
    open class func listChargingSessionsApiV1VehiclesVehicleIdSessionsGet(vehicleId: String, limit: Int? = nil, completion: @escaping (_ data: ChargingSessionListResponse?, _ error: Error?) -> Void)
```

List Charging Sessions

Most-recent-first session list. Default limit 50 covers ~6 weeks of typical daily-charging owners; clients pass `?limit=N` to dig further. Strict per-user filter so a vehicle_id collision (Tesla sometimes recycles ids across accounts) can't leak rows.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let vehicleId = "vehicleId_example" // String | 
let limit = 987 // Int |  (optional) (default to 50)

// List Charging Sessions
VehiclesAPI.listChargingSessionsApiV1VehiclesVehicleIdSessionsGet(vehicleId: vehicleId, limit: limit) { (response, error) in
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
 **vehicleId** | **String** |  | 
 **limit** | **Int** |  | [optional] [default to 50]

### Return type

[**ChargingSessionListResponse**](ChargingSessionListResponse.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listPendingCommandsApiV1VehiclesCommandsPendingGet**
```swift
    open class func listPendingCommandsApiV1VehiclesCommandsPendingGet(limit: Int? = nil, completion: @escaping (_ data: PendingCommandListResponse?, _ error: Error?) -> Void)
```

List Pending Commands

Phase 9 — what VCP commands sent in the last few minutes are still awaiting telemetry confirmation, plus the most recently resolved ones for the iOS UI to flip to \"已关闭\" / \"超时\".  The resolver runs server-side on every Telemetry frame, so a well-timed poll right after dispatch will see the row transition pending → confirmed within ~1-2 s of the actual state change.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let limit = 987 // Int |  (optional) (default to 20)

// List Pending Commands
VehiclesAPI.listPendingCommandsApiV1VehiclesCommandsPendingGet(limit: limit) { (response, error) in
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
 **limit** | **Int** |  | [optional] [default to 20]

### Return type

[**PendingCommandListResponse**](PendingCommandListResponse.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listQueuedCommandsApiV1VehiclesCommandsQueuedGet**
```swift
    open class func listQueuedCommandsApiV1VehiclesCommandsQueuedGet(limit: Int? = nil, completion: @escaping (_ data: QueuedCommandListResponse?, _ error: Error?) -> Void)
```

List Queued Commands

Return commands waiting on the car's next CONNECTED telemetry event, plus recently-resolved ones for the iOS UI to flip badges.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let limit = 987 // Int |  (optional) (default to 20)

// List Queued Commands
VehiclesAPI.listQueuedCommandsApiV1VehiclesCommandsQueuedGet(limit: limit) { (response, error) in
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
 **limit** | **Int** |  | [optional] [default to 20]

### Return type

[**QueuedCommandListResponse**](QueuedCommandListResponse.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listVehiclesApiV1VehiclesGet**
```swift
    open class func listVehiclesApiV1VehiclesGet(completion: @escaping (_ data: VehicleListResponse?, _ error: Error?) -> Void)
```

List Vehicles

List user's Tesla vehicles, syncing the local Vehicle table. Logic in services/vehicle_sync_service.sync_vehicles.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI


// List Vehicles
VehiclesAPI.listVehiclesApiV1VehiclesGet() { (response, error) in
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
This endpoint does not need any parameter.

### Return type

[**VehicleListResponse**](VehicleListResponse.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **navigateVehicleAddressApiV1VehiclesVehicleIdNavigateAddressPost**
```swift
    open class func navigateVehicleAddressApiV1VehiclesVehicleIdNavigateAddressPost(vehicleId: String, navigationAddressRequest: NavigationAddressRequest, completion: @escaping (_ data: AnyCodable?, _ error: Error?) -> Void)
```

Navigate Vehicle Address

Send navigation destination by address to vehicle.  Sends address string to the vehicle's navigation system. Vehicle must be online.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let vehicleId = "vehicleId_example" // String | 
let navigationAddressRequest = NavigationAddressRequest(address: "address_example", locale: "locale_example") // NavigationAddressRequest | 

// Navigate Vehicle Address
VehiclesAPI.navigateVehicleAddressApiV1VehiclesVehicleIdNavigateAddressPost(vehicleId: vehicleId, navigationAddressRequest: navigationAddressRequest) { (response, error) in
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
 **vehicleId** | **String** |  | 
 **navigationAddressRequest** | [**NavigationAddressRequest**](NavigationAddressRequest.md) |  | 

### Return type

**AnyCodable**

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **navigateVehicleApiV1VehiclesVehicleIdNavigatePost**
```swift
    open class func navigateVehicleApiV1VehiclesVehicleIdNavigatePost(vehicleId: String, navigationRequest: NavigationRequest, completion: @escaping (_ data: AnyCodable?, _ error: Error?) -> Void)
```

Navigate Vehicle

Send GPS coordinates to vehicle nav. Dispatches through capability registry. Uses numeric vehicle_id (not VIN) since navigation_gps_request is one of the few endpoints not on the VCP-signed path.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let vehicleId = "vehicleId_example" // String | 
let navigationRequest = NavigationRequest(latitude: 123, longitude: 123, order: 123) // NavigationRequest | 

// Navigate Vehicle
VehiclesAPI.navigateVehicleApiV1VehiclesVehicleIdNavigatePost(vehicleId: vehicleId, navigationRequest: navigationRequest) { (response, error) in
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
 **vehicleId** | **String** |  | 
 **navigationRequest** | [**NavigationRequest**](NavigationRequest.md) |  | 

### Return type

**AnyCodable**

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **preheatVehicleApiV1VehiclesVehicleIdPreheatPost**
```swift
    open class func preheatVehicleApiV1VehiclesVehicleIdPreheatPost(vehicleId: String, completion: @escaping (_ data: AnyCodable?, _ error: Error?) -> Void)
```

Preheat Vehicle

Start HVAC (auto_conditioning_start) so the cabin is at temperature on arrival. Used by 出发前预热. Dispatches through capability registry.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let vehicleId = "vehicleId_example" // String | 

// Preheat Vehicle
VehiclesAPI.preheatVehicleApiV1VehiclesVehicleIdPreheatPost(vehicleId: vehicleId) { (response, error) in
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
 **vehicleId** | **String** |  | 

### Return type

**AnyCodable**

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **setChargeLimitApiV1VehiclesVehicleIdChargeLimitPost**
```swift
    open class func setChargeLimitApiV1VehiclesVehicleIdChargeLimitPost(vehicleId: String, chargeLimitRequest: ChargeLimitRequest, completion: @escaping (_ data: AnyCodable?, _ error: Error?) -> Void)
```

Set Charge Limit

Set the vehicle's charge limit SOC percent (50..100). Dispatches through capability registry.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let vehicleId = "vehicleId_example" // String | 
let chargeLimitRequest = ChargeLimitRequest(percent: 123) // ChargeLimitRequest | 

// Set Charge Limit
VehiclesAPI.setChargeLimitApiV1VehiclesVehicleIdChargeLimitPost(vehicleId: vehicleId, chargeLimitRequest: chargeLimitRequest) { (response, error) in
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
 **vehicleId** | **String** |  | 
 **chargeLimitRequest** | [**ChargeLimitRequest**](ChargeLimitRequest.md) |  | 

### Return type

**AnyCodable**

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **setClimateKeeperModeApiV1VehiclesVehicleIdClimateKeeperModePost**
```swift
    open class func setClimateKeeperModeApiV1VehiclesVehicleIdClimateKeeperModePost(vehicleId: String, climateKeeperModeRequest: ClimateKeeperModeRequest, completion: @escaping (_ data: AnyCodable?, _ error: Error?) -> Void)
```

Set Climate Keeper Mode

Set climate keeper mode. 0=off / 1=keep / 2=dog / 3=camp. Dispatches through capability registry.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let vehicleId = "vehicleId_example" // String | 
let climateKeeperModeRequest = ClimateKeeperModeRequest(mode: 123) // ClimateKeeperModeRequest | 

// Set Climate Keeper Mode
VehiclesAPI.setClimateKeeperModeApiV1VehiclesVehicleIdClimateKeeperModePost(vehicleId: vehicleId, climateKeeperModeRequest: climateKeeperModeRequest) { (response, error) in
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
 **vehicleId** | **String** |  | 
 **climateKeeperModeRequest** | [**ClimateKeeperModeRequest**](ClimateKeeperModeRequest.md) |  | 

### Return type

**AnyCodable**

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **setPrimaryVehicleApiV1VehiclesVehicleIdSetPrimaryPost**
```swift
    open class func setPrimaryVehicleApiV1VehiclesVehicleIdSetPrimaryPost(vehicleId: String, completion: @escaping (_ data: AnyCodable?, _ error: Error?) -> Void)
```

Set Primary Vehicle

Set vehicle as primary for the user.  Only one vehicle can be primary at a time.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let vehicleId = "vehicleId_example" // String | 

// Set Primary Vehicle
VehiclesAPI.setPrimaryVehicleApiV1VehiclesVehicleIdSetPrimaryPost(vehicleId: vehicleId) { (response, error) in
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
 **vehicleId** | **String** |  | 

### Return type

**AnyCodable**

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **setSentryModeApiV1VehiclesVehicleIdSentryModePost**
```swift
    open class func setSentryModeApiV1VehiclesVehicleIdSentryModePost(vehicleId: String, sentryModeRequest: SentryModeRequest, completion: @escaping (_ data: AnyCodable?, _ error: Error?) -> Void)
```

Set Sentry Mode

Toggle sentry mode. Dispatches through capability registry.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let vehicleId = "vehicleId_example" // String | 
let sentryModeRequest = SentryModeRequest(on: false) // SentryModeRequest | 

// Set Sentry Mode
VehiclesAPI.setSentryModeApiV1VehiclesVehicleIdSentryModePost(vehicleId: vehicleId, sentryModeRequest: sentryModeRequest) { (response, error) in
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
 **vehicleId** | **String** |  | 
 **sentryModeRequest** | [**SentryModeRequest**](SentryModeRequest.md) |  | 

### Return type

**AnyCodable**

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **suggestChargeLimitEndpointApiV1VehiclesVehicleIdSuggestChargeLimitPost**
```swift
    open class func suggestChargeLimitEndpointApiV1VehiclesVehicleIdSuggestChargeLimitPost(vehicleId: String, suggestChargeLimitRequest: SuggestChargeLimitRequest, completion: @escaping (_ data: SuggestChargeLimitResponse?, _ error: Error?) -> Void)
```

Suggest Charge Limit Endpoint

Server-side mirror of iOS ChargeLimitSuggester. Reads the user's currently-stored ScheduledDeparture (A.3) to find any upcoming trip; daily/trip preferences come from the request body (Phase D will read them from /user/settings instead).

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let vehicleId = "vehicleId_example" // String | 
let suggestChargeLimitRequest = SuggestChargeLimitRequest(currentLimit: 123, dailyLimitSoc: 123, tripLimitSoc: 123, tripWindowHours: 123) // SuggestChargeLimitRequest | 

// Suggest Charge Limit Endpoint
VehiclesAPI.suggestChargeLimitEndpointApiV1VehiclesVehicleIdSuggestChargeLimitPost(vehicleId: vehicleId, suggestChargeLimitRequest: suggestChargeLimitRequest) { (response, error) in
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
 **vehicleId** | **String** |  | 
 **suggestChargeLimitRequest** | [**SuggestChargeLimitRequest**](SuggestChargeLimitRequest.md) |  | 

### Return type

[**SuggestChargeLimitResponse**](SuggestChargeLimitResponse.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **upsertChargingSessionApiV1VehiclesVehicleIdSessionsPost**
```swift
    open class func upsertChargingSessionApiV1VehiclesVehicleIdSessionsPost(vehicleId: String, chargingSessionRequest: ChargingSessionRequest, completion: @escaping (_ data: ChargingSessionResponse?, _ error: Error?) -> Void)
```

Upsert Charging Session

Create or update a charging session.  iOS POSTs once on plug-in (ended_at NULL) and again on plug-out (ended_at set). Server upserts on ``client_session_id`` so retries are safe; if absent (legacy iOS builds), every POST creates a new row — acceptable trade-off but fix client-side first.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let vehicleId = "vehicleId_example" // String | 
let chargingSessionRequest = ChargingSessionRequest(clientSessionId: "clientSessionId_example", endRangeKm: 123, endSoc: 123, endedAsComplete: false, endedAt: Date(), energyAddedKwh: 123, lat: 123, lng: 123, locationName: "locationName_example", startRangeKm: 123, startSoc: 123, startedAt: Date()) // ChargingSessionRequest | 

// Upsert Charging Session
VehiclesAPI.upsertChargingSessionApiV1VehiclesVehicleIdSessionsPost(vehicleId: vehicleId, chargingSessionRequest: chargingSessionRequest) { (response, error) in
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
 **vehicleId** | **String** |  | 
 **chargingSessionRequest** | [**ChargingSessionRequest**](ChargingSessionRequest.md) |  | 

### Return type

[**ChargingSessionResponse**](ChargingSessionResponse.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **wakeVehicleApiV1VehiclesVehicleIdWakePost**
```swift
    open class func wakeVehicleApiV1VehiclesVehicleIdWakePost(vehicleId: String, completion: @escaping (_ data: WakeResponse?, _ error: Error?) -> Void)
```

Wake Vehicle

Wake up the vehicle.  Sends wake-up command and waits for vehicle to come online. May take 10-30 seconds.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let vehicleId = "vehicleId_example" // String | 

// Wake Vehicle
VehiclesAPI.wakeVehicleApiV1VehiclesVehicleIdWakePost(vehicleId: vehicleId) { (response, error) in
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
 **vehicleId** | **String** |  | 

### Return type

[**WakeResponse**](WakeResponse.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

