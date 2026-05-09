# AutomationsApi

All URIs are relative to *http://localhost*

| Method | HTTP request | Description |
|------------- | ------------- | -------------|
| [**createRuleApiV1AutomationsPost**](AutomationsApi.md#createruleapiv1automationspost) | **POST** /api/v1/automations/ | Create Rule |
| [**deleteRuleApiV1AutomationsRuleIdDelete**](AutomationsApi.md#deleteruleapiv1automationsruleiddelete) | **DELETE** /api/v1/automations/{rule_id} | Delete Rule |
| [**getTelemetryStateApiV1AutomationsStateGet**](AutomationsApi.md#gettelemetrystateapiv1automationsstateget) | **GET** /api/v1/automations/state | Get Telemetry State |
| [**listCapabilitiesApiV1AutomationsCapabilitiesGet**](AutomationsApi.md#listcapabilitiesapiv1automationscapabilitiesget) | **GET** /api/v1/automations/capabilities | List Capabilities |
| [**listRecentFiresApiV1AutomationsRecentFiresGet**](AutomationsApi.md#listrecentfiresapiv1automationsrecentfiresget) | **GET** /api/v1/automations/recent-fires | List Recent Fires |
| [**listRulesApiV1AutomationsGet**](AutomationsApi.md#listrulesapiv1automationsget) | **GET** /api/v1/automations/ | List Rules |
| [**listSnoozesApiV1AutomationsSnoozesGet**](AutomationsApi.md#listsnoozesapiv1automationssnoozesget) | **GET** /api/v1/automations/snoozes | List Snoozes |
| [**reorderRulesApiV1AutomationsOrderPut**](AutomationsApi.md#reorderrulesapiv1automationsorderput) | **PUT** /api/v1/automations/order | Reorder Rules |
| [**snoozeRuleApiV1AutomationsRuleIdSnoozePost**](AutomationsApi.md#snoozeruleapiv1automationsruleidsnoozepost) | **POST** /api/v1/automations/{rule_id}/snooze | Snooze Rule |
| [**unsnoozeRuleApiV1AutomationsRuleIdSnoozeDelete**](AutomationsApi.md#unsnoozeruleapiv1automationsruleidsnoozedelete) | **DELETE** /api/v1/automations/{rule_id}/snooze | Unsnooze Rule |
| [**updateRuleApiV1AutomationsRuleIdPut**](AutomationsApi.md#updateruleapiv1automationsruleidput) | **PUT** /api/v1/automations/{rule_id} | Update Rule |



## createRuleApiV1AutomationsPost

> RuleResponse createRuleApiV1AutomationsPost(ruleCreateRequest)

Create Rule

### Example

```ts
import {
  Configuration,
  AutomationsApi,
} from '@teplanner/sdk';
import type { CreateRuleApiV1AutomationsPostRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new AutomationsApi(config);

  const body = {
    // RuleCreateRequest
    ruleCreateRequest: ...,
  } satisfies CreateRuleApiV1AutomationsPostRequest;

  try {
    const data = await api.createRuleApiV1AutomationsPost(body);
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
| **ruleCreateRequest** | [RuleCreateRequest](RuleCreateRequest.md) |  | |

### Return type

[**RuleResponse**](RuleResponse.md)

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

- **Content-Type**: `application/json`
- **Accept**: `application/json`


### HTTP response details
| Status code | Description | Response headers |
|-------------|-------------|------------------|
| **201** | Successful Response |  -  |
| **422** | Validation Error |  -  |

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


## deleteRuleApiV1AutomationsRuleIdDelete

> object deleteRuleApiV1AutomationsRuleIdDelete(ruleId)

Delete Rule

### Example

```ts
import {
  Configuration,
  AutomationsApi,
} from '@teplanner/sdk';
import type { DeleteRuleApiV1AutomationsRuleIdDeleteRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new AutomationsApi(config);

  const body = {
    // string
    ruleId: ruleId_example,
  } satisfies DeleteRuleApiV1AutomationsRuleIdDeleteRequest;

  try {
    const data = await api.deleteRuleApiV1AutomationsRuleIdDelete(body);
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
| **ruleId** | `string` |  | [Defaults to `undefined`] |

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


## getTelemetryStateApiV1AutomationsStateGet

> TelemetryStateResponse getTelemetryStateApiV1AutomationsStateGet()

Get Telemetry State

Return the user\&#39;s telemetry-recorded entity state — the &#x60;&#x60;tel:*&#x60;&#x60; rows the Fleet Telemetry consumer writes into automation_state.  iOS calls this on each polling tick, before evaluating rules, and seeds the local engine memory with the server\&#39;s &#x60;&#x60;since&#x60;&#x60; timestamps. The interpreter then prefers the earlier of (locally observed, server telemetry) when computing duration. That\&#39;s what closes the \&quot;已开启 0 分钟\&quot; gap: the iOS HubView pill now reports the same elapsed time the server reports in push notifications.

### Example

```ts
import {
  Configuration,
  AutomationsApi,
} from '@teplanner/sdk';
import type { GetTelemetryStateApiV1AutomationsStateGetRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new AutomationsApi(config);

  try {
    const data = await api.getTelemetryStateApiV1AutomationsStateGet();
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

[**TelemetryStateResponse**](TelemetryStateResponse.md)

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


## listCapabilitiesApiV1AutomationsCapabilitiesGet

> { [key: string]: Array&lt;object&gt;; } listCapabilitiesApiV1AutomationsCapabilitiesGet()

List Capabilities

Registry introspection. iOS visual builder calls this once at boot to populate the action-block picker.

### Example

```ts
import {
  Configuration,
  AutomationsApi,
} from '@teplanner/sdk';
import type { ListCapabilitiesApiV1AutomationsCapabilitiesGetRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const api = new AutomationsApi();

  try {
    const data = await api.listCapabilitiesApiV1AutomationsCapabilitiesGet();
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

**{ [key: string]: Array<object>; }**

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


## listRecentFiresApiV1AutomationsRecentFiresGet

> RecentFiresResponse listRecentFiresApiV1AutomationsRecentFiresGet(limit)

List Recent Fires

Recent rule-fire timeline for the user. Drives the iOS \&#39;活动\&#39; page — answers \&#39;did my露营 rule fire today?\&#39; without the user having to scrub through notification center.

### Example

```ts
import {
  Configuration,
  AutomationsApi,
} from '@teplanner/sdk';
import type { ListRecentFiresApiV1AutomationsRecentFiresGetRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new AutomationsApi(config);

  const body = {
    // number (optional)
    limit: 56,
  } satisfies ListRecentFiresApiV1AutomationsRecentFiresGetRequest;

  try {
    const data = await api.listRecentFiresApiV1AutomationsRecentFiresGet(body);
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
| **limit** | `number` |  | [Optional] [Defaults to `50`] |

### Return type

[**RecentFiresResponse**](RecentFiresResponse.md)

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


## listRulesApiV1AutomationsGet

> RuleListResponse listRulesApiV1AutomationsGet()

List Rules

List all of the user\&#39;s rules. Lazy-seeds the presets on first call (when user has zero rules). Order is canonical: each preset in its ALL_PRESETS-declared position, user-authored rules after, by creation time. Each rule includes &#x60;&#x60;last_fired_at&#x60;&#x60; — the most recent PushedAlert.pushed_at for that rule\&#39;s kind.

### Example

```ts
import {
  Configuration,
  AutomationsApi,
} from '@teplanner/sdk';
import type { ListRulesApiV1AutomationsGetRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new AutomationsApi(config);

  try {
    const data = await api.listRulesApiV1AutomationsGet();
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

[**RuleListResponse**](RuleListResponse.md)

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


## listSnoozesApiV1AutomationsSnoozesGet

> SnoozeListResponse listSnoozesApiV1AutomationsSnoozesGet()

List Snoozes

List all active (snoozed_until_utc &gt; now) snoozes for the user. Stale rows (past their window) are filtered server-side; the client never sees them, so iOS doesn\&#39;t need to time-check.

### Example

```ts
import {
  Configuration,
  AutomationsApi,
} from '@teplanner/sdk';
import type { ListSnoozesApiV1AutomationsSnoozesGetRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new AutomationsApi(config);

  try {
    const data = await api.listSnoozesApiV1AutomationsSnoozesGet();
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

[**SnoozeListResponse**](SnoozeListResponse.md)

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


## reorderRulesApiV1AutomationsOrderPut

> RuleListResponse reorderRulesApiV1AutomationsOrderPut(ruleOrderRequest)

Reorder Rules

Persist a user-defined display order. Returns the full rule list in the new canonical order so iOS can replace its in-memory cache in one round-trip.  All rule_ids must belong to the requesting user; we 404 on the first mismatch (defensive — silent skipping would leak existence). Duplicates within rule_ids are rejected (400) so position is well-defined.

### Example

```ts
import {
  Configuration,
  AutomationsApi,
} from '@teplanner/sdk';
import type { ReorderRulesApiV1AutomationsOrderPutRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new AutomationsApi(config);

  const body = {
    // RuleOrderRequest
    ruleOrderRequest: ...,
  } satisfies ReorderRulesApiV1AutomationsOrderPutRequest;

  try {
    const data = await api.reorderRulesApiV1AutomationsOrderPut(body);
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
| **ruleOrderRequest** | [RuleOrderRequest](RuleOrderRequest.md) |  | |

### Return type

[**RuleListResponse**](RuleListResponse.md)

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


## snoozeRuleApiV1AutomationsRuleIdSnoozePost

> SnoozeResponse snoozeRuleApiV1AutomationsRuleIdSnoozePost(ruleId, snoozeRequest)

Snooze Rule

Snooze &#x60;&#x60;rule_id&#x60;&#x60; until &#x60;&#x60;until&#x60;&#x60; (absolute UTC) or for &#x60;&#x60;hours&#x60;&#x60; from now. Exactly one of the two must be provided. Replaces any existing snooze on that rule (UNIQUE on rule_id).

### Example

```ts
import {
  Configuration,
  AutomationsApi,
} from '@teplanner/sdk';
import type { SnoozeRuleApiV1AutomationsRuleIdSnoozePostRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new AutomationsApi(config);

  const body = {
    // string
    ruleId: ruleId_example,
    // SnoozeRequest
    snoozeRequest: ...,
  } satisfies SnoozeRuleApiV1AutomationsRuleIdSnoozePostRequest;

  try {
    const data = await api.snoozeRuleApiV1AutomationsRuleIdSnoozePost(body);
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
| **ruleId** | `string` |  | [Defaults to `undefined`] |
| **snoozeRequest** | [SnoozeRequest](SnoozeRequest.md) |  | |

### Return type

[**SnoozeResponse**](SnoozeResponse.md)

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


## unsnoozeRuleApiV1AutomationsRuleIdSnoozeDelete

> object unsnoozeRuleApiV1AutomationsRuleIdSnoozeDelete(ruleId)

Unsnooze Rule

Clear any active snooze on &#x60;&#x60;rule_id&#x60;&#x60;. 404 if the rule itself doesn\&#39;t exist; idempotent on a rule with no active snooze.

### Example

```ts
import {
  Configuration,
  AutomationsApi,
} from '@teplanner/sdk';
import type { UnsnoozeRuleApiV1AutomationsRuleIdSnoozeDeleteRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new AutomationsApi(config);

  const body = {
    // string
    ruleId: ruleId_example,
  } satisfies UnsnoozeRuleApiV1AutomationsRuleIdSnoozeDeleteRequest;

  try {
    const data = await api.unsnoozeRuleApiV1AutomationsRuleIdSnoozeDelete(body);
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
| **ruleId** | `string` |  | [Defaults to `undefined`] |

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


## updateRuleApiV1AutomationsRuleIdPut

> RuleResponse updateRuleApiV1AutomationsRuleIdPut(ruleId, ruleUpdateRequest)

Update Rule

### Example

```ts
import {
  Configuration,
  AutomationsApi,
} from '@teplanner/sdk';
import type { UpdateRuleApiV1AutomationsRuleIdPutRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new AutomationsApi(config);

  const body = {
    // string
    ruleId: ruleId_example,
    // RuleUpdateRequest
    ruleUpdateRequest: ...,
  } satisfies UpdateRuleApiV1AutomationsRuleIdPutRequest;

  try {
    const data = await api.updateRuleApiV1AutomationsRuleIdPut(body);
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
| **ruleId** | `string` |  | [Defaults to `undefined`] |
| **ruleUpdateRequest** | [RuleUpdateRequest](RuleUpdateRequest.md) |  | |

### Return type

[**RuleResponse**](RuleResponse.md)

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

