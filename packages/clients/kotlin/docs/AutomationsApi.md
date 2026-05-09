# AutomationsApi

All URIs are relative to *http://localhost*

| Method | HTTP request | Description |
| ------------- | ------------- | ------------- |
| [**createRuleApiV1AutomationsPost**](AutomationsApi.md#createRuleApiV1AutomationsPost) | **POST** api/v1/automations/ | Create Rule |
| [**deleteRuleApiV1AutomationsRuleIdDelete**](AutomationsApi.md#deleteRuleApiV1AutomationsRuleIdDelete) | **DELETE** api/v1/automations/{rule_id} | Delete Rule |
| [**getTelemetryStateApiV1AutomationsStateGet**](AutomationsApi.md#getTelemetryStateApiV1AutomationsStateGet) | **GET** api/v1/automations/state | Get Telemetry State |
| [**listCapabilitiesApiV1AutomationsCapabilitiesGet**](AutomationsApi.md#listCapabilitiesApiV1AutomationsCapabilitiesGet) | **GET** api/v1/automations/capabilities | List Capabilities |
| [**listRecentFiresApiV1AutomationsRecentFiresGet**](AutomationsApi.md#listRecentFiresApiV1AutomationsRecentFiresGet) | **GET** api/v1/automations/recent-fires | List Recent Fires |
| [**listRulesApiV1AutomationsGet**](AutomationsApi.md#listRulesApiV1AutomationsGet) | **GET** api/v1/automations/ | List Rules |
| [**listSnoozesApiV1AutomationsSnoozesGet**](AutomationsApi.md#listSnoozesApiV1AutomationsSnoozesGet) | **GET** api/v1/automations/snoozes | List Snoozes |
| [**reorderRulesApiV1AutomationsOrderPut**](AutomationsApi.md#reorderRulesApiV1AutomationsOrderPut) | **PUT** api/v1/automations/order | Reorder Rules |
| [**snoozeRuleApiV1AutomationsRuleIdSnoozePost**](AutomationsApi.md#snoozeRuleApiV1AutomationsRuleIdSnoozePost) | **POST** api/v1/automations/{rule_id}/snooze | Snooze Rule |
| [**unsnoozeRuleApiV1AutomationsRuleIdSnoozeDelete**](AutomationsApi.md#unsnoozeRuleApiV1AutomationsRuleIdSnoozeDelete) | **DELETE** api/v1/automations/{rule_id}/snooze | Unsnooze Rule |
| [**updateRuleApiV1AutomationsRuleIdPut**](AutomationsApi.md#updateRuleApiV1AutomationsRuleIdPut) | **PUT** api/v1/automations/{rule_id} | Update Rule |



Create Rule

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(AutomationsApi::class.java)
val ruleCreateRequest : RuleCreateRequest =  // RuleCreateRequest | 

launch(Dispatchers.IO) {
    val result : RuleResponse = webService.createRuleApiV1AutomationsPost(ruleCreateRequest)
}
```

### Parameters
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **ruleCreateRequest** | [**RuleCreateRequest**](RuleCreateRequest.md)|  | |

### Return type

[**RuleResponse**](RuleResponse.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json


Delete Rule

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(AutomationsApi::class.java)
val ruleId : kotlin.String = ruleId_example // kotlin.String | 

launch(Dispatchers.IO) {
    val result : kotlin.Any = webService.deleteRuleApiV1AutomationsRuleIdDelete(ruleId)
}
```

### Parameters
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **ruleId** | **kotlin.String**|  | |

### Return type

[**kotlin.Any**](kotlin.Any.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json


Get Telemetry State

Return the user&#39;s telemetry-recorded entity state — the &#x60;&#x60;tel:*&#x60;&#x60; rows the Fleet Telemetry consumer writes into automation_state.  iOS calls this on each polling tick, before evaluating rules, and seeds the local engine memory with the server&#39;s &#x60;&#x60;since&#x60;&#x60; timestamps. The interpreter then prefers the earlier of (locally observed, server telemetry) when computing duration. That&#39;s what closes the \&quot;已开启 0 分钟\&quot; gap: the iOS HubView pill now reports the same elapsed time the server reports in push notifications.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(AutomationsApi::class.java)

launch(Dispatchers.IO) {
    val result : TelemetryStateResponse = webService.getTelemetryStateApiV1AutomationsStateGet()
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**TelemetryStateResponse**](TelemetryStateResponse.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json


List Capabilities

Registry introspection. iOS visual builder calls this once at boot to populate the action-block picker.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
val webService = apiClient.createWebservice(AutomationsApi::class.java)

launch(Dispatchers.IO) {
    val result : kotlin.collections.Map<kotlin.String, kotlin.collections.List<kotlin.Any>> = webService.listCapabilitiesApiV1AutomationsCapabilitiesGet()
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**kotlin.collections.Map&lt;kotlin.String, kotlin.collections.List&lt;kotlin.Any&gt;&gt;**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json


List Recent Fires

Recent rule-fire timeline for the user. Drives the iOS &#39;活动&#39; page — answers &#39;did my露营 rule fire today?&#39; without the user having to scrub through notification center.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(AutomationsApi::class.java)
val limit : kotlin.Int = 56 // kotlin.Int | 

launch(Dispatchers.IO) {
    val result : RecentFiresResponse = webService.listRecentFiresApiV1AutomationsRecentFiresGet(limit)
}
```

### Parameters
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **limit** | **kotlin.Int**|  | [optional] [default to 50] |

### Return type

[**RecentFiresResponse**](RecentFiresResponse.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json


List Rules

List all of the user&#39;s rules. Lazy-seeds the presets on first call (when user has zero rules). Order is canonical: each preset in its ALL_PRESETS-declared position, user-authored rules after, by creation time. Each rule includes &#x60;&#x60;last_fired_at&#x60;&#x60; — the most recent PushedAlert.pushed_at for that rule&#39;s kind.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(AutomationsApi::class.java)

launch(Dispatchers.IO) {
    val result : RuleListResponse = webService.listRulesApiV1AutomationsGet()
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**RuleListResponse**](RuleListResponse.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json


List Snoozes

List all active (snoozed_until_utc &gt; now) snoozes for the user. Stale rows (past their window) are filtered server-side; the client never sees them, so iOS doesn&#39;t need to time-check.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(AutomationsApi::class.java)

launch(Dispatchers.IO) {
    val result : SnoozeListResponse = webService.listSnoozesApiV1AutomationsSnoozesGet()
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**SnoozeListResponse**](SnoozeListResponse.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json


Reorder Rules

Persist a user-defined display order. Returns the full rule list in the new canonical order so iOS can replace its in-memory cache in one round-trip.  All rule_ids must belong to the requesting user; we 404 on the first mismatch (defensive — silent skipping would leak existence). Duplicates within rule_ids are rejected (400) so position is well-defined.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(AutomationsApi::class.java)
val ruleOrderRequest : RuleOrderRequest =  // RuleOrderRequest | 

launch(Dispatchers.IO) {
    val result : RuleListResponse = webService.reorderRulesApiV1AutomationsOrderPut(ruleOrderRequest)
}
```

### Parameters
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **ruleOrderRequest** | [**RuleOrderRequest**](RuleOrderRequest.md)|  | |

### Return type

[**RuleListResponse**](RuleListResponse.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json


Snooze Rule

Snooze &#x60;&#x60;rule_id&#x60;&#x60; until &#x60;&#x60;until&#x60;&#x60; (absolute UTC) or for &#x60;&#x60;hours&#x60;&#x60; from now. Exactly one of the two must be provided. Replaces any existing snooze on that rule (UNIQUE on rule_id).

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(AutomationsApi::class.java)
val ruleId : kotlin.String = ruleId_example // kotlin.String | 
val snoozeRequest : SnoozeRequest =  // SnoozeRequest | 

launch(Dispatchers.IO) {
    val result : SnoozeResponse = webService.snoozeRuleApiV1AutomationsRuleIdSnoozePost(ruleId, snoozeRequest)
}
```

### Parameters
| **ruleId** | **kotlin.String**|  | |
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **snoozeRequest** | [**SnoozeRequest**](SnoozeRequest.md)|  | |

### Return type

[**SnoozeResponse**](SnoozeResponse.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json


Unsnooze Rule

Clear any active snooze on &#x60;&#x60;rule_id&#x60;&#x60;. 404 if the rule itself doesn&#39;t exist; idempotent on a rule with no active snooze.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(AutomationsApi::class.java)
val ruleId : kotlin.String = ruleId_example // kotlin.String | 

launch(Dispatchers.IO) {
    val result : kotlin.Any = webService.unsnoozeRuleApiV1AutomationsRuleIdSnoozeDelete(ruleId)
}
```

### Parameters
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **ruleId** | **kotlin.String**|  | |

### Return type

[**kotlin.Any**](kotlin.Any.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json


Update Rule

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(AutomationsApi::class.java)
val ruleId : kotlin.String = ruleId_example // kotlin.String | 
val ruleUpdateRequest : RuleUpdateRequest =  // RuleUpdateRequest | 

launch(Dispatchers.IO) {
    val result : RuleResponse = webService.updateRuleApiV1AutomationsRuleIdPut(ruleId, ruleUpdateRequest)
}
```

### Parameters
| **ruleId** | **kotlin.String**|  | |
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **ruleUpdateRequest** | [**RuleUpdateRequest**](RuleUpdateRequest.md)|  | |

### Return type

[**RuleResponse**](RuleResponse.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

