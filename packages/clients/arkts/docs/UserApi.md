# UserApi

All URIs are relative to *http://localhost*

| Method | HTTP request | Description |
|------------- | ------------- | -------------|
| [**clearScheduledDepartureApiV1UserScheduledDepartureDelete**](UserApi.md#clearscheduleddepartureapiv1userscheduleddeparturedelete) | **DELETE** /api/v1/user/scheduled-departure | Clear Scheduled Departure |
| [**getScheduledDepartureApiV1UserScheduledDepartureGet**](UserApi.md#getscheduleddepartureapiv1userscheduleddepartureget) | **GET** /api/v1/user/scheduled-departure | Get Scheduled Departure |
| [**getUserSettingsApiV1UserSettingsGet**](UserApi.md#getusersettingsapiv1usersettingsget) | **GET** /api/v1/user/settings | Get User Settings |
| [**upsertScheduledDepartureApiV1UserScheduledDeparturePut**](UserApi.md#upsertscheduleddepartureapiv1userscheduleddepartureput) | **PUT** /api/v1/user/scheduled-departure | Upsert Scheduled Departure |
| [**upsertUserSettingsApiV1UserSettingsPut**](UserApi.md#upsertusersettingsapiv1usersettingsput) | **PUT** /api/v1/user/settings | Upsert User Settings |



## clearScheduledDepartureApiV1UserScheduledDepartureDelete

> object clearScheduledDepartureApiV1UserScheduledDepartureDelete()

Clear Scheduled Departure

Idempotent — clearing a non-existent row is a 200, not 404.

### Example

```ts
import {
  Configuration,
  UserApi,
} from '@teplanner/sdk';
import type { ClearScheduledDepartureApiV1UserScheduledDepartureDeleteRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new UserApi(config);

  try {
    const data = await api.clearScheduledDepartureApiV1UserScheduledDepartureDelete();
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


## getScheduledDepartureApiV1UserScheduledDepartureGet

> ScheduledDepartureResponse getScheduledDepartureApiV1UserScheduledDepartureGet()

Get Scheduled Departure

Fetch the user\&#39;s active scheduled departure. Returns &#x60;&#x60;null&#x60;&#x60; when none is set — iOS treats null as \&quot;not scheduled\&quot; and shows the empty card.

### Example

```ts
import {
  Configuration,
  UserApi,
} from '@teplanner/sdk';
import type { GetScheduledDepartureApiV1UserScheduledDepartureGetRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new UserApi(config);

  try {
    const data = await api.getScheduledDepartureApiV1UserScheduledDepartureGet();
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

[**ScheduledDepartureResponse**](ScheduledDepartureResponse.md)

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


## getUserSettingsApiV1UserSettingsGet

> UserSettingsResponse getUserSettingsApiV1UserSettingsGet()

Get User Settings

Return the user\&#39;s full settings dict. Empty dict when never set. &#x60;updated_at&#x60; is the most recent row update — clients use it to short-circuit re-fetches.

### Example

```ts
import {
  Configuration,
  UserApi,
} from '@teplanner/sdk';
import type { GetUserSettingsApiV1UserSettingsGetRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new UserApi(config);

  try {
    const data = await api.getUserSettingsApiV1UserSettingsGet();
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

[**UserSettingsResponse**](UserSettingsResponse.md)

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


## upsertScheduledDepartureApiV1UserScheduledDeparturePut

> ScheduledDepartureResponse upsertScheduledDepartureApiV1UserScheduledDeparturePut(scheduledDepartureRequest)

Upsert Scheduled Departure

Replace the user\&#39;s scheduled departure with the supplied row. UNIQUE(user_id) enforces single-row semantics; we update in place when a row already exists rather than relying on the DB unique error to bubble up.  Past departures are accepted — the iOS UI prevents them, but a server reject would race with clock skew and break preheat cancellation flows.

### Example

```ts
import {
  Configuration,
  UserApi,
} from '@teplanner/sdk';
import type { UpsertScheduledDepartureApiV1UserScheduledDeparturePutRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new UserApi(config);

  const body = {
    // ScheduledDepartureRequest
    scheduledDepartureRequest: ...,
  } satisfies UpsertScheduledDepartureApiV1UserScheduledDeparturePutRequest;

  try {
    const data = await api.upsertScheduledDepartureApiV1UserScheduledDeparturePut(body);
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
| **scheduledDepartureRequest** | [ScheduledDepartureRequest](ScheduledDepartureRequest.md) |  | |

### Return type

[**ScheduledDepartureResponse**](ScheduledDepartureResponse.md)

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


## upsertUserSettingsApiV1UserSettingsPut

> UserSettingsResponse upsertUserSettingsApiV1UserSettingsPut(userSettingsRequest)

Upsert User Settings

Merge &#x60;&#x60;body.settings&#x60;&#x60; into the user\&#39;s settings dict (or replace entirely if &#x60;&#x60;replace_all&#x3D;true&#x60;&#x60;). Each value is JSON-encoded for storage. Keys longer than 80 chars or empty are rejected (matches column constraint).

### Example

```ts
import {
  Configuration,
  UserApi,
} from '@teplanner/sdk';
import type { UpsertUserSettingsApiV1UserSettingsPutRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new UserApi(config);

  const body = {
    // UserSettingsRequest
    userSettingsRequest: ...,
  } satisfies UpsertUserSettingsApiV1UserSettingsPutRequest;

  try {
    const data = await api.upsertUserSettingsApiV1UserSettingsPut(body);
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
| **userSettingsRequest** | [UserSettingsRequest](UserSettingsRequest.md) |  | |

### Return type

[**UserSettingsResponse**](UserSettingsResponse.md)

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

