package cloud.teplanner.api.apis

import cloud.teplanner.api.infrastructure.CollectionFormats.*
import retrofit2.http.*
import retrofit2.Response
import okhttp3.RequestBody
import com.squareup.moshi.Json

import cloud.teplanner.api.models.EmailAuthResponse
import cloud.teplanner.api.models.EmailLoginRequest
import cloud.teplanner.api.models.EmailRegisterRequest
import cloud.teplanner.api.models.HTTPValidationError
import cloud.teplanner.api.models.TeslaCallbackRequest
import cloud.teplanner.api.models.WeChatLoginRequest
import cloud.teplanner.api.models.WeChatLoginResponse

interface AuthApi {
    /**
     * POST api/v1/auth/login
     * Email Login
     * Login with email and password. Logic in services/auth_service.login_email_user.
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param emailLoginRequest 
     * @return [EmailAuthResponse]
     */
    @POST("api/v1/auth/login")
    suspend fun emailLoginApiV1AuthLoginPost(@Body emailLoginRequest: EmailLoginRequest): Response<EmailAuthResponse>

    /**
     * POST api/v1/auth/register
     * Email Register
     * Register a new user with email and password (Android / non- WeChat clients). Logic in services/auth_service.register_email_user.
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param emailRegisterRequest 
     * @return [EmailAuthResponse]
     */
    @POST("api/v1/auth/register")
    suspend fun emailRegisterApiV1AuthRegisterPost(@Body emailRegisterRequest: EmailRegisterRequest): Response<EmailAuthResponse>

    /**
     * GET api/v1/auth/tesla/authorize
     * Tesla Authorize
     * Get Tesla OAuth authorization URL.  If user_id is not provided, creates an anonymous user (for testing).  Returns:     Authorization URL, state for CSRF protection, and user_id
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param userId User ID to link Tesla to (optional)
     * @return [kotlin.Any]
     */
    @GET("api/v1/auth/tesla/authorize")
    suspend fun teslaAuthorizeApiV1AuthTeslaAuthorizeGet(@Query("user_id") userId: kotlin.Int? = null): Response<kotlin.Any>

    /**
     * GET api/v1/auth/tesla/callback
     * Tesla Callback
     * Handle Tesla OAuth callback (GET).  Renders an HTML success/error page for the WebView. The exchange + persist + JWT-mint logic now lives in &#x60;services/tesla_auth_service.exchange_and_store&#x60;.
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param code Authorization code from Tesla
     * @param state State parameter for CSRF protection
     * @return [kotlin.Any]
     */
    @GET("api/v1/auth/tesla/callback")
    suspend fun teslaCallbackApiV1AuthTeslaCallbackGet(@Query("code") code: kotlin.String, @Query("state") state: kotlin.String): Response<kotlin.Any>

    /**
     * POST api/v1/auth/tesla/callback
     * Tesla Callback Post
     * Handle Tesla OAuth callback (POST).  Used when an iOS native client OR the legacy Mini Program sends the OAuth code as JSON. Same exchange + persist logic as the GET handler, but JSON response.
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param teslaCallbackRequest 
     * @param userId  (optional)
     * @return [kotlin.Any]
     */
    @POST("api/v1/auth/tesla/callback")
    suspend fun teslaCallbackPostApiV1AuthTeslaCallbackPost(@Body teslaCallbackRequest: TeslaCallbackRequest, @Query("user_id") userId: kotlin.Int? = null): Response<kotlin.Any>

    /**
     * GET api/v1/auth/tesla/status
     * Tesla Link Status
     * Check if user has linked Tesla account.  Args:     user_id: User ID to check  Returns:     Link status and expiration info
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param userId User ID to check
     * @return [kotlin.Any]
     */
    @GET("api/v1/auth/tesla/status")
    suspend fun teslaLinkStatusApiV1AuthTeslaStatusGet(@Query("user_id") userId: kotlin.Int): Response<kotlin.Any>

    /**
     * POST api/v1/auth/tesla/refresh
     * Tesla Refresh Token
     * Refresh a Tesla access token. If user_id is given, the stored row is also updated.
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param refreshToken 
     * @param userId  (optional)
     * @return [kotlin.Any]
     */
    @POST("api/v1/auth/tesla/refresh")
    suspend fun teslaRefreshTokenApiV1AuthTeslaRefreshPost(@Query("refresh_token") refreshToken: kotlin.String, @Query("user_id") userId: kotlin.Int? = null): Response<kotlin.Any>

    /**
     * GET api/v1/auth/tesla/test
     * Tesla Test
     * Test Tesla OAuth configuration.  Returns current configuration info (no sensitive data).
     * Responses:
     *  - 200: Successful Response
     *
     * @return [kotlin.Any]
     */
    @GET("api/v1/auth/tesla/test")
    suspend fun teslaTestApiV1AuthTeslaTestGet(): Response<kotlin.Any>

    /**
     * GET api/v1/auth/validate
     * Validate Token
     * Validate JWT token and return user info.  Used by Mini Program on startup to check if stored token is still valid.  Returns:     User info and Tesla link status
     * Responses:
     *  - 200: Successful Response
     *
     * @return [kotlin.Any]
     */
    @GET("api/v1/auth/validate")
    suspend fun validateTokenApiV1AuthValidateGet(): Response<kotlin.Any>

    /**
     * POST api/v1/auth/wechat/login
     * Wechat Login
     * WeChat Mini Program login.  Exchange wx.login() code for user session and JWT token.  Args:     request: Contains the code from wx.login()     db: Database session  Returns:     JWT access token and user info
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param weChatLoginRequest 
     * @return [WeChatLoginResponse]
     */
    @POST("api/v1/auth/wechat/login")
    suspend fun wechatLoginApiV1AuthWechatLoginPost(@Body weChatLoginRequest: WeChatLoginRequest): Response<WeChatLoginResponse>

}
