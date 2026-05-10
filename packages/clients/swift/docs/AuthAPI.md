# AuthAPI

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**emailLoginApiV1AuthLoginPost**](AuthAPI.md#emailloginapiv1authloginpost) | **POST** /api/v1/auth/login | Email Login
[**emailRegisterApiV1AuthRegisterPost**](AuthAPI.md#emailregisterapiv1authregisterpost) | **POST** /api/v1/auth/register | Email Register
[**teslaAuthorizeApiV1AuthTeslaAuthorizeGet**](AuthAPI.md#teslaauthorizeapiv1authteslaauthorizeget) | **GET** /api/v1/auth/tesla/authorize | Tesla Authorize
[**teslaCallbackApiV1AuthTeslaCallbackGet**](AuthAPI.md#teslacallbackapiv1authteslacallbackget) | **GET** /api/v1/auth/tesla/callback | Tesla Callback
[**teslaCallbackPostApiV1AuthTeslaCallbackPost**](AuthAPI.md#teslacallbackpostapiv1authteslacallbackpost) | **POST** /api/v1/auth/tesla/callback | Tesla Callback Post
[**teslaLinkStatusApiV1AuthTeslaStatusGet**](AuthAPI.md#teslalinkstatusapiv1authteslastatusget) | **GET** /api/v1/auth/tesla/status | Tesla Link Status
[**teslaRefreshTokenApiV1AuthTeslaRefreshPost**](AuthAPI.md#teslarefreshtokenapiv1authteslarefreshpost) | **POST** /api/v1/auth/tesla/refresh | Tesla Refresh Token
[**teslaTestApiV1AuthTeslaTestGet**](AuthAPI.md#teslatestapiv1authteslatestget) | **GET** /api/v1/auth/tesla/test | Tesla Test
[**validateTokenApiV1AuthValidateGet**](AuthAPI.md#validatetokenapiv1authvalidateget) | **GET** /api/v1/auth/validate | Validate Token
[**wechatLoginApiV1AuthWechatLoginPost**](AuthAPI.md#wechatloginapiv1authwechatloginpost) | **POST** /api/v1/auth/wechat/login | Wechat Login


# **emailLoginApiV1AuthLoginPost**
```swift
    open class func emailLoginApiV1AuthLoginPost(emailLoginRequest: EmailLoginRequest, completion: @escaping (_ data: EmailAuthResponse?, _ error: Error?) -> Void)
```

Email Login

Login with email and password. Logic in services/auth_service.login_email_user.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let emailLoginRequest = EmailLoginRequest(email: "email_example", password: "password_example") // EmailLoginRequest | 

// Email Login
AuthAPI.emailLoginApiV1AuthLoginPost(emailLoginRequest: emailLoginRequest) { (response, error) in
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
 **emailLoginRequest** | [**EmailLoginRequest**](EmailLoginRequest.md) |  | 

### Return type

[**EmailAuthResponse**](EmailAuthResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **emailRegisterApiV1AuthRegisterPost**
```swift
    open class func emailRegisterApiV1AuthRegisterPost(emailRegisterRequest: EmailRegisterRequest, completion: @escaping (_ data: EmailAuthResponse?, _ error: Error?) -> Void)
```

Email Register

Register a new user with email and password (Android / non- WeChat clients). Logic in services/auth_service.register_email_user.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let emailRegisterRequest = EmailRegisterRequest(email: "email_example", password: "password_example", nickname: "nickname_example") // EmailRegisterRequest | 

// Email Register
AuthAPI.emailRegisterApiV1AuthRegisterPost(emailRegisterRequest: emailRegisterRequest) { (response, error) in
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
 **emailRegisterRequest** | [**EmailRegisterRequest**](EmailRegisterRequest.md) |  | 

### Return type

[**EmailAuthResponse**](EmailAuthResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **teslaAuthorizeApiV1AuthTeslaAuthorizeGet**
```swift
    open class func teslaAuthorizeApiV1AuthTeslaAuthorizeGet(userId: Int? = nil, completion: @escaping (_ data: AnyCodable?, _ error: Error?) -> Void)
```

Tesla Authorize

Get Tesla OAuth authorization URL.  If user_id is not provided, creates an anonymous user (for testing).  Returns:     Authorization URL, state for CSRF protection, and user_id

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let userId = 987 // Int | User ID to link Tesla to (optional)

// Tesla Authorize
AuthAPI.teslaAuthorizeApiV1AuthTeslaAuthorizeGet(userId: userId) { (response, error) in
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
 **userId** | **Int** | User ID to link Tesla to | [optional] 

### Return type

**AnyCodable**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **teslaCallbackApiV1AuthTeslaCallbackGet**
```swift
    open class func teslaCallbackApiV1AuthTeslaCallbackGet(code: String, state: String, completion: @escaping (_ data: AnyCodable?, _ error: Error?) -> Void)
```

Tesla Callback

Handle Tesla OAuth callback (GET).  Renders an HTML success/error page for the WebView. The exchange + persist + JWT-mint logic now lives in `services/tesla_auth_service.exchange_and_store`.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let code = "code_example" // String | Authorization code from Tesla
let state = "state_example" // String | State parameter for CSRF protection

// Tesla Callback
AuthAPI.teslaCallbackApiV1AuthTeslaCallbackGet(code: code, state: state) { (response, error) in
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
 **code** | **String** | Authorization code from Tesla | 
 **state** | **String** | State parameter for CSRF protection | 

### Return type

**AnyCodable**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **teslaCallbackPostApiV1AuthTeslaCallbackPost**
```swift
    open class func teslaCallbackPostApiV1AuthTeslaCallbackPost(teslaCallbackRequest: TeslaCallbackRequest, userId: Int? = nil, completion: @escaping (_ data: AnyCodable?, _ error: Error?) -> Void)
```

Tesla Callback Post

Handle Tesla OAuth callback (POST).  Used when an iOS native client OR the legacy Mini Program sends the OAuth code as JSON. Same exchange + persist logic as the GET handler, but JSON response.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let teslaCallbackRequest = TeslaCallbackRequest(code: "code_example", state: "state_example") // TeslaCallbackRequest | 
let userId = 987 // Int |  (optional)

// Tesla Callback Post
AuthAPI.teslaCallbackPostApiV1AuthTeslaCallbackPost(teslaCallbackRequest: teslaCallbackRequest, userId: userId) { (response, error) in
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
 **teslaCallbackRequest** | [**TeslaCallbackRequest**](TeslaCallbackRequest.md) |  | 
 **userId** | **Int** |  | [optional] 

### Return type

**AnyCodable**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **teslaLinkStatusApiV1AuthTeslaStatusGet**
```swift
    open class func teslaLinkStatusApiV1AuthTeslaStatusGet(userId: Int, completion: @escaping (_ data: AnyCodable?, _ error: Error?) -> Void)
```

Tesla Link Status

Check if user has linked Tesla account.  Args:     user_id: User ID to check  Returns:     Link status and expiration info

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let userId = 987 // Int | User ID to check

// Tesla Link Status
AuthAPI.teslaLinkStatusApiV1AuthTeslaStatusGet(userId: userId) { (response, error) in
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
 **userId** | **Int** | User ID to check | 

### Return type

**AnyCodable**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **teslaRefreshTokenApiV1AuthTeslaRefreshPost**
```swift
    open class func teslaRefreshTokenApiV1AuthTeslaRefreshPost(refreshToken: String, userId: Int? = nil, completion: @escaping (_ data: AnyCodable?, _ error: Error?) -> Void)
```

Tesla Refresh Token

Refresh a Tesla access token. If user_id is given, the stored row is also updated.

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let refreshToken = "refreshToken_example" // String | 
let userId = 987 // Int |  (optional)

// Tesla Refresh Token
AuthAPI.teslaRefreshTokenApiV1AuthTeslaRefreshPost(refreshToken: refreshToken, userId: userId) { (response, error) in
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
 **refreshToken** | **String** |  | 
 **userId** | **Int** |  | [optional] 

### Return type

**AnyCodable**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **teslaTestApiV1AuthTeslaTestGet**
```swift
    open class func teslaTestApiV1AuthTeslaTestGet(completion: @escaping (_ data: AnyCodable?, _ error: Error?) -> Void)
```

Tesla Test

Test Tesla OAuth configuration.  Returns current configuration info (no sensitive data).

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI


// Tesla Test
AuthAPI.teslaTestApiV1AuthTeslaTestGet() { (response, error) in
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

**AnyCodable**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **validateTokenApiV1AuthValidateGet**
```swift
    open class func validateTokenApiV1AuthValidateGet(completion: @escaping (_ data: AnyCodable?, _ error: Error?) -> Void)
```

Validate Token

Validate JWT token and return user info.  Used by Mini Program on startup to check if stored token is still valid.  Returns:     User info and Tesla link status

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI


// Validate Token
AuthAPI.validateTokenApiV1AuthValidateGet() { (response, error) in
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

**AnyCodable**

### Authorization

[HTTPBearer](../README.md#HTTPBearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **wechatLoginApiV1AuthWechatLoginPost**
```swift
    open class func wechatLoginApiV1AuthWechatLoginPost(weChatLoginRequest: WeChatLoginRequest, completion: @escaping (_ data: WeChatLoginResponse?, _ error: Error?) -> Void)
```

Wechat Login

WeChat Mini Program login.  Exchange wx.login() code for user session and JWT token.  Args:     request: Contains the code from wx.login()     db: Database session  Returns:     JWT access token and user info

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import TePlannerAPI

let weChatLoginRequest = WeChatLoginRequest(code: "code_example") // WeChatLoginRequest | 

// Wechat Login
AuthAPI.wechatLoginApiV1AuthWechatLoginPost(weChatLoginRequest: weChatLoginRequest) { (response, error) in
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
 **weChatLoginRequest** | [**WeChatLoginRequest**](WeChatLoginRequest.md) |  | 

### Return type

[**WeChatLoginResponse**](WeChatLoginResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

