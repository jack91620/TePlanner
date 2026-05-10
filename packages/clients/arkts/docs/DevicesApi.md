# DevicesApi

All URIs are relative to *http://localhost*

| Method | HTTP request | Description |
|------------- | ------------- | -------------|
| [**registerDeviceApiV1DevicesRegisterPost**](DevicesApi.md#registerdeviceapiv1devicesregisterpost) | **POST** /api/v1/devices/register | Register Device |
| [**runAutomationTickApiV1DevicesRunAutomationTickPost**](DevicesApi.md#runautomationtickapiv1devicesrunautomationtickpost) | **POST** /api/v1/devices/run-automation-tick | Run Automation Tick |
| [**testPushApiV1DevicesTestPushPost**](DevicesApi.md#testpushapiv1devicestestpushpost) | **POST** /api/v1/devices/test-push | Test Push |



## registerDeviceApiV1DevicesRegisterPost

> RegisterDeviceResponse registerDeviceApiV1DevicesRegisterPost(registerDeviceRequest)

Register Device

Upsert (user_id, token). Re-registering an existing token just bumps last_seen_at — that lets the polling layer prune stale rows later (e.g. tokens not seen for 30 days are likely uninstalled).

### Example

```ts
import {
  Configuration,
  DevicesApi,
} from '@teplanner/sdk';
import type { RegisterDeviceApiV1DevicesRegisterPostRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new DevicesApi(config);

  const body = {
    // RegisterDeviceRequest
    registerDeviceRequest: ...,
  } satisfies RegisterDeviceApiV1DevicesRegisterPostRequest;

  try {
    const data = await api.registerDeviceApiV1DevicesRegisterPost(body);
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
| **registerDeviceRequest** | [RegisterDeviceRequest](RegisterDeviceRequest.md) |  | |

### Return type

[**RegisterDeviceResponse**](RegisterDeviceResponse.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

- **Content-Type**: `application/json`
- **Accept**: `application/json`


### HTTP response details
| Status code | Description | Response headers |
|-------------|-------------|------------------|
| **200** | Successful Response |  -  |
| **422** | Validation Error |  -  |

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


## runAutomationTickApiV1DevicesRunAutomationTickPost

> object runAutomationTickApiV1DevicesRunAutomationTickPost()

Run Automation Tick

Trigger a single polling tick on demand. Used for end-to-end debugging: hit this, watch server.log, verify a push lands. Doesn\&#39;t take args — runs the full eligible-user loop.

### Example

```ts
import {
  Configuration,
  DevicesApi,
} from '@teplanner/sdk';
import type { RunAutomationTickApiV1DevicesRunAutomationTickPostRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new DevicesApi(config);

  try {
    const data = await api.runAutomationTickApiV1DevicesRunAutomationTickPost();
    console.log(data);
  } catch (error) {
    console.error(error);
  }
}

// Run the test
example().catch(console.error);
```

### Parameters

This endpoint does not need any parameter.

### Return type

**object**

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: `application/json`


### HTTP response details
| Status code | Description | Response headers |
|-------------|-------------|------------------|
| **200** | Successful Response |  -  |

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


## testPushApiV1DevicesTestPushPost

> object testPushApiV1DevicesTestPushPost(testPushRequest)

Test Push

Send a debug push to all of this user\&#39;s registered devices. Phase E — routes through PushDispatcher so APNs / JPush / Huawei Push Kit all receive it according to each token\&#39;s platform field.

### Example

```ts
import {
  Configuration,
  DevicesApi,
} from '@teplanner/sdk';
import type { TestPushApiV1DevicesTestPushPostRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new DevicesApi(config);

  const body = {
    // TestPushRequest
    testPushRequest: ...,
  } satisfies TestPushApiV1DevicesTestPushPostRequest;

  try {
    const data = await api.testPushApiV1DevicesTestPushPost(body);
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
| **testPushRequest** | [TestPushRequest](TestPushRequest.md) |  | |

### Return type

**object**

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

- **Content-Type**: `application/json`
- **Accept**: `application/json`


### HTTP response details
| Status code | Description | Response headers |
|-------------|-------------|------------------|
| **200** | Successful Response |  -  |
| **422** | Validation Error |  -  |

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)

