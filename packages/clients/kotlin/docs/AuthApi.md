# AuthApi

All URIs are relative to *http://localhost*

| Method | HTTP request | Description |
| ------------- | ------------- | ------------- |
| [**emailLoginApiV1AuthLoginPost**](AuthApi.md#emailLoginApiV1AuthLoginPost) | **POST** api/v1/auth/login | Email Login |
| [**emailRegisterApiV1AuthRegisterPost**](AuthApi.md#emailRegisterApiV1AuthRegisterPost) | **POST** api/v1/auth/register | Email Register |
| [**teslaAuthorizeApiV1AuthTeslaAuthorizeGet**](AuthApi.md#teslaAuthorizeApiV1AuthTeslaAuthorizeGet) | **GET** api/v1/auth/tesla/authorize | Tesla Authorize |
| [**teslaCallbackApiV1AuthTeslaCallbackGet**](AuthApi.md#teslaCallbackApiV1AuthTeslaCallbackGet) | **GET** api/v1/auth/tesla/callback | Tesla Callback |
| [**teslaCallbackPostApiV1AuthTeslaCallbackPost**](AuthApi.md#teslaCallbackPostApiV1AuthTeslaCallbackPost) | **POST** api/v1/auth/tesla/callback | Tesla Callback Post |
| [**teslaLinkStatusApiV1AuthTeslaStatusGet**](AuthApi.md#teslaLinkStatusApiV1AuthTeslaStatusGet) | **GET** api/v1/auth/tesla/status | Tesla Link Status |
| [**teslaRefreshTokenApiV1AuthTeslaRefreshPost**](AuthApi.md#teslaRefreshTokenApiV1AuthTeslaRefreshPost) | **POST** api/v1/auth/tesla/refresh | Tesla Refresh Token |
| [**teslaTestApiV1AuthTeslaTestGet**](AuthApi.md#teslaTestApiV1AuthTeslaTestGet) | **GET** api/v1/auth/tesla/test | Tesla Test |
| [**validateTokenApiV1AuthValidateGet**](AuthApi.md#validateTokenApiV1AuthValidateGet) | **GET** api/v1/auth/validate | Validate Token |
| [**wechatLoginApiV1AuthWechatLoginPost**](AuthApi.md#wechatLoginApiV1AuthWechatLoginPost) | **POST** api/v1/auth/wechat/login | Wechat Login |



Email Login

Login with email and password. Logic in services/auth_service.login_email_user.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
val webService = apiClient.createWebservice(AuthApi::class.java)
val emailLoginRequest : EmailLoginRequest =  // EmailLoginRequest | 

launch(Dispatchers.IO) {
    val result : EmailAuthResponse = webService.emailLoginApiV1AuthLoginPost(emailLoginRequest)
}
```

### Parameters
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **emailLoginRequest** | [**EmailLoginRequest**](EmailLoginRequest.md)|  | |

### Return type

[**EmailAuthResponse**](EmailAuthResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json


Email Register

Register a new user with email and password (Android / non- WeChat clients). Logic in services/auth_service.register_email_user.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
val webService = apiClient.createWebservice(AuthApi::class.java)
val emailRegisterRequest : EmailRegisterRequest =  // EmailRegisterRequest | 

launch(Dispatchers.IO) {
    val result : EmailAuthResponse = webService.emailRegisterApiV1AuthRegisterPost(emailRegisterRequest)
}
```

### Parameters
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **emailRegisterRequest** | [**EmailRegisterRequest**](EmailRegisterRequest.md)|  | |

### Return type

[**EmailAuthResponse**](EmailAuthResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json


Tesla Authorize

Get Tesla OAuth authorization URL.  If user_id is not provided, creates an anonymous user (for testing).  Returns:     Authorization URL, state for CSRF protection, and user_id

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
val webService = apiClient.createWebservice(AuthApi::class.java)
val userId : kotlin.Int = 56 // kotlin.Int | User ID to link Tesla to

launch(Dispatchers.IO) {
    val result : kotlin.Any = webService.teslaAuthorizeApiV1AuthTeslaAuthorizeGet(userId)
}
```

### Parameters
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **userId** | **kotlin.Int**| User ID to link Tesla to | [optional] |

### Return type

[**kotlin.Any**](kotlin.Any.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json


Tesla Callback

Handle Tesla OAuth callback (GET).  Renders an HTML success/error page for the WebView. The exchange + persist + JWT-mint logic now lives in &#x60;services/tesla_auth_service.exchange_and_store&#x60;.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
val webService = apiClient.createWebservice(AuthApi::class.java)
val code : kotlin.String = code_example // kotlin.String | Authorization code from Tesla
val state : kotlin.String = state_example // kotlin.String | State parameter for CSRF protection

launch(Dispatchers.IO) {
    val result : kotlin.Any = webService.teslaCallbackApiV1AuthTeslaCallbackGet(code, state)
}
```

### Parameters
| **code** | **kotlin.String**| Authorization code from Tesla | |
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **state** | **kotlin.String**| State parameter for CSRF protection | |

### Return type

[**kotlin.Any**](kotlin.Any.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json


Tesla Callback Post

Handle Tesla OAuth callback (POST).  Used when an iOS native client OR the legacy Mini Program sends the OAuth code as JSON. Same exchange + persist logic as the GET handler, but JSON response.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
val webService = apiClient.createWebservice(AuthApi::class.java)
val teslaCallbackRequest : TeslaCallbackRequest =  // TeslaCallbackRequest | 
val userId : kotlin.Int = 56 // kotlin.Int | 

launch(Dispatchers.IO) {
    val result : kotlin.Any = webService.teslaCallbackPostApiV1AuthTeslaCallbackPost(teslaCallbackRequest, userId)
}
```

### Parameters
| **teslaCallbackRequest** | [**TeslaCallbackRequest**](TeslaCallbackRequest.md)|  | |
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **userId** | **kotlin.Int**|  | [optional] |

### Return type

[**kotlin.Any**](kotlin.Any.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json


Tesla Link Status

Check if user has linked Tesla account.  Args:     user_id: User ID to check  Returns:     Link status and expiration info

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
val webService = apiClient.createWebservice(AuthApi::class.java)
val userId : kotlin.Int = 56 // kotlin.Int | User ID to check

launch(Dispatchers.IO) {
    val result : kotlin.Any = webService.teslaLinkStatusApiV1AuthTeslaStatusGet(userId)
}
```

### Parameters
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **userId** | **kotlin.Int**| User ID to check | |

### Return type

[**kotlin.Any**](kotlin.Any.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json


Tesla Refresh Token

Refresh a Tesla access token. If user_id is given, the stored row is also updated.

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
val webService = apiClient.createWebservice(AuthApi::class.java)
val refreshToken : kotlin.String = refreshToken_example // kotlin.String | 
val userId : kotlin.Int = 56 // kotlin.Int | 

launch(Dispatchers.IO) {
    val result : kotlin.Any = webService.teslaRefreshTokenApiV1AuthTeslaRefreshPost(refreshToken, userId)
}
```

### Parameters
| **refreshToken** | **kotlin.String**|  | |
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **userId** | **kotlin.Int**|  | [optional] |

### Return type

[**kotlin.Any**](kotlin.Any.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json


Tesla Test

Test Tesla OAuth configuration.  Returns current configuration info (no sensitive data).

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
val webService = apiClient.createWebservice(AuthApi::class.java)

launch(Dispatchers.IO) {
    val result : kotlin.Any = webService.teslaTestApiV1AuthTeslaTestGet()
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**kotlin.Any**](kotlin.Any.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json


Validate Token

Validate JWT token and return user info.  Used by Mini Program on startup to check if stored token is still valid.  Returns:     User info and Tesla link status

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
apiClient.setBearerToken("TOKEN")
val webService = apiClient.createWebservice(AuthApi::class.java)

launch(Dispatchers.IO) {
    val result : kotlin.Any = webService.validateTokenApiV1AuthValidateGet()
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**kotlin.Any**](kotlin.Any.md)

### Authorization


Configure HTTPBearer:
    ApiClient().setBearerToken("TOKEN")

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json


Wechat Login

WeChat Mini Program login.  Exchange wx.login() code for user session and JWT token.  Args:     request: Contains the code from wx.login()     db: Database session  Returns:     JWT access token and user info

### Example
```kotlin
// Import classes:
//import cloud.teplanner.api.*
//import cloud.teplanner.api.infrastructure.*
//import cloud.teplanner.api.models.*

val apiClient = ApiClient()
val webService = apiClient.createWebservice(AuthApi::class.java)
val weChatLoginRequest : WeChatLoginRequest =  // WeChatLoginRequest | 

launch(Dispatchers.IO) {
    val result : WeChatLoginResponse = webService.wechatLoginApiV1AuthWechatLoginPost(weChatLoginRequest)
}
```

### Parameters
| Name | Type | Description  | Notes |
| ------------- | ------------- | ------------- | ------------- |
| **weChatLoginRequest** | [**WeChatLoginRequest**](WeChatLoginRequest.md)|  | |

### Return type

[**WeChatLoginResponse**](WeChatLoginResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

