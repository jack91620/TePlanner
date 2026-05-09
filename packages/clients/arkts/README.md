# @teplanner/sdk@1.0.0

A TypeScript SDK client for the localhost API.

## Usage

First, install the SDK from npm.

```bash
npm install @teplanner/sdk --save
```

Next, try it out.


```ts
import {
  Configuration,
  AuthApi,
} from '@teplanner/sdk';
import type { EmailLoginApiV1AuthLoginPostRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const api = new AuthApi();

  const body = {
    // EmailLoginRequest
    emailLoginRequest: ...,
  } satisfies EmailLoginApiV1AuthLoginPostRequest;

  try {
    const data = await api.emailLoginApiV1AuthLoginPost(body);
    console.log(data);
  } catch (error) {
    console.error(error);
  }
}

// Run the test
example().catch(console.error);
```


## Documentation

### API Endpoints

All URIs are relative to *http://localhost*

| Class | Method | HTTP request | Description
| ----- | ------ | ------------ | -------------
*AuthApi* | [**emailLoginApiV1AuthLoginPost**](docs/AuthApi.md#emailloginapiv1authloginpost) | **POST** /api/v1/auth/login | Email Login
*AuthApi* | [**emailRegisterApiV1AuthRegisterPost**](docs/AuthApi.md#emailregisterapiv1authregisterpost) | **POST** /api/v1/auth/register | Email Register
*AuthApi* | [**teslaAuthorizeApiV1AuthTeslaAuthorizeGet**](docs/AuthApi.md#teslaauthorizeapiv1authteslaauthorizeget) | **GET** /api/v1/auth/tesla/authorize | Tesla Authorize
*AuthApi* | [**teslaCallbackApiV1AuthTeslaCallbackGet**](docs/AuthApi.md#teslacallbackapiv1authteslacallbackget) | **GET** /api/v1/auth/tesla/callback | Tesla Callback
*AuthApi* | [**teslaCallbackPostApiV1AuthTeslaCallbackPost**](docs/AuthApi.md#teslacallbackpostapiv1authteslacallbackpost) | **POST** /api/v1/auth/tesla/callback | Tesla Callback Post
*AuthApi* | [**teslaLinkStatusApiV1AuthTeslaStatusGet**](docs/AuthApi.md#teslalinkstatusapiv1authteslastatusget) | **GET** /api/v1/auth/tesla/status | Tesla Link Status
*AuthApi* | [**teslaRefreshTokenApiV1AuthTeslaRefreshPost**](docs/AuthApi.md#teslarefreshtokenapiv1authteslarefreshpost) | **POST** /api/v1/auth/tesla/refresh | Tesla Refresh Token
*AuthApi* | [**teslaTestApiV1AuthTeslaTestGet**](docs/AuthApi.md#teslatestapiv1authteslatestget) | **GET** /api/v1/auth/tesla/test | Tesla Test
*AuthApi* | [**validateTokenApiV1AuthValidateGet**](docs/AuthApi.md#validatetokenapiv1authvalidateget) | **GET** /api/v1/auth/validate | Validate Token
*AuthApi* | [**wechatLoginApiV1AuthWechatLoginPost**](docs/AuthApi.md#wechatloginapiv1authwechatloginpost) | **POST** /api/v1/auth/wechat/login | Wechat Login
*AutomationsApi* | [**createRuleApiV1AutomationsPost**](docs/AutomationsApi.md#createruleapiv1automationspost) | **POST** /api/v1/automations/ | Create Rule
*AutomationsApi* | [**deleteRuleApiV1AutomationsRuleIdDelete**](docs/AutomationsApi.md#deleteruleapiv1automationsruleiddelete) | **DELETE** /api/v1/automations/{rule_id} | Delete Rule
*AutomationsApi* | [**getTelemetryStateApiV1AutomationsStateGet**](docs/AutomationsApi.md#gettelemetrystateapiv1automationsstateget) | **GET** /api/v1/automations/state | Get Telemetry State
*AutomationsApi* | [**listCapabilitiesApiV1AutomationsCapabilitiesGet**](docs/AutomationsApi.md#listcapabilitiesapiv1automationscapabilitiesget) | **GET** /api/v1/automations/capabilities | List Capabilities
*AutomationsApi* | [**listRecentFiresApiV1AutomationsRecentFiresGet**](docs/AutomationsApi.md#listrecentfiresapiv1automationsrecentfiresget) | **GET** /api/v1/automations/recent-fires | List Recent Fires
*AutomationsApi* | [**listRulesApiV1AutomationsGet**](docs/AutomationsApi.md#listrulesapiv1automationsget) | **GET** /api/v1/automations/ | List Rules
*AutomationsApi* | [**listSnoozesApiV1AutomationsSnoozesGet**](docs/AutomationsApi.md#listsnoozesapiv1automationssnoozesget) | **GET** /api/v1/automations/snoozes | List Snoozes
*AutomationsApi* | [**reorderRulesApiV1AutomationsOrderPut**](docs/AutomationsApi.md#reorderrulesapiv1automationsorderput) | **PUT** /api/v1/automations/order | Reorder Rules
*AutomationsApi* | [**snoozeRuleApiV1AutomationsRuleIdSnoozePost**](docs/AutomationsApi.md#snoozeruleapiv1automationsruleidsnoozepost) | **POST** /api/v1/automations/{rule_id}/snooze | Snooze Rule
*AutomationsApi* | [**unsnoozeRuleApiV1AutomationsRuleIdSnoozeDelete**](docs/AutomationsApi.md#unsnoozeruleapiv1automationsruleidsnoozedelete) | **DELETE** /api/v1/automations/{rule_id}/snooze | Unsnooze Rule
*AutomationsApi* | [**updateRuleApiV1AutomationsRuleIdPut**](docs/AutomationsApi.md#updateruleapiv1automationsruleidput) | **PUT** /api/v1/automations/{rule_id} | Update Rule
*ChargingApi* | [**getStationApiV1ChargingStationsStationIdGet**](docs/ChargingApi.md#getstationapiv1chargingstationsstationidget) | **GET** /api/v1/charging/stations/{station_id} | Get Station
*ChargingApi* | [**searchNearbyStationsApiV1ChargingNearbyGet**](docs/ChargingApi.md#searchnearbystationsapiv1chargingnearbyget) | **GET** /api/v1/charging/nearby | Search Nearby Stations
*ChargingApi* | [**searchStationsApiV1ChargingStationsGet**](docs/ChargingApi.md#searchstationsapiv1chargingstationsget) | **GET** /api/v1/charging/stations | Search Stations
*DefaultApi* | [**healthCheckHealthGet**](docs/DefaultApi.md#healthcheckhealthget) | **GET** /health | Health Check
*DefaultApi* | [**rootGet**](docs/DefaultApi.md#rootget) | **GET** / | Root
*DefaultApi* | [**serveWechatVerificationFilenameGet**](docs/DefaultApi.md#servewechatverificationfilenameget) | **GET** /{filename} | Serve Wechat Verification
*DevicesApi* | [**registerDeviceApiV1DevicesRegisterPost**](docs/DevicesApi.md#registerdeviceapiv1devicesregisterpost) | **POST** /api/v1/devices/register | Register Device
*DevicesApi* | [**runAutomationTickApiV1DevicesRunAutomationTickPost**](docs/DevicesApi.md#runautomationtickapiv1devicesrunautomationtickpost) | **POST** /api/v1/devices/run-automation-tick | Run Automation Tick
*DevicesApi* | [**testPushApiV1DevicesTestPushPost**](docs/DevicesApi.md#testpushapiv1devicestestpushpost) | **POST** /api/v1/devices/test-push | Test Push
*RoutesApi* | [**chargingPlanApiV1RoutesChargingPlanPost**](docs/RoutesApi.md#chargingplanapiv1routeschargingplanpost) | **POST** /api/v1/routes/charging-plan | Charging Plan
*RoutesApi* | [**geocodeAddressApiV1RoutesGeocodePost**](docs/RoutesApi.md#geocodeaddressapiv1routesgeocodepost) | **POST** /api/v1/routes/geocode | Geocode Address
*RoutesApi* | [**getRouteApiV1RoutesSavedRouteIdGet**](docs/RoutesApi.md#getrouteapiv1routessavedrouteidget) | **GET** /api/v1/routes/saved/{route_id} | Get Route
*RoutesApi* | [**listRoutesApiV1RoutesGet**](docs/RoutesApi.md#listroutesapiv1routesget) | **GET** /api/v1/routes/ | List Routes
*RoutesApi* | [**navigateRouteApiV1RoutesNavigatePost**](docs/RoutesApi.md#navigaterouteapiv1routesnavigatepost) | **POST** /api/v1/routes/navigate | Navigate Route
*RoutesApi* | [**navigateSavedRouteApiV1RoutesNavigateRouteIdPost**](docs/RoutesApi.md#navigatesavedrouteapiv1routesnavigaterouteidpost) | **POST** /api/v1/routes/navigate/{route_id} | Navigate Saved Route
*RoutesApi* | [**reverseGeocodeApiV1RoutesReverseGeocodePost**](docs/RoutesApi.md#reversegeocodeapiv1routesreversegeocodepost) | **POST** /api/v1/routes/reverse-geocode | Reverse Geocode
*RoutesApi* | [**routeOnlyApiV1RoutesRoutePost**](docs/RoutesApi.md#routeonlyapiv1routesroutepost) | **POST** /api/v1/routes/route | Route Only
*RoutesApi* | [**searchPlacesApiV1RoutesSearchGet**](docs/RoutesApi.md#searchplacesapiv1routessearchget) | **GET** /api/v1/routes/search | Search Places
*UserApi* | [**clearScheduledDepartureApiV1UserScheduledDepartureDelete**](docs/UserApi.md#clearscheduleddepartureapiv1userscheduleddeparturedelete) | **DELETE** /api/v1/user/scheduled-departure | Clear Scheduled Departure
*UserApi* | [**getScheduledDepartureApiV1UserScheduledDepartureGet**](docs/UserApi.md#getscheduleddepartureapiv1userscheduleddepartureget) | **GET** /api/v1/user/scheduled-departure | Get Scheduled Departure
*UserApi* | [**getUserSettingsApiV1UserSettingsGet**](docs/UserApi.md#getusersettingsapiv1usersettingsget) | **GET** /api/v1/user/settings | Get User Settings
*UserApi* | [**upsertScheduledDepartureApiV1UserScheduledDeparturePut**](docs/UserApi.md#upsertscheduleddepartureapiv1userscheduleddepartureput) | **PUT** /api/v1/user/scheduled-departure | Upsert Scheduled Departure
*UserApi* | [**upsertUserSettingsApiV1UserSettingsPut**](docs/UserApi.md#upsertusersettingsapiv1usersettingsput) | **PUT** /api/v1/user/settings | Upsert User Settings
*VehiclesApi* | [**cancelQueuedCommandApiV1VehiclesCommandsQueuedQueuedIdDelete**](docs/VehiclesApi.md#cancelqueuedcommandapiv1vehiclescommandsqueuedqueuediddelete) | **DELETE** /api/v1/vehicles/commands/queued/{queued_id} | Cancel Queued Command
*VehiclesApi* | [**getVehicleApiV1VehiclesVehicleIdGet**](docs/VehiclesApi.md#getvehicleapiv1vehiclesvehicleidget) | **GET** /api/v1/vehicles/{vehicle_id} | Get Vehicle
*VehiclesApi* | [**getVehicleStateApiV1VehiclesVehicleIdStateGet**](docs/VehiclesApi.md#getvehiclestateapiv1vehiclesvehicleidstateget) | **GET** /api/v1/vehicles/{vehicle_id}/state | Get Vehicle State
*VehiclesApi* | [**listChargingSessionsApiV1VehiclesVehicleIdSessionsGet**](docs/VehiclesApi.md#listchargingsessionsapiv1vehiclesvehicleidsessionsget) | **GET** /api/v1/vehicles/{vehicle_id}/sessions | List Charging Sessions
*VehiclesApi* | [**listPendingCommandsApiV1VehiclesCommandsPendingGet**](docs/VehiclesApi.md#listpendingcommandsapiv1vehiclescommandspendingget) | **GET** /api/v1/vehicles/commands/pending | List Pending Commands
*VehiclesApi* | [**listQueuedCommandsApiV1VehiclesCommandsQueuedGet**](docs/VehiclesApi.md#listqueuedcommandsapiv1vehiclescommandsqueuedget) | **GET** /api/v1/vehicles/commands/queued | List Queued Commands
*VehiclesApi* | [**listVehiclesApiV1VehiclesGet**](docs/VehiclesApi.md#listvehiclesapiv1vehiclesget) | **GET** /api/v1/vehicles/ | List Vehicles
*VehiclesApi* | [**navigateVehicleAddressApiV1VehiclesVehicleIdNavigateAddressPost**](docs/VehiclesApi.md#navigatevehicleaddressapiv1vehiclesvehicleidnavigateaddresspost) | **POST** /api/v1/vehicles/{vehicle_id}/navigate/address | Navigate Vehicle Address
*VehiclesApi* | [**navigateVehicleApiV1VehiclesVehicleIdNavigatePost**](docs/VehiclesApi.md#navigatevehicleapiv1vehiclesvehicleidnavigatepost) | **POST** /api/v1/vehicles/{vehicle_id}/navigate | Navigate Vehicle
*VehiclesApi* | [**preheatVehicleApiV1VehiclesVehicleIdPreheatPost**](docs/VehiclesApi.md#preheatvehicleapiv1vehiclesvehicleidpreheatpost) | **POST** /api/v1/vehicles/{vehicle_id}/preheat | Preheat Vehicle
*VehiclesApi* | [**setChargeLimitApiV1VehiclesVehicleIdChargeLimitPost**](docs/VehiclesApi.md#setchargelimitapiv1vehiclesvehicleidchargelimitpost) | **POST** /api/v1/vehicles/{vehicle_id}/charge-limit | Set Charge Limit
*VehiclesApi* | [**setClimateKeeperModeApiV1VehiclesVehicleIdClimateKeeperModePost**](docs/VehiclesApi.md#setclimatekeepermodeapiv1vehiclesvehicleidclimatekeepermodepost) | **POST** /api/v1/vehicles/{vehicle_id}/climate-keeper-mode | Set Climate Keeper Mode
*VehiclesApi* | [**setPrimaryVehicleApiV1VehiclesVehicleIdSetPrimaryPost**](docs/VehiclesApi.md#setprimaryvehicleapiv1vehiclesvehicleidsetprimarypost) | **POST** /api/v1/vehicles/{vehicle_id}/set-primary | Set Primary Vehicle
*VehiclesApi* | [**setSentryModeApiV1VehiclesVehicleIdSentryModePost**](docs/VehiclesApi.md#setsentrymodeapiv1vehiclesvehicleidsentrymodepost) | **POST** /api/v1/vehicles/{vehicle_id}/sentry-mode | Set Sentry Mode
*VehiclesApi* | [**suggestChargeLimitEndpointApiV1VehiclesVehicleIdSuggestChargeLimitPost**](docs/VehiclesApi.md#suggestchargelimitendpointapiv1vehiclesvehicleidsuggestchargelimitpost) | **POST** /api/v1/vehicles/{vehicle_id}/suggest-charge-limit | Suggest Charge Limit Endpoint
*VehiclesApi* | [**upsertChargingSessionApiV1VehiclesVehicleIdSessionsPost**](docs/VehiclesApi.md#upsertchargingsessionapiv1vehiclesvehicleidsessionspost) | **POST** /api/v1/vehicles/{vehicle_id}/sessions | Upsert Charging Session
*VehiclesApi* | [**wakeVehicleApiV1VehiclesVehicleIdWakePost**](docs/VehiclesApi.md#wakevehicleapiv1vehiclesvehicleidwakepost) | **POST** /api/v1/vehicles/{vehicle_id}/wake | Wake Vehicle


### Models

- [ChargeLimitRequest](docs/ChargeLimitRequest.md)
- [ChargingPlanRequest](docs/ChargingPlanRequest.md)
- [ChargingPlanResponse](docs/ChargingPlanResponse.md)
- [ChargingSessionListResponse](docs/ChargingSessionListResponse.md)
- [ChargingSessionRequest](docs/ChargingSessionRequest.md)
- [ChargingSessionResponse](docs/ChargingSessionResponse.md)
- [ChargingStation](docs/ChargingStation.md)
- [ChargingStopResponse](docs/ChargingStopResponse.md)
- [ClimateKeeperModeRequest](docs/ClimateKeeperModeRequest.md)
- [EmailAuthResponse](docs/EmailAuthResponse.md)
- [EmailLoginRequest](docs/EmailLoginRequest.md)
- [EmailRegisterRequest](docs/EmailRegisterRequest.md)
- [GeocodeRequest](docs/GeocodeRequest.md)
- [GeocodeResponse](docs/GeocodeResponse.md)
- [HTTPValidationError](docs/HTTPValidationError.md)
- [LocationInner](docs/LocationInner.md)
- [LocationInput](docs/LocationInput.md)
- [NavigateRouteRequest](docs/NavigateRouteRequest.md)
- [NavigationAddressRequest](docs/NavigationAddressRequest.md)
- [NavigationRequest](docs/NavigationRequest.md)
- [POIInput](docs/POIInput.md)
- [PendingCommandListResponse](docs/PendingCommandListResponse.md)
- [PendingCommandResponse](docs/PendingCommandResponse.md)
- [QueuedCommandListResponse](docs/QueuedCommandListResponse.md)
- [QueuedCommandResponse](docs/QueuedCommandResponse.md)
- [RecentFireEntry](docs/RecentFireEntry.md)
- [RecentFiresResponse](docs/RecentFiresResponse.md)
- [RegisterDeviceRequest](docs/RegisterDeviceRequest.md)
- [RegisterDeviceResponse](docs/RegisterDeviceResponse.md)
- [RouteOnlyRequest](docs/RouteOnlyRequest.md)
- [RouteOnlyResponse](docs/RouteOnlyResponse.md)
- [RoutePlanResponse](docs/RoutePlanResponse.md)
- [RuleCreateRequest](docs/RuleCreateRequest.md)
- [RuleListResponse](docs/RuleListResponse.md)
- [RuleOrderRequest](docs/RuleOrderRequest.md)
- [RuleResponse](docs/RuleResponse.md)
- [RuleUpdateRequest](docs/RuleUpdateRequest.md)
- [ScheduledDepartureRequest](docs/ScheduledDepartureRequest.md)
- [ScheduledDepartureResponse](docs/ScheduledDepartureResponse.md)
- [SentryModeRequest](docs/SentryModeRequest.md)
- [SnoozeListResponse](docs/SnoozeListResponse.md)
- [SnoozeRequest](docs/SnoozeRequest.md)
- [SnoozeResponse](docs/SnoozeResponse.md)
- [StationSearchResponse](docs/StationSearchResponse.md)
- [SuggestChargeLimitRequest](docs/SuggestChargeLimitRequest.md)
- [SuggestChargeLimitResponse](docs/SuggestChargeLimitResponse.md)
- [TelemetryStateEntry](docs/TelemetryStateEntry.md)
- [TelemetryStateResponse](docs/TelemetryStateResponse.md)
- [TeslaCallbackRequest](docs/TeslaCallbackRequest.md)
- [TestPushRequest](docs/TestPushRequest.md)
- [UserSettingsRequest](docs/UserSettingsRequest.md)
- [UserSettingsResponse](docs/UserSettingsResponse.md)
- [ValidationError](docs/ValidationError.md)
- [VehicleListResponse](docs/VehicleListResponse.md)
- [VehicleResponse](docs/VehicleResponse.md)
- [VehicleStateResponse](docs/VehicleStateResponse.md)
- [WakeResponse](docs/WakeResponse.md)
- [WeChatLoginRequest](docs/WeChatLoginRequest.md)
- [WeChatLoginResponse](docs/WeChatLoginResponse.md)

### Authorization


Authentication schemes defined for the API:
<a id="HTTPBearer"></a>
#### HTTPBearer


- **Type**: HTTP Bearer Token authentication

## About

This TypeScript SDK client supports the [Fetch API](https://fetch.spec.whatwg.org/)
and is automatically generated by the
[OpenAPI Generator](https://openapi-generator.tech) project:

- API version: `0.1.0`
- Package version: `1.0.0`
- Generator version: `7.22.0`
- Build package: `org.openapitools.codegen.languages.TypeScriptFetchClientCodegen`

The generated npm module supports the following:

- Environments
  * Node.js
  * Webpack
  * Browserify
- Language levels
  * ES5 - you must have a Promises/A+ library installed
  * ES6
- Module systems
  * CommonJS
  * ES6 module system


## Development

### Building

To build the TypeScript source code, you need to have Node.js and npm installed.
After cloning the repository, navigate to the project directory and run:

```bash
npm install
npm run build
```

### Publishing

Once you've built the package, you can publish it to npm:

```bash
npm publish
```

## License

[]()
