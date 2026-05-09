# AuthApi

All URIs are relative to *http://localhost*

| Method | HTTP request | Description |
|------------- | ------------- | -------------|
| [**emailLoginApiV1AuthLoginPost**](AuthApi.md#emailloginapiv1authloginpost) | **POST** /api/v1/auth/login | Email Login |
| [**emailRegisterApiV1AuthRegisterPost**](AuthApi.md#emailregisterapiv1authregisterpost) | **POST** /api/v1/auth/register | Email Register |
| [**teslaAuthorizeApiV1AuthTeslaAuthorizeGet**](AuthApi.md#teslaauthorizeapiv1authteslaauthorizeget) | **GET** /api/v1/auth/tesla/authorize | Tesla Authorize |
| [**teslaCallbackApiV1AuthTeslaCallbackGet**](AuthApi.md#teslacallbackapiv1authteslacallbackget) | **GET** /api/v1/auth/tesla/callback | Tesla Callback |
| [**teslaCallbackPostApiV1AuthTeslaCallbackPost**](AuthApi.md#teslacallbackpostapiv1authteslacallbackpost) | **POST** /api/v1/auth/tesla/callback | Tesla Callback Post |
| [**teslaLinkStatusApiV1AuthTeslaStatusGet**](AuthApi.md#teslalinkstatusapiv1authteslastatusget) | **GET** /api/v1/auth/tesla/status | Tesla Link Status |
| [**teslaRefreshTokenApiV1AuthTeslaRefreshPost**](AuthApi.md#teslarefreshtokenapiv1authteslarefreshpost) | **POST** /api/v1/auth/tesla/refresh | Tesla Refresh Token |
| [**teslaTestApiV1AuthTeslaTestGet**](AuthApi.md#teslatestapiv1authteslatestget) | **GET** /api/v1/auth/tesla/test | Tesla Test |
| [**validateTokenApiV1AuthValidateGet**](AuthApi.md#validatetokenapiv1authvalidateget) | **GET** /api/v1/auth/validate | Validate Token |
| [**wechatLoginApiV1AuthWechatLoginPost**](AuthApi.md#wechatloginapiv1authwechatloginpost) | **POST** /api/v1/auth/wechat/login | Wechat Login |



## emailLoginApiV1AuthLoginPost

> EmailAuthResponse emailLoginApiV1AuthLoginPost(emailLoginRequest)

Email Login

Login with email and password. Logic in services/auth_service.login_email_user.

### Example

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

### Parameters


| Name | Type | Description  | Notes |
|------------- | ------------- | ------------- | -------------|
| **emailLoginRequest** | [EmailLoginRequest](EmailLoginRequest.md) |  | |

### Return type

[**EmailAuthResponse**](EmailAuthResponse.md)

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


## emailRegisterApiV1AuthRegisterPost

> EmailAuthResponse emailRegisterApiV1AuthRegisterPost(emailRegisterRequest)

Email Register

Register a new user with email and password (Android / non- WeChat clients). Logic in services/auth_service.register_email_user.

### Example

```ts
import {
  Configuration,
  AuthApi,
} from '@teplanner/sdk';
import type { EmailRegisterApiV1AuthRegisterPostRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const api = new AuthApi();

  const body = {
    // EmailRegisterRequest
    emailRegisterRequest: ...,
  } satisfies EmailRegisterApiV1AuthRegisterPostRequest;

  try {
    const data = await api.emailRegisterApiV1AuthRegisterPost(body);
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
| **emailRegisterRequest** | [EmailRegisterRequest](EmailRegisterRequest.md) |  | |

### Return type

[**EmailAuthResponse**](EmailAuthResponse.md)

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


## teslaAuthorizeApiV1AuthTeslaAuthorizeGet

> any teslaAuthorizeApiV1AuthTeslaAuthorizeGet(userId)

Tesla Authorize

Get Tesla OAuth authorization URL.  If user_id is not provided, creates an anonymous user (for testing).  Returns:     Authorization URL, state for CSRF protection, and user_id

### Example

```ts
import {
  Configuration,
  AuthApi,
} from '@teplanner/sdk';
import type { TeslaAuthorizeApiV1AuthTeslaAuthorizeGetRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const api = new AuthApi();

  const body = {
    // number | User ID to link Tesla to (optional)
    userId: 56,
  } satisfies TeslaAuthorizeApiV1AuthTeslaAuthorizeGetRequest;

  try {
    const data = await api.teslaAuthorizeApiV1AuthTeslaAuthorizeGet(body);
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
| **userId** | `number` | User ID to link Tesla to | [Optional] [Defaults to `undefined`] |

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


## teslaCallbackApiV1AuthTeslaCallbackGet

> any teslaCallbackApiV1AuthTeslaCallbackGet(code, state)

Tesla Callback

Handle Tesla OAuth callback (GET).  Renders an HTML success/error page for the WebView. The exchange + persist + JWT-mint logic now lives in &#x60;services/tesla_auth_service.exchange_and_store&#x60;.

### Example

```ts
import {
  Configuration,
  AuthApi,
} from '@teplanner/sdk';
import type { TeslaCallbackApiV1AuthTeslaCallbackGetRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const api = new AuthApi();

  const body = {
    // string | Authorization code from Tesla
    code: code_example,
    // string | State parameter for CSRF protection
    state: state_example,
  } satisfies TeslaCallbackApiV1AuthTeslaCallbackGetRequest;

  try {
    const data = await api.teslaCallbackApiV1AuthTeslaCallbackGet(body);
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
| **code** | `string` | Authorization code from Tesla | [Defaults to `undefined`] |
| **state** | `string` | State parameter for CSRF protection | [Defaults to `undefined`] |

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


## teslaCallbackPostApiV1AuthTeslaCallbackPost

> object teslaCallbackPostApiV1AuthTeslaCallbackPost(teslaCallbackRequest, userId)

Tesla Callback Post

Handle Tesla OAuth callback (POST).  Used when an iOS native client OR the legacy Mini Program sends the OAuth code as JSON. Same exchange + persist logic as the GET handler, but JSON response.

### Example

```ts
import {
  Configuration,
  AuthApi,
} from '@teplanner/sdk';
import type { TeslaCallbackPostApiV1AuthTeslaCallbackPostRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const api = new AuthApi();

  const body = {
    // TeslaCallbackRequest
    teslaCallbackRequest: ...,
    // number (optional)
    userId: 56,
  } satisfies TeslaCallbackPostApiV1AuthTeslaCallbackPostRequest;

  try {
    const data = await api.teslaCallbackPostApiV1AuthTeslaCallbackPost(body);
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
| **teslaCallbackRequest** | [TeslaCallbackRequest](TeslaCallbackRequest.md) |  | |
| **userId** | `number` |  | [Optional] [Defaults to `undefined`] |

### Return type

**object**

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


## teslaLinkStatusApiV1AuthTeslaStatusGet

> any teslaLinkStatusApiV1AuthTeslaStatusGet(userId)

Tesla Link Status

Check if user has linked Tesla account.  Args:     user_id: User ID to check  Returns:     Link status and expiration info

### Example

```ts
import {
  Configuration,
  AuthApi,
} from '@teplanner/sdk';
import type { TeslaLinkStatusApiV1AuthTeslaStatusGetRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const api = new AuthApi();

  const body = {
    // number | User ID to check
    userId: 56,
  } satisfies TeslaLinkStatusApiV1AuthTeslaStatusGetRequest;

  try {
    const data = await api.teslaLinkStatusApiV1AuthTeslaStatusGet(body);
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
| **userId** | `number` | User ID to check | [Defaults to `undefined`] |

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


## teslaRefreshTokenApiV1AuthTeslaRefreshPost

> any teslaRefreshTokenApiV1AuthTeslaRefreshPost(refreshToken, userId)

Tesla Refresh Token

Refresh a Tesla access token. If user_id is given, the stored row is also updated.

### Example

```ts
import {
  Configuration,
  AuthApi,
} from '@teplanner/sdk';
import type { TeslaRefreshTokenApiV1AuthTeslaRefreshPostRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const api = new AuthApi();

  const body = {
    // string
    refreshToken: refreshToken_example,
    // number (optional)
    userId: 56,
  } satisfies TeslaRefreshTokenApiV1AuthTeslaRefreshPostRequest;

  try {
    const data = await api.teslaRefreshTokenApiV1AuthTeslaRefreshPost(body);
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
| **refreshToken** | `string` |  | [Defaults to `undefined`] |
| **userId** | `number` |  | [Optional] [Defaults to `undefined`] |

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


## teslaTestApiV1AuthTeslaTestGet

> any teslaTestApiV1AuthTeslaTestGet()

Tesla Test

Test Tesla OAuth configuration.  Returns current configuration info (no sensitive data).

### Example

```ts
import {
  Configuration,
  AuthApi,
} from '@teplanner/sdk';
import type { TeslaTestApiV1AuthTeslaTestGetRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const api = new AuthApi();

  try {
    const data = await api.teslaTestApiV1AuthTeslaTestGet();
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


## validateTokenApiV1AuthValidateGet

> any validateTokenApiV1AuthValidateGet()

Validate Token

Validate JWT token and return user info.  Used by Mini Program on startup to check if stored token is still valid.  Returns:     User info and Tesla link status

### Example

```ts
import {
  Configuration,
  AuthApi,
} from '@teplanner/sdk';
import type { ValidateTokenApiV1AuthValidateGetRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const config = new Configuration({ 
    // Configure HTTP bearer authorization: HTTPBearer
    accessToken: "YOUR BEARER TOKEN",
  });
  const api = new AuthApi(config);

  try {
    const data = await api.validateTokenApiV1AuthValidateGet();
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

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: `application/json`


### HTTP response details
| Status code | Description | Response headers |
|-------------|-------------|------------------|
| **200** | Successful Response |  -  |

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


## wechatLoginApiV1AuthWechatLoginPost

> WeChatLoginResponse wechatLoginApiV1AuthWechatLoginPost(weChatLoginRequest)

Wechat Login

WeChat Mini Program login.  Exchange wx.login() code for user session and JWT token.  Args:     request: Contains the code from wx.login()     db: Database session  Returns:     JWT access token and user info

### Example

```ts
import {
  Configuration,
  AuthApi,
} from '@teplanner/sdk';
import type { WechatLoginApiV1AuthWechatLoginPostRequest } from '@teplanner/sdk';

async function example() {
  console.log("🚀 Testing @teplanner/sdk SDK...");
  const api = new AuthApi();

  const body = {
    // WeChatLoginRequest
    weChatLoginRequest: ...,
  } satisfies WechatLoginApiV1AuthWechatLoginPostRequest;

  try {
    const data = await api.wechatLoginApiV1AuthWechatLoginPost(body);
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
| **weChatLoginRequest** | [WeChatLoginRequest](WeChatLoginRequest.md) |  | |

### Return type

[**WeChatLoginResponse**](WeChatLoginResponse.md)

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

