# UserApi

All URIs are relative to *http://localhost*

| Method | HTTP request | Description |
| ------------- | ------------- | ------------- |
| [**clearScheduledDepartureApiV1UserScheduledDepartureDelete**](UserApi.md#clearScheduledDepartureApiV1UserScheduledDepartureDelete) | **DELETE** api/v1/user/scheduled-departure | Clear Scheduled Departure |
| [**getScheduledDepartureApiV1UserScheduledDepartureGet**](UserApi.md#getScheduledDepartureApiV1UserScheduledDepartureGet) | **GET** api/v1/user/scheduled-departure | Get Scheduled Departure |
| [**getUserSettingsApiV1UserSettingsGet**](UserApi.md#getUserSettingsApiV1UserSettingsGet) | **GET** api/v1/user/settings | Get User Settings |
| [**upsertScheduledDepartureApiV1UserScheduledDeparturePut**](UserApi.md#upsertScheduledDepartureApiV1UserScheduledDeparturePut) | **PUT** api/v1/user/scheduled-departure | Upsert Scheduled Departure |
| [**upsertUserSettingsApiV1UserSettingsPut**](UserApi.md#upsertUserSettingsApiV1UserSettingsPut) | **PUT** api/v1/user/settings | Upsert User Settings |



Clear Scheduled Departure

Idempotent — clearing a non-existent row is a 200, not 404.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(UserApi::class.java)

launch(Dispatchers.IO) {
    val result : kotlin.Any = webService.clearScheduledDepartureApiV1UserScheduledDepartureDelete()
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**kotlin.Any**](kotlin.Any.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json


Get Scheduled Departure

Fetch the user&#39;s active scheduled departure. Returns &#x60;&#x60;null&#x60;&#x60; when none is set — iOS treats null as \&quot;not scheduled\&quot; and shows the empty card.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(UserApi::class.java)

launch(Dispatchers.IO) {
    val result : ScheduledDepartureResponse = webService.getScheduledDepartureApiV1UserScheduledDepartureGet()
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**ScheduledDepartureResponse**](ScheduledDepartureResponse.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json


Get User Settings

Return the user&#39;s full settings dict. Empty dict when never set. &#x60;updated_at&#x60; is the most recent row update — clients use it to short-circuit re-fetches.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(UserApi::class.java)

launch(Dispatchers.IO) {
    val result : UserSettingsResponse = webService.getUserSettingsApiV1UserSettingsGet()
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**UserSettingsResponse**](UserSettingsResponse.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json


Upsert Scheduled Departure

Replace the user&#39;s scheduled departure with the supplied row. UNIQUE(user_id) enforces single-row semantics; we update in place when a row already exists rather than relying on the DB unique error to bubble up.  Past departures are accepted — the iOS UI prevents them, but a server reject would race with clock skew and break preheat cancellation flows.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(UserApi::class.java)
val scheduledDepartureRequest : ScheduledDepartureRequest =  // ScheduledDepartureRequest | 

launch(Dispatchers.IO) {
    val result : ScheduledDepartureResponse = webService.upsertScheduledDepartureApiV1UserScheduledDeparturePut(scheduledDepartureRequest)
}
```

### Parameters
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **scheduledDepartureRequest** | [**ScheduledDepartureRequest**](ScheduledDepartureRequest.md)|  | |

### Return type

[**ScheduledDepartureResponse**](ScheduledDepartureResponse.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json


Upsert User Settings

Merge &#x60;&#x60;body.settings&#x60;&#x60; into the user&#39;s settings dict (or replace entirely if &#x60;&#x60;replace_all&#x3D;true&#x60;&#x60;). Each value is JSON-encoded for storage. Keys longer than 80 chars or empty are rejected (matches column constraint).

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(UserApi::class.java)
val userSettingsRequest : UserSettingsRequest =  // UserSettingsRequest | 

launch(Dispatchers.IO) {
    val result : UserSettingsResponse = webService.upsertUserSettingsApiV1UserSettingsPut(userSettingsRequest)
}
```

### Parameters
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **userSettingsRequest** | [**UserSettingsRequest**](UserSettingsRequest.md)|  | |

### Return type

[**UserSettingsResponse**](UserSettingsResponse.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

