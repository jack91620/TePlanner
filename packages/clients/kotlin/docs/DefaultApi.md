# DefaultApi

All URIs are relative to *http://localhost*

| Method | HTTP request | Description |
| ------------- | ------------- | ------------- |
| [**healthCheckHealthGet**](DefaultApi.md#healthCheckHealthGet) | **GET** health | Health Check |
| [**rootGet**](DefaultApi.md#rootGet) | **GET**  | Root |
| [**serveWechatVerificationFilenameGet**](DefaultApi.md#serveWechatVerificationFilenameGet) | **GET** {filename} | Serve Wechat Verification |



Health Check

Health check endpoint. Returns app version + status — the &#x60;version&#x60; field is consumed by &#x60;tests/test_health.py&#x60; and surfaced in the &#x60;ops/server-monitor.sh&#x60; snapshot for cross- referencing post-deploy. Source: &#x60;app.config.settings.APP_VERSION&#x60; if defined, falling back to &#39;0.0.0&#39; for local runs.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
val webService = apiClient.createWebservice(DefaultApi::class.java)

launch(Dispatchers.IO) {
    val result : kotlin.Any = webService.healthCheckHealthGet()
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**kotlin.Any**](kotlin.Any.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json


Root

Root endpoint.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
val webService = apiClient.createWebservice(DefaultApi::class.java)

launch(Dispatchers.IO) {
    val result : kotlin.Any = webService.rootGet()
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**kotlin.Any**](kotlin.Any.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json


Serve Wechat Verification

Serve WeChat domain verification files from static directory.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
val webService = apiClient.createWebservice(DefaultApi::class.java)
val filename : kotlin.String = filename_example // kotlin.String | 

launch(Dispatchers.IO) {
    val result : kotlin.Any = webService.serveWechatVerificationFilenameGet(filename)
}
```

### Parameters
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **filename** | **kotlin.String**|  | |

### Return type

[**kotlin.Any**](kotlin.Any.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

