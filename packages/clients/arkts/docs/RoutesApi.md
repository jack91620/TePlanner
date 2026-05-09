# RoutesApi

All URIs are relative to *http://localhost*

| Method | HTTP request | Description |
|------------- | ------------- | -------------|
| [**chargingPlanApiV1RoutesChargingPlanPost**](RoutesApi.md#chargingplanapiv1routeschargingplanpost) | **POST** /api/v1/routes/charging-plan | Charging Plan |
| [**geocodeAddressApiV1RoutesGeocodePost**](RoutesApi.md#geocodeaddressapiv1routesgeocodepost) | **POST** /api/v1/routes/geocode | Geocode Address |
| [**getRouteApiV1RoutesSavedRouteIdGet**](RoutesApi.md#getrouteapiv1routessavedrouteidget) | **GET** /api/v1/routes/saved/{route_id} | Get Route |
| [**listRoutesApiV1RoutesGet**](RoutesApi.md#listroutesapiv1routesget) | **GET** /api/v1/routes/ | List Routes |
| [**navigateRouteApiV1RoutesNavigatePost**](RoutesApi.md#navigaterouteapiv1routesnavigatepost) | **POST** /api/v1/routes/navigate | Navigate Route |
| [**navigateSavedRouteApiV1RoutesNavigateRouteIdPost**](RoutesApi.md#navigatesavedrouteapiv1routesnavigaterouteidpost) | **POST** /api/v1/routes/navigate/{route_id} | Navigate Saved Route |
| [**reverseGeocodeApiV1RoutesReverseGeocodePost**](RoutesApi.md#reversegeocodeapiv1routesreversegeocodepost) | **POST** /api/v1/routes/reverse-geocode | Reverse Geocode |
| [**routeOnlyApiV1RoutesRoutePost**](RoutesApi.md#routeonlyapiv1routesroutepost) | **POST** /api/v1/routes/route | Route Only |
| [**searchPlacesApiV1RoutesSearchGet**](RoutesApi.md#searchplacesapiv1routessearchget) | **GET** /api/v1/routes/search | Search Places |



## chargingPlanApiV1RoutesChargingPlanPost

> ChargingPlanResponse chargingPlanApiV1RoutesChargingPlanPost(chargingPlanRequest)

Charging Plan

Phase 8.2: greedy charging-stop selection over client-provided candidate POIs. Pure computation — no map API call.

### Example

```ts
import {
  Configuration,
  RoutesApi,
} from '@teplanner/sdk';
import type { ChargingPlanApiV1RoutesChargingPlanPostRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const api = new RoutesApi();

  const body = {
    // ChargingPlanRequest
    chargingPlanRequest: ...,
  } satisfies ChargingPlanApiV1RoutesChargingPlanPostRequest;

  try {
    const data = await api.chargingPlanApiV1RoutesChargingPlanPost(body);
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
| **chargingPlanRequest** | [ChargingPlanRequest](ChargingPlanRequest.md) |  | |

### Return type

[**ChargingPlanResponse**](ChargingPlanResponse.md)

### Authorization

No authorization required

### HTTP request headers

- **Content-Type**: `application/json`
- **Accept**: `application/json`


### HTTP response details
| Status code | Description | Response headers |
|-------------|-------------|------------------|
| **200** | Successful Response |  -  |
| **422** | Validation Error |  -  |

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


## geocodeAddressApiV1RoutesGeocodePost

> GeocodeResponse geocodeAddressApiV1RoutesGeocodePost(geocodeRequest)

Geocode Address

Convert address to coordinates.  Useful for getting coordinates from user-entered addresses.

### Example

```ts
import {
  Configuration,
  RoutesApi,
} from '@teplanner/sdk';
import type { GeocodeAddressApiV1RoutesGeocodePostRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const api = new RoutesApi();

  const body = {
    // GeocodeRequest
    geocodeRequest: ...,
  } satisfies GeocodeAddressApiV1RoutesGeocodePostRequest;

  try {
    const data = await api.geocodeAddressApiV1RoutesGeocodePost(body);
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
| **geocodeRequest** | [GeocodeRequest](GeocodeRequest.md) |  | |

### Return type

[**GeocodeResponse**](GeocodeResponse.md)

### Authorization

No authorization required

### HTTP request headers

- **Content-Type**: `application/json`
- **Accept**: `application/json`


### HTTP response details
| Status code | Description | Response headers |
|-------------|-------------|------------------|
| **200** | Successful Response |  -  |
| **422** | Validation Error |  -  |

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


## getRouteApiV1RoutesSavedRouteIdGet

> RoutePlanResponse getRouteApiV1RoutesSavedRouteIdGet(routeId)

Get Route

Get a saved route plan.

### Example

```ts
import {
  Configuration,
  RoutesApi,
} from '@teplanner/sdk';
import type { GetRouteApiV1RoutesSavedRouteIdGetRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new RoutesApi(config);

  const body = {
    // number
    routeId: 56,
  } satisfies GetRouteApiV1RoutesSavedRouteIdGetRequest;

  try {
    const data = await api.getRouteApiV1RoutesSavedRouteIdGet(body);
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
| **routeId** | `number` |  | [Defaults to `undefined`] |

### Return type

[**RoutePlanResponse**](RoutePlanResponse.md)

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


## listRoutesApiV1RoutesGet

> any listRoutesApiV1RoutesGet(limit, offset)

List Routes

List user\&#39;s saved routes.

### Example

```ts
import {
  Configuration,
  RoutesApi,
} from '@teplanner/sdk';
import type { ListRoutesApiV1RoutesGetRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new RoutesApi(config);

  const body = {
    // number (optional)
    limit: 56,
    // number (optional)
    offset: 56,
  } satisfies ListRoutesApiV1RoutesGetRequest;

  try {
    const data = await api.listRoutesApiV1RoutesGet(body);
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
| **limit** | `number` |  | [Optional] [Defaults to `10`] |
| **offset** | `number` |  | [Optional] [Defaults to `0`] |

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


## navigateRouteApiV1RoutesNavigatePost

> any navigateRouteApiV1RoutesNavigatePost(navigateRouteRequest)

Navigate Route

Send planned route to vehicle.  Sends navigation waypoints to the vehicle\&#39;s navigation system. By default, sends the charging stops as waypoints.

### Example

```ts
import {
  Configuration,
  RoutesApi,
} from '@teplanner/sdk';
import type { NavigateRouteApiV1RoutesNavigatePostRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new RoutesApi(config);

  const body = {
    // NavigateRouteRequest
    navigateRouteRequest: ...,
  } satisfies NavigateRouteApiV1RoutesNavigatePostRequest;

  try {
    const data = await api.navigateRouteApiV1RoutesNavigatePost(body);
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
| **navigateRouteRequest** | [NavigateRouteRequest](NavigateRouteRequest.md) |  | |

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


## navigateSavedRouteApiV1RoutesNavigateRouteIdPost

> any navigateSavedRouteApiV1RoutesNavigateRouteIdPost(routeId)

Navigate Saved Route

Send a saved route\&#39;s charging stops + destination to the user\&#39;s primary Tesla vehicle. Logic lives in &#x60;services/route_dispatch_service.send_saved_route_to_vehicle&#x60;.

### Example

```ts
import {
  Configuration,
  RoutesApi,
} from '@teplanner/sdk';
import type { NavigateSavedRouteApiV1RoutesNavigateRouteIdPostRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new RoutesApi(config);

  const body = {
    // number
    routeId: 56,
  } satisfies NavigateSavedRouteApiV1RoutesNavigateRouteIdPostRequest;

  try {
    const data = await api.navigateSavedRouteApiV1RoutesNavigateRouteIdPost(body);
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
| **routeId** | `number` |  | [Defaults to `undefined`] |

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


## reverseGeocodeApiV1RoutesReverseGeocodePost

> any reverseGeocodeApiV1RoutesReverseGeocodePost(latitude, longitude)

Reverse Geocode

Convert coordinates to address.  Useful for displaying readable location names.

### Example

```ts
import {
  Configuration,
  RoutesApi,
} from '@teplanner/sdk';
import type { ReverseGeocodeApiV1RoutesReverseGeocodePostRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const api = new RoutesApi();

  const body = {
    // number
    latitude: 8.14,
    // number
    longitude: 8.14,
  } satisfies ReverseGeocodeApiV1RoutesReverseGeocodePostRequest;

  try {
    const data = await api.reverseGeocodeApiV1RoutesReverseGeocodePost(body);
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
| **latitude** | `number` |  | [Defaults to `undefined`] |
| **longitude** | `number` |  | [Defaults to `undefined`] |

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


## routeOnlyApiV1RoutesRoutePost

> RouteOnlyResponse routeOnlyApiV1RoutesRoutePost(routeOnlyRequest)

Route Only

Phase 8.2: AMap routing only — polyline + distance + duration.  No POI search, no charging plan. iOS calls this first, then runs AMap SDK along-route POI search locally, then POSTs candidate POIs back to /routes/charging-plan to compute the greedy stops.

### Example

```ts
import {
  Configuration,
  RoutesApi,
} from '@teplanner/sdk';
import type { RouteOnlyApiV1RoutesRoutePostRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const api = new RoutesApi();

  const body = {
    // RouteOnlyRequest
    routeOnlyRequest: ...,
  } satisfies RouteOnlyApiV1RoutesRoutePostRequest;

  try {
    const data = await api.routeOnlyApiV1RoutesRoutePost(body);
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
| **routeOnlyRequest** | [RouteOnlyRequest](RouteOnlyRequest.md) |  | |

### Return type

[**RouteOnlyResponse**](RouteOnlyResponse.md)

### Authorization

No authorization required

### HTTP request headers

- **Content-Type**: `application/json`
- **Accept**: `application/json`


### HTTP response details
| Status code | Description | Response headers |
|-------------|-------------|------------------|
| **200** | Successful Response |  -  |
| **422** | Validation Error |  -  |

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


## searchPlacesApiV1RoutesSearchGet

> any searchPlacesApiV1RoutesSearchGet(keyword, location)

Search Places

Search for places by keyword.  Args:     keyword: Search keyword (e.g., city name, POI name)     location: Optional center location \&quot;lat,lng\&quot; for distance calculation  Returns:     List of matching places with name, address, location and distance

### Example

```ts
import {
  Configuration,
  RoutesApi,
} from '@teplanner/sdk';
import type { SearchPlacesApiV1RoutesSearchGetRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const api = new RoutesApi();

  const body = {
    // string
    keyword: keyword_example,
    // string (optional)
    location: location_example,
  } satisfies SearchPlacesApiV1RoutesSearchGetRequest;

  try {
    const data = await api.searchPlacesApiV1RoutesSearchGet(body);
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
| **keyword** | `string` |  | [Defaults to `undefined`] |
| **location** | `string` |  | [Optional] [Defaults to `undefined`] |

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

