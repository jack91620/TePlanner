# DevicesAPI

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**registerDeviceApiV1DevicesRegisterPost**](DevicesAPI.md#registerdeviceapiv1devicesregisterpost) | **POST** /api/v1/devices/register | Register Device
[**runAutomationTickApiV1DevicesRunAutomationTickPost**](DevicesAPI.md#runautomationtickapiv1devicesrunautomationtickpost) | **POST** /api/v1/devices/run-automation-tick | Run Automation Tick
[**testPushApiV1DevicesTestPushPost**](DevicesAPI.md#testpushapiv1devicestestpushpost) | **POST** /api/v1/devices/test-push | Test Push


# **registerDeviceApiV1DevicesRegisterPost**
```swift
    open class func registerDeviceApiV1DevicesRegisterPost(registerDeviceRequest: RegisterDeviceRequest, completion: @escaping (_ data: RegisterDeviceResponse?, _ error: Error?) -> Void)
```

Register Device

Upsert (user_id, token). Re-registering an existing token just bumps last_seen_at — that lets the polling layer prune stale rows later (e.g. tokens not seen for 30 days are likely uninstalled).

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let registerDeviceRequest = RegisterDeviceRequest(bundleId: "bundleId_example", token: "token_example") // RegisterDeviceRequest | 

// Register Device
DevicesAPI.registerDeviceApiV1DevicesRegisterPost(registerDeviceRequest: registerDeviceRequest) { (response, error) in
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
 **registerDeviceRequest** | [**RegisterDeviceRequest**](RegisterDeviceRequest.md) |  | 

### Return type

[**RegisterDeviceResponse**](RegisterDeviceResponse.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **runAutomationTickApiV1DevicesRunAutomationTickPost**
```swift
    open class func runAutomationTickApiV1DevicesRunAutomationTickPost(completion: @escaping (_ data: AnyCodable?, _ error: Error?) -> Void)
```

Run Automation Tick

Trigger a single polling tick on demand. Used for end-to-end debugging: hit this, watch server.log, verify a push lands. Doesn't take args — runs the full eligible-user loop.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI


// Run Automation Tick
DevicesAPI.runAutomationTickApiV1DevicesRunAutomationTickPost() { (response, error) in
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

# **testPushApiV1DevicesTestPushPost**
```swift
    open class func testPushApiV1DevicesTestPushPost(testPushRequest: TestPushRequest, completion: @escaping (_ data: AnyCodable?, _ error: Error?) -> Void)
```

Test Push

Send a debug push to all of this user's registered devices. Useful while wiring up — flip APNs creds, hit this endpoint, see if a notification lands on the phone.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let testPushRequest = TestPushRequest(body: "body_example", title: "title_example") // TestPushRequest | 

// Test Push
DevicesAPI.testPushApiV1DevicesTestPushPost(testPushRequest: testPushRequest) { (response, error) in
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
 **testPushRequest** | [**TestPushRequest**](TestPushRequest.md) |  | 

### Return type

**AnyCodable**

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

