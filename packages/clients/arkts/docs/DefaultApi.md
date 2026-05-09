# DefaultApi

All URIs are relative to *http://localhost*

| Method | HTTP request | Description |
|------------- | ------------- | -------------|
| [**healthCheckHealthGet**](DefaultApi.md#healthcheckhealthget) | **GET** /health | Health Check |
| [**rootGet**](DefaultApi.md#rootget) | **GET** / | Root |
| [**serveWechatVerificationFilenameGet**](DefaultApi.md#servewechatverificationfilenameget) | **GET** /{filename} | Serve Wechat Verification |



## healthCheckHealthGet

> any healthCheckHealthGet()

Health Check

Health check endpoint. Returns app version + status — the &#x60;version&#x60; field is consumed by &#x60;tests/test_health.py&#x60; and surfaced in the &#x60;ops/server-monitor.sh&#x60; snapshot for cross- referencing post-deploy. Source: &#x60;app.config.settings.APP_VERSION&#x60; if defined, falling back to \&#39;0.0.0\&#39; for local runs.

### Example

```ts
import {
  Configuration,
  DefaultApi,
} from '@teplanner/sdk';
import type { HealthCheckHealthGetRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const api = new DefaultApi();

  try {
    const data = await api.healthCheckHealthGet();
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

**any**

### Authorization

No authorization required

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: `application/json`


### HTTP response details
| Status code | Description | Response headers |
|-------------|-------------|------------------|
| **200** | Successful Response |  -  |

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


## rootGet

> any rootGet()

Root

Root endpoint.

### Example

```ts
import {
  Configuration,
  DefaultApi,
} from '@teplanner/sdk';
import type { RootGetRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const api = new DefaultApi();

  try {
    const data = await api.rootGet();
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

**any**

### Authorization

No authorization required

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: `application/json`


### HTTP response details
| Status code | Description | Response headers |
|-------------|-------------|------------------|
| **200** | Successful Response |  -  |

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


## serveWechatVerificationFilenameGet

> any serveWechatVerificationFilenameGet(filename)

Serve Wechat Verification

Serve WeChat domain verification files from static directory.

### Example

```ts
import {
  Configuration,
  DefaultApi,
} from '@teplanner/sdk';
import type { ServeWechatVerificationFilenameGetRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const api = new DefaultApi();

  const body = {
    // string
    filename: filename_example,
  } satisfies ServeWechatVerificationFilenameGetRequest;

  try {
    const data = await api.serveWechatVerificationFilenameGet(body);
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
| **filename** | `string` |  | [Defaults to `undefined`] |

### Return type

**any**

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

