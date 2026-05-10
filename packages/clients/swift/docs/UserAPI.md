# UserAPI

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**clearScheduledDepartureApiV1UserScheduledDepartureDelete**](UserAPI.md#clearscheduleddepartureapiv1userscheduleddeparturedelete) | **DELETE** /api/v1/user/scheduled-departure | Clear Scheduled Departure
[**getScheduledDepartureApiV1UserScheduledDepartureGet**](UserAPI.md#getscheduleddepartureapiv1userscheduleddepartureget) | **GET** /api/v1/user/scheduled-departure | Get Scheduled Departure
[**getUserSettingsApiV1UserSettingsGet**](UserAPI.md#getusersettingsapiv1usersettingsget) | **GET** /api/v1/user/settings | Get User Settings
[**upsertScheduledDepartureApiV1UserScheduledDeparturePut**](UserAPI.md#upsertscheduleddepartureapiv1userscheduleddepartureput) | **PUT** /api/v1/user/scheduled-departure | Upsert Scheduled Departure
[**upsertUserSettingsApiV1UserSettingsPut**](UserAPI.md#upsertusersettingsapiv1usersettingsput) | **PUT** /api/v1/user/settings | Upsert User Settings


# **clearScheduledDepartureApiV1UserScheduledDepartureDelete**
```swift
    open class func clearScheduledDepartureApiV1UserScheduledDepartureDelete(completion: @escaping (_ data: AnyCodable?, _ error: Error?) -> Void)
```

Clear Scheduled Departure

Idempotent — clearing a non-existent row is a 200, not 404.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI


// Clear Scheduled Departure
UserAPI.clearScheduledDepartureApiV1UserScheduledDepartureDelete() { (response, error) in
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

**AnyCodable**

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getScheduledDepartureApiV1UserScheduledDepartureGet**
```swift
    open class func getScheduledDepartureApiV1UserScheduledDepartureGet(completion: @escaping (_ data: ScheduledDepartureResponse?, _ error: Error?) -> Void)
```

Get Scheduled Departure

Fetch the user's active scheduled departure. Returns ``null`` when none is set — iOS treats null as \"not scheduled\" and shows the empty card.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI


// Get Scheduled Departure
UserAPI.getScheduledDepartureApiV1UserScheduledDepartureGet() { (response, error) in
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

[**ScheduledDepartureResponse**](ScheduledDepartureResponse.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getUserSettingsApiV1UserSettingsGet**
```swift
    open class func getUserSettingsApiV1UserSettingsGet(completion: @escaping (_ data: UserSettingsResponse?, _ error: Error?) -> Void)
```

Get User Settings

Return the user's full settings dict. Empty dict when never set. `updated_at` is the most recent row update — clients use it to short-circuit re-fetches.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI


// Get User Settings
UserAPI.getUserSettingsApiV1UserSettingsGet() { (response, error) in
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

[**UserSettingsResponse**](UserSettingsResponse.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **upsertScheduledDepartureApiV1UserScheduledDeparturePut**
```swift
    open class func upsertScheduledDepartureApiV1UserScheduledDeparturePut(scheduledDepartureRequest: ScheduledDepartureRequest, completion: @escaping (_ data: ScheduledDepartureResponse?, _ error: Error?) -> Void)
```

Upsert Scheduled Departure

Replace the user's scheduled departure with the supplied row. UNIQUE(user_id) enforces single-row semantics; we update in place when a row already exists rather than relying on the DB unique error to bubble up.  Past departures are accepted — the iOS UI prevents them, but a server reject would race with clock skew and break preheat cancellation flows.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let scheduledDepartureRequest = ScheduledDepartureRequest(departureAtUtc: Date(), leadMinutes: 123, label: "label_example", vehicleId: "vehicleId_example", targetChargeSoc: 123, enabled: false) // ScheduledDepartureRequest | 

// Upsert Scheduled Departure
UserAPI.upsertScheduledDepartureApiV1UserScheduledDeparturePut(scheduledDepartureRequest: scheduledDepartureRequest) { (response, error) in
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
 **scheduledDepartureRequest** | [**ScheduledDepartureRequest**](ScheduledDepartureRequest.md) |  | 

### Return type

[**ScheduledDepartureResponse**](ScheduledDepartureResponse.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **upsertUserSettingsApiV1UserSettingsPut**
```swift
    open class func upsertUserSettingsApiV1UserSettingsPut(userSettingsRequest: UserSettingsRequest, completion: @escaping (_ data: UserSettingsResponse?, _ error: Error?) -> Void)
```

Upsert User Settings

Merge ``body.settings`` into the user's settings dict (or replace entirely if ``replace_all=true``). Each value is JSON-encoded for storage. Keys longer than 80 chars or empty are rejected (matches column constraint).

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let userSettingsRequest = UserSettingsRequest(settings: 123, replaceAll: false) // UserSettingsRequest | 

// Upsert User Settings
UserAPI.upsertUserSettingsApiV1UserSettingsPut(userSettingsRequest: userSettingsRequest) { (response, error) in
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
 **userSettingsRequest** | [**UserSettingsRequest**](UserSettingsRequest.md) |  | 

### Return type

[**UserSettingsResponse**](UserSettingsResponse.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

