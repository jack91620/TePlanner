# RoutesAPI

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**chargingPlanApiV1RoutesChargingPlanPost**](RoutesAPI.md#chargingplanapiv1routeschargingplanpost) | **POST** /api/v1/routes/charging-plan | Charging Plan
[**geocodeAddressApiV1RoutesGeocodePost**](RoutesAPI.md#geocodeaddressapiv1routesgeocodepost) | **POST** /api/v1/routes/geocode | Geocode Address
[**getRouteApiV1RoutesSavedRouteIdGet**](RoutesAPI.md#getrouteapiv1routessavedrouteidget) | **GET** /api/v1/routes/saved/{route_id} | Get Route
[**listRoutesApiV1RoutesGet**](RoutesAPI.md#listroutesapiv1routesget) | **GET** /api/v1/routes/ | List Routes
[**navigateRouteApiV1RoutesNavigatePost**](RoutesAPI.md#navigaterouteapiv1routesnavigatepost) | **POST** /api/v1/routes/navigate | Navigate Route
[**navigateSavedRouteApiV1RoutesNavigateRouteIdPost**](RoutesAPI.md#navigatesavedrouteapiv1routesnavigaterouteidpost) | **POST** /api/v1/routes/navigate/{route_id} | Navigate Saved Route
[**reverseGeocodeApiV1RoutesReverseGeocodePost**](RoutesAPI.md#reversegeocodeapiv1routesreversegeocodepost) | **POST** /api/v1/routes/reverse-geocode | Reverse Geocode
[**routeOnlyApiV1RoutesRoutePost**](RoutesAPI.md#routeonlyapiv1routesroutepost) | **POST** /api/v1/routes/route | Route Only
[**searchPlacesApiV1RoutesSearchGet**](RoutesAPI.md#searchplacesapiv1routessearchget) | **GET** /api/v1/routes/search | Search Places


# **chargingPlanApiV1RoutesChargingPlanPost**
```swift
    open class func chargingPlanApiV1RoutesChargingPlanPost(chargingPlanRequest: ChargingPlanRequest, completion: @escaping (_ data: ChargingPlanResponse?, _ error: Error?) -> Void)
```

Charging Plan

Phase 8.2: greedy charging-stop selection over client-provided candidate POIs. Pure computation — no map API call.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let chargingPlanRequest = ChargingPlanRequest(candidatePois: [POIInput(address: "address_example", id: "id_example", latitude: 123, longitude: 123, name: "name_example")], carType: "carType_example", initialSoc: 123, minArrivalSoc: 123, polyline: [[123]], totalDistanceKm: 123, vehicleRangeKm: 123) // ChargingPlanRequest | 

// Charging Plan
RoutesAPI.chargingPlanApiV1RoutesChargingPlanPost(chargingPlanRequest: chargingPlanRequest) { (response, error) in
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
 **chargingPlanRequest** | [**ChargingPlanRequest**](ChargingPlanRequest.md) |  | 

### Return type

[**ChargingPlanResponse**](ChargingPlanResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **geocodeAddressApiV1RoutesGeocodePost**
```swift
    open class func geocodeAddressApiV1RoutesGeocodePost(geocodeRequest: GeocodeRequest, completion: @escaping (_ data: GeocodeResponse?, _ error: Error?) -> Void)
```

Geocode Address

Convert address to coordinates.  Useful for getting coordinates from user-entered addresses.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let geocodeRequest = GeocodeRequest(address: "address_example") // GeocodeRequest | 

// Geocode Address
RoutesAPI.geocodeAddressApiV1RoutesGeocodePost(geocodeRequest: geocodeRequest) { (response, error) in
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
 **geocodeRequest** | [**GeocodeRequest**](GeocodeRequest.md) |  | 

### Return type

[**GeocodeResponse**](GeocodeResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getRouteApiV1RoutesSavedRouteIdGet**
```swift
    open class func getRouteApiV1RoutesSavedRouteIdGet(routeId: Int, completion: @escaping (_ data: RoutePlanResponse?, _ error: Error?) -> Void)
```

Get Route

Get a saved route plan.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let routeId = 987 // Int | 

// Get Route
RoutesAPI.getRouteApiV1RoutesSavedRouteIdGet(routeId: routeId) { (response, error) in
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
 **routeId** | **Int** |  | 

### Return type

[**RoutePlanResponse**](RoutePlanResponse.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listRoutesApiV1RoutesGet**
```swift
    open class func listRoutesApiV1RoutesGet(limit: Int? = nil, offset: Int? = nil, completion: @escaping (_ data: AnyCodable?, _ error: Error?) -> Void)
```

List Routes

List user's saved routes.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let limit = 987 // Int |  (optional) (default to 10)
let offset = 987 // Int |  (optional) (default to 0)

// List Routes
RoutesAPI.listRoutesApiV1RoutesGet(limit: limit, offset: offset) { (response, error) in
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
 **limit** | **Int** |  | [optional] [default to 10]
 **offset** | **Int** |  | [optional] [default to 0]

### Return type

**AnyCodable**

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **navigateRouteApiV1RoutesNavigatePost**
```swift
    open class func navigateRouteApiV1RoutesNavigatePost(navigateRouteRequest: NavigateRouteRequest, completion: @escaping (_ data: AnyCodable?, _ error: Error?) -> Void)
```

Navigate Route

Send planned route to vehicle.  Sends navigation waypoints to the vehicle's navigation system. By default, sends the charging stops as waypoints.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let navigateRouteRequest = NavigateRouteRequest(vehicleId: "vehicleId_example", waypoints: [LocationInput(address: "address_example", latitude: 123, longitude: 123)]) // NavigateRouteRequest | 

// Navigate Route
RoutesAPI.navigateRouteApiV1RoutesNavigatePost(navigateRouteRequest: navigateRouteRequest) { (response, error) in
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
 **navigateRouteRequest** | [**NavigateRouteRequest**](NavigateRouteRequest.md) |  | 

### Return type

**AnyCodable**

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **navigateSavedRouteApiV1RoutesNavigateRouteIdPost**
```swift
    open class func navigateSavedRouteApiV1RoutesNavigateRouteIdPost(routeId: Int, completion: @escaping (_ data: AnyCodable?, _ error: Error?) -> Void)
```

Navigate Saved Route

Send a saved route's charging stops + destination to the user's primary Tesla vehicle. Logic lives in `services/route_dispatch_service.send_saved_route_to_vehicle`.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let routeId = 987 // Int | 

// Navigate Saved Route
RoutesAPI.navigateSavedRouteApiV1RoutesNavigateRouteIdPost(routeId: routeId) { (response, error) in
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
 **routeId** | **Int** |  | 

### Return type

**AnyCodable**

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **reverseGeocodeApiV1RoutesReverseGeocodePost**
```swift
    open class func reverseGeocodeApiV1RoutesReverseGeocodePost(latitude: Double, longitude: Double, completion: @escaping (_ data: AnyCodable?, _ error: Error?) -> Void)
```

Reverse Geocode

Convert coordinates to address.  Useful for displaying readable location names.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let latitude = 987 // Double | 
let longitude = 987 // Double | 

// Reverse Geocode
RoutesAPI.reverseGeocodeApiV1RoutesReverseGeocodePost(latitude: latitude, longitude: longitude) { (response, error) in
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
 **latitude** | **Double** |  | 
 **longitude** | **Double** |  | 

### Return type

**AnyCodable**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **routeOnlyApiV1RoutesRoutePost**
```swift
    open class func routeOnlyApiV1RoutesRoutePost(routeOnlyRequest: RouteOnlyRequest, completion: @escaping (_ data: RouteOnlyResponse?, _ error: Error?) -> Void)
```

Route Only

Phase 8.2: AMap routing only — polyline + distance + duration.  No POI search, no charging plan. iOS calls this first, then runs AMap SDK along-route POI search locally, then POSTs candidate POIs back to /routes/charging-plan to compute the greedy stops.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let routeOnlyRequest = RouteOnlyRequest(destination: LocationInput(address: "address_example", latitude: 123, longitude: 123), origin: nil) // RouteOnlyRequest | 

// Route Only
RoutesAPI.routeOnlyApiV1RoutesRoutePost(routeOnlyRequest: routeOnlyRequest) { (response, error) in
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
 **routeOnlyRequest** | [**RouteOnlyRequest**](RouteOnlyRequest.md) |  | 

### Return type

[**RouteOnlyResponse**](RouteOnlyResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **searchPlacesApiV1RoutesSearchGet**
```swift
    open class func searchPlacesApiV1RoutesSearchGet(keyword: String, location: String? = nil, completion: @escaping (_ data: AnyCodable?, _ error: Error?) -> Void)
```

Search Places

Search for places by keyword.  Args:     keyword: Search keyword (e.g., city name, POI name)     location: Optional center location \"lat,lng\" for distance calculation  Returns:     List of matching places with name, address, location and distance

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let keyword = "keyword_example" // String | 
let location = "location_example" // String |  (optional)

// Search Places
RoutesAPI.searchPlacesApiV1RoutesSearchGet(keyword: keyword, location: location) { (response, error) in
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
 **keyword** | **String** |  | 
 **location** | **String** |  | [optional] 

### Return type

**AnyCodable**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

