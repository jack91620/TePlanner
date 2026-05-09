# VehiclesApi

All URIs are relative to *http://localhost*

| Method | HTTP request | Description |
|------------- | ------------- | -------------|
| [**cancelQueuedCommandApiV1VehiclesCommandsQueuedQueuedIdDelete**](VehiclesApi.md#cancelqueuedcommandapiv1vehiclescommandsqueuedqueuediddelete) | **DELETE** /api/v1/vehicles/commands/queued/{queued_id} | Cancel Queued Command |
| [**getVehicleApiV1VehiclesVehicleIdGet**](VehiclesApi.md#getvehicleapiv1vehiclesvehicleidget) | **GET** /api/v1/vehicles/{vehicle_id} | Get Vehicle |
| [**getVehicleStateApiV1VehiclesVehicleIdStateGet**](VehiclesApi.md#getvehiclestateapiv1vehiclesvehicleidstateget) | **GET** /api/v1/vehicles/{vehicle_id}/state | Get Vehicle State |
| [**listChargingSessionsApiV1VehiclesVehicleIdSessionsGet**](VehiclesApi.md#listchargingsessionsapiv1vehiclesvehicleidsessionsget) | **GET** /api/v1/vehicles/{vehicle_id}/sessions | List Charging Sessions |
| [**listPendingCommandsApiV1VehiclesCommandsPendingGet**](VehiclesApi.md#listpendingcommandsapiv1vehiclescommandspendingget) | **GET** /api/v1/vehicles/commands/pending | List Pending Commands |
| [**listQueuedCommandsApiV1VehiclesCommandsQueuedGet**](VehiclesApi.md#listqueuedcommandsapiv1vehiclescommandsqueuedget) | **GET** /api/v1/vehicles/commands/queued | List Queued Commands |
| [**listVehiclesApiV1VehiclesGet**](VehiclesApi.md#listvehiclesapiv1vehiclesget) | **GET** /api/v1/vehicles/ | List Vehicles |
| [**navigateVehicleAddressApiV1VehiclesVehicleIdNavigateAddressPost**](VehiclesApi.md#navigatevehicleaddressapiv1vehiclesvehicleidnavigateaddresspost) | **POST** /api/v1/vehicles/{vehicle_id}/navigate/address | Navigate Vehicle Address |
| [**navigateVehicleApiV1VehiclesVehicleIdNavigatePost**](VehiclesApi.md#navigatevehicleapiv1vehiclesvehicleidnavigatepost) | **POST** /api/v1/vehicles/{vehicle_id}/navigate | Navigate Vehicle |
| [**preheatVehicleApiV1VehiclesVehicleIdPreheatPost**](VehiclesApi.md#preheatvehicleapiv1vehiclesvehicleidpreheatpost) | **POST** /api/v1/vehicles/{vehicle_id}/preheat | Preheat Vehicle |
| [**setChargeLimitApiV1VehiclesVehicleIdChargeLimitPost**](VehiclesApi.md#setchargelimitapiv1vehiclesvehicleidchargelimitpost) | **POST** /api/v1/vehicles/{vehicle_id}/charge-limit | Set Charge Limit |
| [**setClimateKeeperModeApiV1VehiclesVehicleIdClimateKeeperModePost**](VehiclesApi.md#setclimatekeepermodeapiv1vehiclesvehicleidclimatekeepermodepost) | **POST** /api/v1/vehicles/{vehicle_id}/climate-keeper-mode | Set Climate Keeper Mode |
| [**setPrimaryVehicleApiV1VehiclesVehicleIdSetPrimaryPost**](VehiclesApi.md#setprimaryvehicleapiv1vehiclesvehicleidsetprimarypost) | **POST** /api/v1/vehicles/{vehicle_id}/set-primary | Set Primary Vehicle |
| [**setSentryModeApiV1VehiclesVehicleIdSentryModePost**](VehiclesApi.md#setsentrymodeapiv1vehiclesvehicleidsentrymodepost) | **POST** /api/v1/vehicles/{vehicle_id}/sentry-mode | Set Sentry Mode |
| [**suggestChargeLimitEndpointApiV1VehiclesVehicleIdSuggestChargeLimitPost**](VehiclesApi.md#suggestchargelimitendpointapiv1vehiclesvehicleidsuggestchargelimitpost) | **POST** /api/v1/vehicles/{vehicle_id}/suggest-charge-limit | Suggest Charge Limit Endpoint |
| [**upsertChargingSessionApiV1VehiclesVehicleIdSessionsPost**](VehiclesApi.md#upsertchargingsessionapiv1vehiclesvehicleidsessionspost) | **POST** /api/v1/vehicles/{vehicle_id}/sessions | Upsert Charging Session |
| [**wakeVehicleApiV1VehiclesVehicleIdWakePost**](VehiclesApi.md#wakevehicleapiv1vehiclesvehicleidwakepost) | **POST** /api/v1/vehicles/{vehicle_id}/wake | Wake Vehicle |



## cancelQueuedCommandApiV1VehiclesCommandsQueuedQueuedIdDelete

> object cancelQueuedCommandApiV1VehiclesCommandsQueuedQueuedIdDelete(queuedId)

Cancel Queued Command

Cancel a still-queued command before it drains. 404 if the user doesn\&#39;t own it; 409 if it\&#39;s already been sent/dropped.

### Example

```ts
import {
  Configuration,
  VehiclesApi,
} from '@teplanner/sdk';
import type { CancelQueuedCommandApiV1VehiclesCommandsQueuedQueuedIdDeleteRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new VehiclesApi(config);

  const body = {
    // number
    queuedId: 56,
  } satisfies CancelQueuedCommandApiV1VehiclesCommandsQueuedQueuedIdDeleteRequest;

  try {
    const data = await api.cancelQueuedCommandApiV1VehiclesCommandsQueuedQueuedIdDelete(body);
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
| **queuedId** | `number` |  | [Defaults to `undefined`] |

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
| **422** | Validation Error |  -  |

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


## getVehicleApiV1VehiclesVehicleIdGet

> VehicleResponse getVehicleApiV1VehiclesVehicleIdGet(vehicleId)

Get Vehicle

Get specific vehicle details.

### Example

```ts
import {
  Configuration,
  VehiclesApi,
} from '@teplanner/sdk';
import type { GetVehicleApiV1VehiclesVehicleIdGetRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new VehiclesApi(config);

  const body = {
    // string
    vehicleId: vehicleId_example,
  } satisfies GetVehicleApiV1VehiclesVehicleIdGetRequest;

  try {
    const data = await api.getVehicleApiV1VehiclesVehicleIdGet(body);
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
| **vehicleId** | `string` |  | [Defaults to `undefined`] |

### Return type

[**VehicleResponse**](VehicleResponse.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: `application/json`


### HTTP response details
| Status code | Description | Response headers |
|-------------|-------------|------------------|
| **200** | Successful Response |  -  |
| **422** | Validation Error |  -  |

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


## getVehicleStateApiV1VehiclesVehicleIdStateGet

> VehicleStateResponse getVehicleStateApiV1VehiclesVehicleIdStateGet(vehicleId)

Get Vehicle State

Get vehicle state (battery, location, etc.).  Returns real-time vehicle data including: - Battery level and range - Current location (GPS) - Charging state - Climate status

### Example

```ts
import {
  Configuration,
  VehiclesApi,
} from '@teplanner/sdk';
import type { GetVehicleStateApiV1VehiclesVehicleIdStateGetRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new VehiclesApi(config);

  const body = {
    // string
    vehicleId: vehicleId_example,
  } satisfies GetVehicleStateApiV1VehiclesVehicleIdStateGetRequest;

  try {
    const data = await api.getVehicleStateApiV1VehiclesVehicleIdStateGet(body);
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
| **vehicleId** | `string` |  | [Defaults to `undefined`] |

### Return type

[**VehicleStateResponse**](VehicleStateResponse.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: `application/json`


### HTTP response details
| Status code | Description | Response headers |
|-------------|-------------|------------------|
| **200** | Successful Response |  -  |
| **422** | Validation Error |  -  |

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


## listChargingSessionsApiV1VehiclesVehicleIdSessionsGet

> ChargingSessionListResponse listChargingSessionsApiV1VehiclesVehicleIdSessionsGet(vehicleId, limit)

List Charging Sessions

Most-recent-first session list. Default limit 50 covers ~6 weeks of typical daily-charging owners; clients pass &#x60;?limit&#x3D;N&#x60; to dig further. Strict per-user filter so a vehicle_id collision (Tesla sometimes recycles ids across accounts) can\&#39;t leak rows.

### Example

```ts
import {
  Configuration,
  VehiclesApi,
} from '@teplanner/sdk';
import type { ListChargingSessionsApiV1VehiclesVehicleIdSessionsGetRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new VehiclesApi(config);

  const body = {
    // string
    vehicleId: vehicleId_example,
    // number (optional)
    limit: 56,
  } satisfies ListChargingSessionsApiV1VehiclesVehicleIdSessionsGetRequest;

  try {
    const data = await api.listChargingSessionsApiV1VehiclesVehicleIdSessionsGet(body);
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
| **vehicleId** | `string` |  | [Defaults to `undefined`] |
| **limit** | `number` |  | [Optional] [Defaults to `50`] |

### Return type

[**ChargingSessionListResponse**](ChargingSessionListResponse.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: `application/json`


### HTTP response details
| Status code | Description | Response headers |
|-------------|-------------|------------------|
| **200** | Successful Response |  -  |
| **422** | Validation Error |  -  |

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


## listPendingCommandsApiV1VehiclesCommandsPendingGet

> PendingCommandListResponse listPendingCommandsApiV1VehiclesCommandsPendingGet(limit)

List Pending Commands

Phase 9 — what VCP commands sent in the last few minutes are still awaiting telemetry confirmation, plus the most recently resolved ones for the iOS UI to flip to \&quot;已关闭\&quot; / \&quot;超时\&quot;.  The resolver runs server-side on every Telemetry frame, so a well-timed poll right after dispatch will see the row transition pending → confirmed within ~1-2 s of the actual state change.

### Example

```ts
import {
  Configuration,
  VehiclesApi,
} from '@teplanner/sdk';
import type { ListPendingCommandsApiV1VehiclesCommandsPendingGetRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new VehiclesApi(config);

  const body = {
    // number (optional)
    limit: 56,
  } satisfies ListPendingCommandsApiV1VehiclesCommandsPendingGetRequest;

  try {
    const data = await api.listPendingCommandsApiV1VehiclesCommandsPendingGet(body);
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
| **limit** | `number` |  | [Optional] [Defaults to `20`] |

### Return type

[**PendingCommandListResponse**](PendingCommandListResponse.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: `application/json`


### HTTP response details
| Status code | Description | Response headers |
|-------------|-------------|------------------|
| **200** | Successful Response |  -  |
| **422** | Validation Error |  -  |

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


## listQueuedCommandsApiV1VehiclesCommandsQueuedGet

> QueuedCommandListResponse listQueuedCommandsApiV1VehiclesCommandsQueuedGet(limit)

List Queued Commands

Return commands waiting on the car\&#39;s next CONNECTED telemetry event, plus recently-resolved ones for the iOS UI to flip badges.

### Example

```ts
import {
  Configuration,
  VehiclesApi,
} from '@teplanner/sdk';
import type { ListQueuedCommandsApiV1VehiclesCommandsQueuedGetRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new VehiclesApi(config);

  const body = {
    // number (optional)
    limit: 56,
  } satisfies ListQueuedCommandsApiV1VehiclesCommandsQueuedGetRequest;

  try {
    const data = await api.listQueuedCommandsApiV1VehiclesCommandsQueuedGet(body);
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
| **limit** | `number` |  | [Optional] [Defaults to `20`] |

### Return type

[**QueuedCommandListResponse**](QueuedCommandListResponse.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: `application/json`


### HTTP response details
| Status code | Description | Response headers |
|-------------|-------------|------------------|
| **200** | Successful Response |  -  |
| **422** | Validation Error |  -  |

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


## listVehiclesApiV1VehiclesGet

> VehicleListResponse listVehiclesApiV1VehiclesGet()

List Vehicles

List user\&#39;s Tesla vehicles, syncing the local Vehicle table. Logic in services/vehicle_sync_service.sync_vehicles.

### Example

```ts
import {
  Configuration,
  VehiclesApi,
} from '@teplanner/sdk';
import type { ListVehiclesApiV1VehiclesGetRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new VehiclesApi(config);

  try {
    const data = await api.listVehiclesApiV1VehiclesGet();
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

[**VehicleListResponse**](VehicleListResponse.md)

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


## navigateVehicleAddressApiV1VehiclesVehicleIdNavigateAddressPost

> any navigateVehicleAddressApiV1VehiclesVehicleIdNavigateAddressPost(vehicleId, navigationAddressRequest)

Navigate Vehicle Address

Send navigation destination by address to vehicle.  Sends address string to the vehicle\&#39;s navigation system. Vehicle must be online.

### Example

```ts
import {
  Configuration,
  VehiclesApi,
} from '@teplanner/sdk';
import type { NavigateVehicleAddressApiV1VehiclesVehicleIdNavigateAddressPostRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new VehiclesApi(config);

  const body = {
    // string
    vehicleId: vehicleId_example,
    // NavigationAddressRequest
    navigationAddressRequest: ...,
  } satisfies NavigateVehicleAddressApiV1VehiclesVehicleIdNavigateAddressPostRequest;

  try {
    const data = await api.navigateVehicleAddressApiV1VehiclesVehicleIdNavigateAddressPost(body);
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
| **vehicleId** | `string` |  | [Defaults to `undefined`] |
| **navigationAddressRequest** | [NavigationAddressRequest](NavigationAddressRequest.md) |  | |

### Return type

**any**

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


## navigateVehicleApiV1VehiclesVehicleIdNavigatePost

> any navigateVehicleApiV1VehiclesVehicleIdNavigatePost(vehicleId, navigationRequest)

Navigate Vehicle

Send GPS coordinates to vehicle nav. Dispatches through capability registry. Uses numeric vehicle_id (not VIN) since navigation_gps_request is one of the few endpoints not on the VCP-signed path.

### Example

```ts
import {
  Configuration,
  VehiclesApi,
} from '@teplanner/sdk';
import type { NavigateVehicleApiV1VehiclesVehicleIdNavigatePostRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new VehiclesApi(config);

  const body = {
    // string
    vehicleId: vehicleId_example,
    // NavigationRequest
    navigationRequest: ...,
  } satisfies NavigateVehicleApiV1VehiclesVehicleIdNavigatePostRequest;

  try {
    const data = await api.navigateVehicleApiV1VehiclesVehicleIdNavigatePost(body);
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
| **vehicleId** | `string` |  | [Defaults to `undefined`] |
| **navigationRequest** | [NavigationRequest](NavigationRequest.md) |  | |

### Return type

**any**

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


## preheatVehicleApiV1VehiclesVehicleIdPreheatPost

> any preheatVehicleApiV1VehiclesVehicleIdPreheatPost(vehicleId)

Preheat Vehicle

Start HVAC (auto_conditioning_start) so the cabin is at temperature on arrival. Used by 出发前预热. Dispatches through capability registry.

### Example

```ts
import {
  Configuration,
  VehiclesApi,
} from '@teplanner/sdk';
import type { PreheatVehicleApiV1VehiclesVehicleIdPreheatPostRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new VehiclesApi(config);

  const body = {
    // string
    vehicleId: vehicleId_example,
  } satisfies PreheatVehicleApiV1VehiclesVehicleIdPreheatPostRequest;

  try {
    const data = await api.preheatVehicleApiV1VehiclesVehicleIdPreheatPost(body);
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
| **vehicleId** | `string` |  | [Defaults to `undefined`] |

### Return type

**any**

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: `application/json`


### HTTP response details
| Status code | Description | Response headers |
|-------------|-------------|------------------|
| **200** | Successful Response |  -  |
| **422** | Validation Error |  -  |

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


## setChargeLimitApiV1VehiclesVehicleIdChargeLimitPost

> any setChargeLimitApiV1VehiclesVehicleIdChargeLimitPost(vehicleId, chargeLimitRequest)

Set Charge Limit

Set the vehicle\&#39;s charge limit SOC percent (50..100). Dispatches through capability registry.

### Example

```ts
import {
  Configuration,
  VehiclesApi,
} from '@teplanner/sdk';
import type { SetChargeLimitApiV1VehiclesVehicleIdChargeLimitPostRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new VehiclesApi(config);

  const body = {
    // string
    vehicleId: vehicleId_example,
    // ChargeLimitRequest
    chargeLimitRequest: ...,
  } satisfies SetChargeLimitApiV1VehiclesVehicleIdChargeLimitPostRequest;

  try {
    const data = await api.setChargeLimitApiV1VehiclesVehicleIdChargeLimitPost(body);
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
| **vehicleId** | `string` |  | [Defaults to `undefined`] |
| **chargeLimitRequest** | [ChargeLimitRequest](ChargeLimitRequest.md) |  | |

### Return type

**any**

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


## setClimateKeeperModeApiV1VehiclesVehicleIdClimateKeeperModePost

> any setClimateKeeperModeApiV1VehiclesVehicleIdClimateKeeperModePost(vehicleId, climateKeeperModeRequest)

Set Climate Keeper Mode

Set climate keeper mode. 0&#x3D;off / 1&#x3D;keep / 2&#x3D;dog / 3&#x3D;camp. Dispatches through capability registry.

### Example

```ts
import {
  Configuration,
  VehiclesApi,
} from '@teplanner/sdk';
import type { SetClimateKeeperModeApiV1VehiclesVehicleIdClimateKeeperModePostRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new VehiclesApi(config);

  const body = {
    // string
    vehicleId: vehicleId_example,
    // ClimateKeeperModeRequest
    climateKeeperModeRequest: ...,
  } satisfies SetClimateKeeperModeApiV1VehiclesVehicleIdClimateKeeperModePostRequest;

  try {
    const data = await api.setClimateKeeperModeApiV1VehiclesVehicleIdClimateKeeperModePost(body);
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
| **vehicleId** | `string` |  | [Defaults to `undefined`] |
| **climateKeeperModeRequest** | [ClimateKeeperModeRequest](ClimateKeeperModeRequest.md) |  | |

### Return type

**any**

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


## setPrimaryVehicleApiV1VehiclesVehicleIdSetPrimaryPost

> any setPrimaryVehicleApiV1VehiclesVehicleIdSetPrimaryPost(vehicleId)

Set Primary Vehicle

Set vehicle as primary for the user.  Only one vehicle can be primary at a time.

### Example

```ts
import {
  Configuration,
  VehiclesApi,
} from '@teplanner/sdk';
import type { SetPrimaryVehicleApiV1VehiclesVehicleIdSetPrimaryPostRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new VehiclesApi(config);

  const body = {
    // string
    vehicleId: vehicleId_example,
  } satisfies SetPrimaryVehicleApiV1VehiclesVehicleIdSetPrimaryPostRequest;

  try {
    const data = await api.setPrimaryVehicleApiV1VehiclesVehicleIdSetPrimaryPost(body);
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
| **vehicleId** | `string` |  | [Defaults to `undefined`] |

### Return type

**any**

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: `application/json`


### HTTP response details
| Status code | Description | Response headers |
|-------------|-------------|------------------|
| **200** | Successful Response |  -  |
| **422** | Validation Error |  -  |

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


## setSentryModeApiV1VehiclesVehicleIdSentryModePost

> any setSentryModeApiV1VehiclesVehicleIdSentryModePost(vehicleId, sentryModeRequest)

Set Sentry Mode

Toggle sentry mode. Dispatches through capability registry.

### Example

```ts
import {
  Configuration,
  VehiclesApi,
} from '@teplanner/sdk';
import type { SetSentryModeApiV1VehiclesVehicleIdSentryModePostRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new VehiclesApi(config);

  const body = {
    // string
    vehicleId: vehicleId_example,
    // SentryModeRequest
    sentryModeRequest: ...,
  } satisfies SetSentryModeApiV1VehiclesVehicleIdSentryModePostRequest;

  try {
    const data = await api.setSentryModeApiV1VehiclesVehicleIdSentryModePost(body);
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
| **vehicleId** | `string` |  | [Defaults to `undefined`] |
| **sentryModeRequest** | [SentryModeRequest](SentryModeRequest.md) |  | |

### Return type

**any**

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


## suggestChargeLimitEndpointApiV1VehiclesVehicleIdSuggestChargeLimitPost

> SuggestChargeLimitResponse suggestChargeLimitEndpointApiV1VehiclesVehicleIdSuggestChargeLimitPost(vehicleId, suggestChargeLimitRequest)

Suggest Charge Limit Endpoint

Server-side mirror of iOS ChargeLimitSuggester. Reads the user\&#39;s currently-stored ScheduledDeparture (A.3) to find any upcoming trip; daily/trip preferences come from the request body (Phase D will read them from /user/settings instead).

### Example

```ts
import {
  Configuration,
  VehiclesApi,
} from '@teplanner/sdk';
import type { SuggestChargeLimitEndpointApiV1VehiclesVehicleIdSuggestChargeLimitPostRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new VehiclesApi(config);

  const body = {
    // string
    vehicleId: vehicleId_example,
    // SuggestChargeLimitRequest
    suggestChargeLimitRequest: ...,
  } satisfies SuggestChargeLimitEndpointApiV1VehiclesVehicleIdSuggestChargeLimitPostRequest;

  try {
    const data = await api.suggestChargeLimitEndpointApiV1VehiclesVehicleIdSuggestChargeLimitPost(body);
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
| **vehicleId** | `string` |  | [Defaults to `undefined`] |
| **suggestChargeLimitRequest** | [SuggestChargeLimitRequest](SuggestChargeLimitRequest.md) |  | |

### Return type

[**SuggestChargeLimitResponse**](SuggestChargeLimitResponse.md)

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


## upsertChargingSessionApiV1VehiclesVehicleIdSessionsPost

> ChargingSessionResponse upsertChargingSessionApiV1VehiclesVehicleIdSessionsPost(vehicleId, chargingSessionRequest)

Upsert Charging Session

Create or update a charging session.  iOS POSTs once on plug-in (ended_at NULL) and again on plug-out (ended_at set). Server upserts on &#x60;&#x60;client_session_id&#x60;&#x60; so retries are safe; if absent (legacy iOS builds), every POST creates a new row — acceptable trade-off but fix client-side first.

### Example

```ts
import {
  Configuration,
  VehiclesApi,
} from '@teplanner/sdk';
import type { UpsertChargingSessionApiV1VehiclesVehicleIdSessionsPostRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new VehiclesApi(config);

  const body = {
    // string
    vehicleId: vehicleId_example,
    // ChargingSessionRequest
    chargingSessionRequest: ...,
  } satisfies UpsertChargingSessionApiV1VehiclesVehicleIdSessionsPostRequest;

  try {
    const data = await api.upsertChargingSessionApiV1VehiclesVehicleIdSessionsPost(body);
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
| **vehicleId** | `string` |  | [Defaults to `undefined`] |
| **chargingSessionRequest** | [ChargingSessionRequest](ChargingSessionRequest.md) |  | |

### Return type

[**ChargingSessionResponse**](ChargingSessionResponse.md)

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


## wakeVehicleApiV1VehiclesVehicleIdWakePost

> WakeResponse wakeVehicleApiV1VehiclesVehicleIdWakePost(vehicleId)

Wake Vehicle

Wake up the vehicle.  Sends wake-up command and waits for vehicle to come online. May take 10-30 seconds.

### Example

```ts
import {
  Configuration,
  VehiclesApi,
} from '@teplanner/sdk';
import type { WakeVehicleApiV1VehiclesVehicleIdWakePostRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new VehiclesApi(config);

  const body = {
    // string
    vehicleId: vehicleId_example,
  } satisfies WakeVehicleApiV1VehiclesVehicleIdWakePostRequest;

  try {
    const data = await api.wakeVehicleApiV1VehiclesVehicleIdWakePost(body);
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
| **vehicleId** | `string` |  | [Defaults to `undefined`] |

### Return type

[**WakeResponse**](WakeResponse.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: `application/json`


### HTTP response details
| Status code | Description | Response headers |
|-------------|-------------|------------------|
| **200** | Successful Response |  -  |
| **422** | Validation Error |  -  |

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)

