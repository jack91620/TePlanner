# DefaultAPI

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**healthCheckHealthGet**](DefaultAPI.md#healthcheckhealthget) | **GET** /health | Health Check
[**rootGet**](DefaultAPI.md#rootget) | **GET** / | Root
[**serveWechatVerificationFilenameGet**](DefaultAPI.md#servewechatverificationfilenameget) | **GET** /{filename} | Serve Wechat Verification


# **healthCheckHealthGet**
```swift
    open class func healthCheckHealthGet(completion: @escaping (_ data: AnyCodable?, _ error: Error?) -> Void)
```

Health Check

Health check endpoint. Returns app version + status — the `version` field is consumed by `tests/test_health.py` and surfaced in the `ops/server-monitor.sh` snapshot for cross- referencing post-deploy. Source: `app.config.settings.APP_VERSION` if defined, falling back to '0.0.0' for local runs.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI


// Health Check
DefaultAPI.healthCheckHealthGet() { (response, error) in
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

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **rootGet**
```swift
    open class func rootGet(completion: @escaping (_ data: AnyCodable?, _ error: Error?) -> Void)
```

Root

Root endpoint.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI


// Root
DefaultAPI.rootGet() { (response, error) in
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

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **serveWechatVerificationFilenameGet**
```swift
    open class func serveWechatVerificationFilenameGet(filename: String, completion: @escaping (_ data: AnyCodable?, _ error: Error?) -> Void)
```

Serve Wechat Verification

Serve WeChat domain verification files from static directory.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let filename = "filename_example" // String | 

// Serve Wechat Verification
DefaultAPI.serveWechatVerificationFilenameGet(filename: filename) { (response, error) in
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
 **filename** | **String** |  | 

### Return type

**AnyCodable**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

