# DevicesApi

All URIs are relative to *http://localhost*

| Method | HTTP request | Description |
| ------------- | ------------- | ------------- |
| [**registerDeviceApiV1DevicesRegisterPost**](DevicesApi.md#registerDeviceApiV1DevicesRegisterPost) | **POST** api/v1/devices/register | Register Device |
| [**runAutomationTickApiV1DevicesRunAutomationTickPost**](DevicesApi.md#runAutomationTickApiV1DevicesRunAutomationTickPost) | **POST** api/v1/devices/run-automation-tick | Run Automation Tick |
| [**testPushApiV1DevicesTestPushPost**](DevicesApi.md#testPushApiV1DevicesTestPushPost) | **POST** api/v1/devices/test-push | Test Push |



Register Device

Upsert (user_id, token). Re-registering an existing token just bumps last_seen_at — that lets the polling layer prune stale rows later (e.g. tokens not seen for 30 days are likely uninstalled).

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(DevicesApi::class.java)
val registerDeviceRequest : RegisterDeviceRequest =  // RegisterDeviceRequest | 

launch(Dispatchers.IO) {
    val result : RegisterDeviceResponse = webService.registerDeviceApiV1DevicesRegisterPost(registerDeviceRequest)
}
```

### Parameters
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **registerDeviceRequest** | [**RegisterDeviceRequest**](RegisterDeviceRequest.md)|  | |

### Return type

[**RegisterDeviceResponse**](RegisterDeviceResponse.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json


Run Automation Tick

Trigger a single polling tick on demand. Used for end-to-end debugging: hit this, watch server.log, verify a push lands. Doesn&#39;t take args — runs the full eligible-user loop.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(DevicesApi::class.java)

launch(Dispatchers.IO) {
    val result : kotlin.Any = webService.runAutomationTickApiV1DevicesRunAutomationTickPost()
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


Test Push

Send a debug push to all of this user&#39;s registered devices. Useful while wiring up — flip APNs creds, hit this endpoint, see if a notification lands on the phone.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(DevicesApi::class.java)
val testPushRequest : TestPushRequest =  // TestPushRequest | 

launch(Dispatchers.IO) {
    val result : kotlin.Any = webService.testPushApiV1DevicesTestPushPost(testPushRequest)
}
```

### Parameters
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **testPushRequest** | [**TestPushRequest**](TestPushRequest.md)|  | |

### Return type

[**kotlin.Any**](kotlin.Any.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

