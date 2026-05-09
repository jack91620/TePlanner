# RoutesApi

All URIs are relative to *http://localhost*

| Method | HTTP request | Description |
| ------------- | ------------- | ------------- |
| [**chargingPlanApiV1RoutesChargingPlanPost**](RoutesApi.md#chargingPlanApiV1RoutesChargingPlanPost) | **POST** api/v1/routes/charging-plan | Charging Plan |
| [**geocodeAddressApiV1RoutesGeocodePost**](RoutesApi.md#geocodeAddressApiV1RoutesGeocodePost) | **POST** api/v1/routes/geocode | Geocode Address |
| [**getRouteApiV1RoutesSavedRouteIdGet**](RoutesApi.md#getRouteApiV1RoutesSavedRouteIdGet) | **GET** api/v1/routes/saved/{route_id} | Get Route |
| [**listRoutesApiV1RoutesGet**](RoutesApi.md#listRoutesApiV1RoutesGet) | **GET** api/v1/routes/ | List Routes |
| [**navigateRouteApiV1RoutesNavigatePost**](RoutesApi.md#navigateRouteApiV1RoutesNavigatePost) | **POST** api/v1/routes/navigate | Navigate Route |
| [**navigateSavedRouteApiV1RoutesNavigateRouteIdPost**](RoutesApi.md#navigateSavedRouteApiV1RoutesNavigateRouteIdPost) | **POST** api/v1/routes/navigate/{route_id} | Navigate Saved Route |
| [**reverseGeocodeApiV1RoutesReverseGeocodePost**](RoutesApi.md#reverseGeocodeApiV1RoutesReverseGeocodePost) | **POST** api/v1/routes/reverse-geocode | Reverse Geocode |
| [**routeOnlyApiV1RoutesRoutePost**](RoutesApi.md#routeOnlyApiV1RoutesRoutePost) | **POST** api/v1/routes/route | Route Only |
| [**searchPlacesApiV1RoutesSearchGet**](RoutesApi.md#searchPlacesApiV1RoutesSearchGet) | **GET** api/v1/routes/search | Search Places |



Charging Plan

Phase 8.2: greedy charging-stop selection over client-provided candidate POIs. Pure computation — no map API call.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
val webService = apiClient.createWebservice(RoutesApi::class.java)
val chargingPlanRequest : ChargingPlanRequest =  // ChargingPlanRequest | 

launch(Dispatchers.IO) {
    val result : ChargingPlanResponse = webService.chargingPlanApiV1RoutesChargingPlanPost(chargingPlanRequest)
}
```

### Parameters
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **chargingPlanRequest** | [**ChargingPlanRequest**](ChargingPlanRequest.md)|  | |

### Return type

[**ChargingPlanResponse**](ChargingPlanResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json


Geocode Address

Convert address to coordinates.  Useful for getting coordinates from user-entered addresses.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
val webService = apiClient.createWebservice(RoutesApi::class.java)
val geocodeRequest : GeocodeRequest =  // GeocodeRequest | 

launch(Dispatchers.IO) {
    val result : GeocodeResponse = webService.geocodeAddressApiV1RoutesGeocodePost(geocodeRequest)
}
```

### Parameters
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **geocodeRequest** | [**GeocodeRequest**](GeocodeRequest.md)|  | |

### Return type

[**GeocodeResponse**](GeocodeResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json


Get Route

Get a saved route plan.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(RoutesApi::class.java)
val routeId : kotlin.Int = 56 // kotlin.Int | 

launch(Dispatchers.IO) {
    val result : RoutePlanResponse = webService.getRouteApiV1RoutesSavedRouteIdGet(routeId)
}
```

### Parameters
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **routeId** | **kotlin.Int**|  | |

### Return type

[**RoutePlanResponse**](RoutePlanResponse.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json


List Routes

List user&#39;s saved routes.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(RoutesApi::class.java)
val limit : kotlin.Int = 56 // kotlin.Int | 
val offset : kotlin.Int = 56 // kotlin.Int | 

launch(Dispatchers.IO) {
    val result : kotlin.Any = webService.listRoutesApiV1RoutesGet(limit, offset)
}
```

### Parameters
| **limit** | **kotlin.Int**|  | [optional] [default to 10] |
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **offset** | **kotlin.Int**|  | [optional] [default to 0] |

### Return type

[**kotlin.Any**](kotlin.Any.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json


Navigate Route

Send planned route to vehicle.  Sends navigation waypoints to the vehicle&#39;s navigation system. By default, sends the charging stops as waypoints.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(RoutesApi::class.java)
val navigateRouteRequest : NavigateRouteRequest =  // NavigateRouteRequest | 

launch(Dispatchers.IO) {
    val result : kotlin.Any = webService.navigateRouteApiV1RoutesNavigatePost(navigateRouteRequest)
}
```

### Parameters
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **navigateRouteRequest** | [**NavigateRouteRequest**](NavigateRouteRequest.md)|  | |

### Return type

[**kotlin.Any**](kotlin.Any.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json


Navigate Saved Route

Send a saved route&#39;s charging stops + destination to the user&#39;s primary Tesla vehicle. Logic lives in &#x60;services/route_dispatch_service.send_saved_route_to_vehicle&#x60;.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(RoutesApi::class.java)
val routeId : kotlin.Int = 56 // kotlin.Int | 

launch(Dispatchers.IO) {
    val result : kotlin.Any = webService.navigateSavedRouteApiV1RoutesNavigateRouteIdPost(routeId)
}
```

### Parameters
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **routeId** | **kotlin.Int**|  | |

### Return type

[**kotlin.Any**](kotlin.Any.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json


Reverse Geocode

Convert coordinates to address.  Useful for displaying readable location names.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
val webService = apiClient.createWebservice(RoutesApi::class.java)
val latitude : java.math.BigDecimal = 8.14 // java.math.BigDecimal | 
val longitude : java.math.BigDecimal = 8.14 // java.math.BigDecimal | 

launch(Dispatchers.IO) {
    val result : kotlin.Any = webService.reverseGeocodeApiV1RoutesReverseGeocodePost(latitude, longitude)
}
```

### Parameters
| **latitude** | **java.math.BigDecimal**|  | |
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **longitude** | **java.math.BigDecimal**|  | |

### Return type

[**kotlin.Any**](kotlin.Any.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json


Route Only

Phase 8.2: AMap routing only — polyline + distance + duration.  No POI search, no charging plan. iOS calls this first, then runs AMap SDK along-route POI search locally, then POSTs candidate POIs back to /routes/charging-plan to compute the greedy stops.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
val webService = apiClient.createWebservice(RoutesApi::class.java)
val routeOnlyRequest : RouteOnlyRequest =  // RouteOnlyRequest | 

launch(Dispatchers.IO) {
    val result : RouteOnlyResponse = webService.routeOnlyApiV1RoutesRoutePost(routeOnlyRequest)
}
```

### Parameters
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **routeOnlyRequest** | [**RouteOnlyRequest**](RouteOnlyRequest.md)|  | |

### Return type

[**RouteOnlyResponse**](RouteOnlyResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json


Search Places

Search for places by keyword.  Args:     keyword: Search keyword (e.g., city name, POI name)     location: Optional center location \&quot;lat,lng\&quot; for distance calculation  Returns:     List of matching places with name, address, location and distance

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
val webService = apiClient.createWebservice(RoutesApi::class.java)
val keyword : kotlin.String = keyword_example // kotlin.String | 
val location : kotlin.String = location_example // kotlin.String | 

launch(Dispatchers.IO) {
    val result : kotlin.Any = webService.searchPlacesApiV1RoutesSearchGet(keyword, location)
}
```

### Parameters
| **keyword** | **kotlin.String**|  | |
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **location** | **kotlin.String**|  | [optional] |

### Return type

[**kotlin.Any**](kotlin.Any.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

