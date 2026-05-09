# AutomationsAPI

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**createRuleApiV1AutomationsPost**](AutomationsAPI.md#createruleapiv1automationspost) | **POST** /api/v1/automations/ | Create Rule
[**deleteRuleApiV1AutomationsRuleIdDelete**](AutomationsAPI.md#deleteruleapiv1automationsruleiddelete) | **DELETE** /api/v1/automations/{rule_id} | Delete Rule
[**getTelemetryStateApiV1AutomationsStateGet**](AutomationsAPI.md#gettelemetrystateapiv1automationsstateget) | **GET** /api/v1/automations/state | Get Telemetry State
[**listCapabilitiesApiV1AutomationsCapabilitiesGet**](AutomationsAPI.md#listcapabilitiesapiv1automationscapabilitiesget) | **GET** /api/v1/automations/capabilities | List Capabilities
[**listRecentFiresApiV1AutomationsRecentFiresGet**](AutomationsAPI.md#listrecentfiresapiv1automationsrecentfiresget) | **GET** /api/v1/automations/recent-fires | List Recent Fires
[**listRulesApiV1AutomationsGet**](AutomationsAPI.md#listrulesapiv1automationsget) | **GET** /api/v1/automations/ | List Rules
[**listSnoozesApiV1AutomationsSnoozesGet**](AutomationsAPI.md#listsnoozesapiv1automationssnoozesget) | **GET** /api/v1/automations/snoozes | List Snoozes
[**reorderRulesApiV1AutomationsOrderPut**](AutomationsAPI.md#reorderrulesapiv1automationsorderput) | **PUT** /api/v1/automations/order | Reorder Rules
[**snoozeRuleApiV1AutomationsRuleIdSnoozePost**](AutomationsAPI.md#snoozeruleapiv1automationsruleidsnoozepost) | **POST** /api/v1/automations/{rule_id}/snooze | Snooze Rule
[**unsnoozeRuleApiV1AutomationsRuleIdSnoozeDelete**](AutomationsAPI.md#unsnoozeruleapiv1automationsruleidsnoozedelete) | **DELETE** /api/v1/automations/{rule_id}/snooze | Unsnooze Rule
[**updateRuleApiV1AutomationsRuleIdPut**](AutomationsAPI.md#updateruleapiv1automationsruleidput) | **PUT** /api/v1/automations/{rule_id} | Update Rule


# **createRuleApiV1AutomationsPost**
```swift
    open class func createRuleApiV1AutomationsPost(ruleCreateRequest: RuleCreateRequest, completion: @escaping (_ data: RuleResponse?, _ error: Error?) -> Void)
```

Create Rule

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let ruleCreateRequest = RuleCreateRequest(enabled: false, name: "name_example", spec: 123) // RuleCreateRequest | 

// Create Rule
AutomationsAPI.createRuleApiV1AutomationsPost(ruleCreateRequest: ruleCreateRequest) { (response, error) in
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
 **ruleCreateRequest** | [**RuleCreateRequest**](RuleCreateRequest.md) |  | 

### Return type

[**RuleResponse**](RuleResponse.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **deleteRuleApiV1AutomationsRuleIdDelete**
```swift
    open class func deleteRuleApiV1AutomationsRuleIdDelete(ruleId: String, completion: @escaping (_ data: AnyCodable?, _ error: Error?) -> Void)
```

Delete Rule

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let ruleId = "ruleId_example" // String | 

// Delete Rule
AutomationsAPI.deleteRuleApiV1AutomationsRuleIdDelete(ruleId: ruleId) { (response, error) in
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
 **ruleId** | **String** |  | 

### Return type

**AnyCodable**

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getTelemetryStateApiV1AutomationsStateGet**
```swift
    open class func getTelemetryStateApiV1AutomationsStateGet(completion: @escaping (_ data: TelemetryStateResponse?, _ error: Error?) -> Void)
```

Get Telemetry State

Return the user's telemetry-recorded entity state — the ``tel:*`` rows the Fleet Telemetry consumer writes into automation_state.  iOS calls this on each polling tick, before evaluating rules, and seeds the local engine memory with the server's ``since`` timestamps. The interpreter then prefers the earlier of (locally observed, server telemetry) when computing duration. That's what closes the \"已开启 0 分钟\" gap: the iOS HubView pill now reports the same elapsed time the server reports in push notifications.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI


// Get Telemetry State
AutomationsAPI.getTelemetryStateApiV1AutomationsStateGet() { (response, error) in
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

[**TelemetryStateResponse**](TelemetryStateResponse.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listCapabilitiesApiV1AutomationsCapabilitiesGet**
```swift
    open class func listCapabilitiesApiV1AutomationsCapabilitiesGet(completion: @escaping (_ data: [String: [AnyCodable]]?, _ error: Error?) -> Void)
```

List Capabilities

Registry introspection. iOS visual builder calls this once at boot to populate the action-block picker.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI


// List Capabilities
AutomationsAPI.listCapabilitiesApiV1AutomationsCapabilitiesGet() { (response, error) in
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

[**[String: [AnyCodable]]**](Array.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listRecentFiresApiV1AutomationsRecentFiresGet**
```swift
    open class func listRecentFiresApiV1AutomationsRecentFiresGet(limit: Int? = nil, completion: @escaping (_ data: RecentFiresResponse?, _ error: Error?) -> Void)
```

List Recent Fires

Recent rule-fire timeline for the user. Drives the iOS '活动' page — answers 'did my露营 rule fire today?' without the user having to scrub through notification center.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let limit = 987 // Int |  (optional) (default to 50)

// List Recent Fires
AutomationsAPI.listRecentFiresApiV1AutomationsRecentFiresGet(limit: limit) { (response, error) in
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
 **limit** | **Int** |  | [optional] [default to 50]

### Return type

[**RecentFiresResponse**](RecentFiresResponse.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listRulesApiV1AutomationsGet**
```swift
    open class func listRulesApiV1AutomationsGet(completion: @escaping (_ data: RuleListResponse?, _ error: Error?) -> Void)
```

List Rules

List all of the user's rules. Lazy-seeds the presets on first call (when user has zero rules). Order is canonical: each preset in its ALL_PRESETS-declared position, user-authored rules after, by creation time. Each rule includes ``last_fired_at`` — the most recent PushedAlert.pushed_at for that rule's kind.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI


// List Rules
AutomationsAPI.listRulesApiV1AutomationsGet() { (response, error) in
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

[**RuleListResponse**](RuleListResponse.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listSnoozesApiV1AutomationsSnoozesGet**
```swift
    open class func listSnoozesApiV1AutomationsSnoozesGet(completion: @escaping (_ data: SnoozeListResponse?, _ error: Error?) -> Void)
```

List Snoozes

List all active (snoozed_until_utc > now) snoozes for the user. Stale rows (past their window) are filtered server-side; the client never sees them, so iOS doesn't need to time-check.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI


// List Snoozes
AutomationsAPI.listSnoozesApiV1AutomationsSnoozesGet() { (response, error) in
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

[**SnoozeListResponse**](SnoozeListResponse.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **reorderRulesApiV1AutomationsOrderPut**
```swift
    open class func reorderRulesApiV1AutomationsOrderPut(ruleOrderRequest: RuleOrderRequest, completion: @escaping (_ data: RuleListResponse?, _ error: Error?) -> Void)
```

Reorder Rules

Persist a user-defined display order. Returns the full rule list in the new canonical order so iOS can replace its in-memory cache in one round-trip.  All rule_ids must belong to the requesting user; we 404 on the first mismatch (defensive — silent skipping would leak existence). Duplicates within rule_ids are rejected (400) so position is well-defined.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let ruleOrderRequest = RuleOrderRequest(clear: false, ruleIds: ["ruleIds_example"]) // RuleOrderRequest | 

// Reorder Rules
AutomationsAPI.reorderRulesApiV1AutomationsOrderPut(ruleOrderRequest: ruleOrderRequest) { (response, error) in
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
 **ruleOrderRequest** | [**RuleOrderRequest**](RuleOrderRequest.md) |  | 

### Return type

[**RuleListResponse**](RuleListResponse.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **snoozeRuleApiV1AutomationsRuleIdSnoozePost**
```swift
    open class func snoozeRuleApiV1AutomationsRuleIdSnoozePost(ruleId: String, snoozeRequest: SnoozeRequest, completion: @escaping (_ data: SnoozeResponse?, _ error: Error?) -> Void)
```

Snooze Rule

Snooze ``rule_id`` until ``until`` (absolute UTC) or for ``hours`` from now. Exactly one of the two must be provided. Replaces any existing snooze on that rule (UNIQUE on rule_id).

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let ruleId = "ruleId_example" // String | 
let snoozeRequest = SnoozeRequest(hours: 123, reason: "reason_example", until: Date()) // SnoozeRequest | 

// Snooze Rule
AutomationsAPI.snoozeRuleApiV1AutomationsRuleIdSnoozePost(ruleId: ruleId, snoozeRequest: snoozeRequest) { (response, error) in
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
 **ruleId** | **String** |  | 
 **snoozeRequest** | [**SnoozeRequest**](SnoozeRequest.md) |  | 

### Return type

[**SnoozeResponse**](SnoozeResponse.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **unsnoozeRuleApiV1AutomationsRuleIdSnoozeDelete**
```swift
    open class func unsnoozeRuleApiV1AutomationsRuleIdSnoozeDelete(ruleId: String, completion: @escaping (_ data: AnyCodable?, _ error: Error?) -> Void)
```

Unsnooze Rule

Clear any active snooze on ``rule_id``. 404 if the rule itself doesn't exist; idempotent on a rule with no active snooze.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let ruleId = "ruleId_example" // String | 

// Unsnooze Rule
AutomationsAPI.unsnoozeRuleApiV1AutomationsRuleIdSnoozeDelete(ruleId: ruleId) { (response, error) in
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
 **ruleId** | **String** |  | 

### Return type

**AnyCodable**

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateRuleApiV1AutomationsRuleIdPut**
```swift
    open class func updateRuleApiV1AutomationsRuleIdPut(ruleId: String, ruleUpdateRequest: RuleUpdateRequest, completion: @escaping (_ data: RuleResponse?, _ error: Error?) -> Void)
```

Update Rule

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let ruleId = "ruleId_example" // String | 
let ruleUpdateRequest = RuleUpdateRequest(enabled: false, name: "name_example", spec: 123) // RuleUpdateRequest | 

// Update Rule
AutomationsAPI.updateRuleApiV1AutomationsRuleIdPut(ruleId: ruleId, ruleUpdateRequest: ruleUpdateRequest) { (response, error) in
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
 **ruleId** | **String** |  | 
 **ruleUpdateRequest** | [**RuleUpdateRequest**](RuleUpdateRequest.md) |  | 

### Return type

[**RuleResponse**](RuleResponse.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

