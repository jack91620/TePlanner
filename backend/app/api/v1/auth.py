"""Authentication endpoints."""

from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.core.security import (
    TokenEncryption,
    create_access_token,
    decode_access_token,
    get_password_hash,
    verify_password,
)
from app.db.models import TeslaToken, User
from app.db.session import get_db
from app.integrations.tesla import TeslaAuth
from app.services.auth_service import (
    AccountDisabledError,
    EmailAlreadyExistsError,
    InvalidCredentialsError,
    login_email_user as _login_email_user,
    register_email_user as _register_email_user,
)
from app.services.tesla_auth_service import (
    TeslaAuthError,
    exchange_and_store as _tesla_exchange_and_store,
    refresh_and_store as _tesla_refresh_and_store,
)
from app.services.wechat import WeChatClient, WeChatAPIError

router = APIRouter()
security = HTTPBearer(auto_error=False)

# Temporary storage for OAuth state and code_verifier (use Redis in production)
_oauth_states: dict = {}


class WeChatLoginRequest(BaseModel):
    """WeChat login request."""

    code: str


class WeChatLoginResponse(BaseModel):
    """WeChat login response."""

    access_token: str
    token_type: str = "Bearer"
    expires_in: int
    user_id: int
    openid: str
    has_tesla_linked: bool = False


# Email/Password auth models (for Android)
class EmailRegisterRequest(BaseModel):
    """Email registration request."""

    email: str
    password: str
    nickname: Optional[str] = None


class EmailLoginRequest(BaseModel):
    """Email login request."""

    email: str
    password: str


class EmailAuthResponse(BaseModel):
    """Email auth response."""

    access_token: str
    token_type: str = "Bearer"
    expires_in: int
    user_id: int
    email: str
    nickname: Optional[str] = None
    has_tesla_linked: bool = False


class TeslaAuthResponse(BaseModel):
    """Tesla authorization URL response."""

    url: str
    state: str


class TeslaCallbackRequest(BaseModel):
    """Tesla OAuth callback request."""

    code: str
    state: str


class UserInfoResponse(BaseModel):
    """User info response."""

    id: int
    openid: str
    nickname: Optional[str] = None
    avatar_url: Optional[str] = None
    has_tesla_linked: bool = False
    tesla_vehicles_count: int = 0


@router.get("/validate")
async def validate_token(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db),
):
    """Validate JWT token and return user info.

    Used by Mini Program on startup to check if stored token is still valid.

    Returns:
        User info and Tesla link status
    """
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
        )

    token = credentials.credentials
    payload = decode_access_token(token)

    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )

    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload",
        )

    # Query user
    result = await db.execute(select(User).where(User.id == int(user_id)))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    # Check Tesla link status
    result = await db.execute(
        select(TeslaToken).where(TeslaToken.user_id == user.id)
    )
    tesla_token = result.scalar_one_or_none()
    has_vehicle_bound = (
        tesla_token is not None
        and tesla_token.expires_at
        and tesla_token.expires_at > datetime.utcnow()
    )

    return {
        "user": {
            "id": user.id,
            "openid": user.openid,
            "nickname": user.nickname,
            "avatar_url": user.avatar_url,
        },
        "hasVehicleBound": has_vehicle_bound,
    }


@router.post("/wechat/login", response_model=WeChatLoginResponse)
async def wechat_login(
    request: WeChatLoginRequest,
    db: AsyncSession = Depends(get_db),
):
    """WeChat Mini Program login.

    Exchange wx.login() code for user session and JWT token.

    Args:
        request: Contains the code from wx.login()
        db: Database session

    Returns:
        JWT access token and user info
    """
    try:
        async with WeChatClient() as client:
            # Exchange code for session
            session_data = await client.code2session(request.code)

            openid = session_data.get("openid")
            unionid = session_data.get("unionid")

            if not openid:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Failed to get openid from WeChat",
                )

            # Find or create user
            result = await db.execute(
                select(User).where(User.openid == openid)
            )
            user = result.scalar_one_or_none()

            if not user:
                user = User(
                    openid=openid,
                    unionid=unionid,
                )
                db.add(user)
                await db.commit()
                await db.refresh(user)
            elif unionid and not user.unionid:
                user.unionid = unionid
                await db.commit()

            # Check if Tesla is linked
            result = await db.execute(
                select(TeslaToken).where(TeslaToken.user_id == user.id)
            )
            has_tesla = result.scalar_one_or_none() is not None

            # Create JWT token
            expires_minutes = settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES
            access_token = create_access_token(
                data={"sub": str(user.id), "openid": openid},
                expires_delta=timedelta(minutes=expires_minutes),
            )

            return WeChatLoginResponse(
                access_token=access_token,
                token_type="Bearer",
                expires_in=expires_minutes * 60,
                user_id=user.id,
                openid=openid,
                has_tesla_linked=has_tesla,
            )

    except WeChatAPIError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"WeChat login failed: {e.message}",
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Login failed: {str(e)}",
        )


# ============ Email/Password Auth (for Android) ============


@router.post("/register", response_model=EmailAuthResponse)
async def email_register(
    request: EmailRegisterRequest,
    db: AsyncSession = Depends(get_db),
):
    """Register a new user with email and password (Android / non-
    WeChat clients). Logic in services/auth_service.register_email_user.
    """
    try:
        bundle = await _register_email_user(
            email=request.email,
            password=request.password,
            nickname=request.nickname,
            db=db,
        )
    except EmailAlreadyExistsError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc),
        )
    return EmailAuthResponse(
        access_token=bundle.access_token,
        token_type="Bearer",
        expires_in=bundle.expires_in,
        user_id=bundle.user_id,
        email=bundle.email,
        nickname=bundle.nickname,
        has_tesla_linked=bundle.has_tesla_linked,
    )


@router.post("/login", response_model=EmailAuthResponse)
async def email_login(
    request: EmailLoginRequest,
    db: AsyncSession = Depends(get_db),
):
    """Login with email and password. Logic in
    services/auth_service.login_email_user.
    """
    try:
        bundle = await _login_email_user(
            email=request.email, password=request.password, db=db,
        )
    except InvalidCredentialsError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc),
        )
    except AccountDisabledError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc),
        )
    return EmailAuthResponse(
        access_token=bundle.access_token,
        token_type="Bearer",
        expires_in=bundle.expires_in,
        user_id=bundle.user_id,
        email=bundle.email,
        nickname=bundle.nickname,
        has_tesla_linked=bundle.has_tesla_linked,
    )


class TeslaAuthResponseWithUser(BaseModel):
    """Tesla authorization URL response with user_id."""

    url: str
    state: str
    user_id: Optional[int] = None


@router.get("/tesla/authorize")
async def tesla_authorize(
    user_id: Optional[int] = Query(None, description="User ID to link Tesla to"),
    db: AsyncSession = Depends(get_db),
):
    """Get Tesla OAuth authorization URL.

    If user_id is not provided, creates an anonymous user (for testing).

    Returns:
        Authorization URL, state for CSRF protection, and user_id
    """
    import uuid

    created_user_id = user_id

    # If no user_id provided, create an anonymous user.
    #
    # WARN: this path historically leaked 242 test users into prod
    # (user did `auth/tesla/authorize` from iOS without keychain
    # user_id → fresh anon → bound to real Tesla VIN). Cleaned up on
    # 2026-05-10. The OAuth callback should dedupe the anon user
    # against existing users bound to the same VIN — TODO, tracked in
    # docs/features/. Until then, log every anon creation so we can
    # spot the leak rate.
    if not user_id:
        anonymous_email = f"android_{uuid.uuid4().hex[:8]}@test.local"
        new_user = User(
            email=anonymous_email,
            nickname="Test User",
        )
        db.add(new_user)
        await db.commit()
        await db.refresh(new_user)
        created_user_id = new_user.id
        import logging
        logging.getLogger(__name__).warning(
            "anonymous user created via /auth/tesla/authorize: id=%s email=%s "
            "(no user_id passed; expected if first-time iOS login but suspicious otherwise)",
            new_user.id, anonymous_email,
        )

    auth = TeslaAuth()
    result = auth.get_authorization_url()

    # Store state -> code_verifier mapping with user_id
    _oauth_states[result["state"]] = {
        "code_verifier": result["code_verifier"],
        "user_id": created_user_id,
    }

    return {
        "url": result["url"],
        "state": result["state"],
        "user_id": created_user_id,
    }


@router.get("/tesla/callback")
async def tesla_callback(
    code: str = Query(..., description="Authorization code from Tesla"),
    state: str = Query(..., description="State parameter for CSRF protection"),
    db: AsyncSession = Depends(get_db),
):
    """Handle Tesla OAuth callback (GET).

    Renders an HTML success/error page for the WebView. The exchange
    + persist + JWT-mint logic now lives in
    `services/tesla_auth_service.exchange_and_store`.
    """
    state_data = _oauth_states.pop(state, None)
    if not state_data:
        return HTMLResponse(
            content=_render_callback_page(
                success=False,
                message="Invalid or expired authorization. Please try again.",
            ),
            status_code=400,
        )

    code_verifier = state_data["code_verifier"]
    user_id = state_data.get("user_id")

    try:
        bundle = await _tesla_exchange_and_store(
            code=code, code_verifier=code_verifier,
            user_id=user_id, db=db,
        )
    except TeslaAuthError as exc:
        return HTMLResponse(
            content=_render_callback_page(
                success=False, message=str(exc),
            ),
            status_code=400,
        )

    # 2026-05-10 — dedup anonymous users that share a VIN with an
    # existing account. Returns the canonical user_id (may differ
    # from `user_id` if merge happened).
    if user_id is not None:
        from app.services.tesla_auth_service import dedup_anon_by_vin
        user_id = await dedup_anon_by_vin(
            db=db, user_id=user_id, access_token=bundle.access_token,
        )

    jwt_token = None
    if user_id:
        jwt_token = create_access_token(
            data={"sub": str(user_id)},
            expires_delta=timedelta(minutes=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES),
        )

    return HTMLResponse(
        content=_render_callback_page(
            success=True,
            message="Tesla account linked successfully!",
            user_id=user_id,
            jwt_token=jwt_token,
        ),
    )


@router.post("/tesla/callback", response_model=dict)
async def tesla_callback_post(
    request: TeslaCallbackRequest,
    user_id: Optional[int] = Query(None),
    db: AsyncSession = Depends(get_db),
):
    """Handle Tesla OAuth callback (POST).

    Used when an iOS native client OR the legacy Mini Program sends
    the OAuth code as JSON. Same exchange + persist logic as the
    GET handler, but JSON response.
    """
    state_data = _oauth_states.pop(request.state, None)
    if not state_data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired state parameter",
        )

    target_user_id = user_id or state_data.get("user_id")

    try:
        bundle = await _tesla_exchange_and_store(
            code=request.code,
            code_verifier=state_data["code_verifier"],
            user_id=target_user_id,
            db=db,
        )
    except TeslaAuthError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        )

    # 2026-05-10 — dedup anonymous users by VIN; see GET handler comment.
    if target_user_id is not None:
        from app.services.tesla_auth_service import dedup_anon_by_vin
        target_user_id = await dedup_anon_by_vin(
            db=db, user_id=target_user_id, access_token=bundle.access_token,
        )

    return {
        "success": True,
        "message": "Tesla account linked successfully",
        "expires_in": bundle.expires_in,
        "user_id": target_user_id,
    }


@router.post("/tesla/refresh")
async def tesla_refresh_token(
    refresh_token: str,
    user_id: Optional[int] = None,
    db: AsyncSession = Depends(get_db),
):
    """Refresh a Tesla access token. If user_id is given, the stored
    row is also updated.
    """
    try:
        bundle = await _tesla_refresh_and_store(
            refresh_token_in=refresh_token, user_id=user_id, db=db,
        )
    except TeslaAuthError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        )
    return {
        "success": True,
        "access_token": bundle.access_token,
        "refresh_token": bundle.refresh_token,
        "expires_in": bundle.expires_in,
    }


@router.get("/tesla/status")
async def tesla_link_status(
    user_id: int = Query(..., description="User ID to check"),
    db: AsyncSession = Depends(get_db),
):
    """Check if user has linked Tesla account.

    Args:
        user_id: User ID to check

    Returns:
        Link status and expiration info
    """
    result = await db.execute(
        select(TeslaToken).where(TeslaToken.user_id == user_id)
    )
    token = result.scalar_one_or_none()

    if not token:
        return {
            "linked": False,
            "expired": False,
            "message": "Tesla account not linked",
        }

    # Handle case where expires_at might be None
    if token.expires_at is None:
        is_expired = True
    else:
        is_expired = token.expires_at < datetime.utcnow()

    return {
        "linked": True,
        "expired": is_expired,
        "expires_at": token.expires_at.isoformat() if token.expires_at else None,
        "message": "Token expired, needs refresh" if is_expired else "Tesla account linked",
    }


@router.get("/tesla/test")
async def tesla_test():
    """Test Tesla OAuth configuration.

    Returns current configuration info (no sensitive data).
    """
    auth = TeslaAuth()
    auth_data = auth.get_authorization_url()

    return {
        "status": "ok",
        "config": {
            "client_id": settings.TESLA_CLIENT_ID[:8] + "..." if settings.TESLA_CLIENT_ID else "not set",
            "redirect_uri": settings.TESLA_REDIRECT_URI,
            "fleet_api_url": settings.TESLA_FLEET_API_BASE_URL,
        },
        "auth_url_preview": auth_data["url"][:100] + "...",
        "state": auth_data["state"],
    }


def _render_callback_page(
    success: bool,
    message: str,
    user_id: Optional[int] = None,
    jwt_token: Optional[str] = None,
) -> str:
    """Render HTML callback page for WebView.

    This page will be displayed in the Mini Program WebView after OAuth.
    It should communicate the result back to the Mini Program.
    """
    status_class = "success" if success else "error"
    status_icon = "check-circle" if success else "times-circle"
    status_color = "#07c160" if success else "#ee0a24"

    # JavaScript to communicate with Mini Program
    js_code = ""
    if success:
        js_code = f"""
        <script>
            // Attempt to close the WebView and return to Mini Program
            if (window.wx && wx.miniProgram) {{
                wx.miniProgram.postMessage({{
                    data: {{
                        type: 'tesla_auth_success',
                        message: '{message}'
                    }}
                }});
                setTimeout(function() {{
                    wx.miniProgram.navigateBack();
                }}, 2000);
            }}
        </script>
        """

    # Generate JSON data for Android to extract
    import json
    auth_data_json = json.dumps({
        "success": success,
        "user_id": user_id,
        "token": jwt_token,
    }) if success and jwt_token else ""

    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Tesla Authorization</title>
        <style>
            * {{
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }}
            body {{
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
                display: flex;
                align-items: center;
                justify-content: center;
                padding: 20px;
            }}
            .container {{
                background: white;
                border-radius: 16px;
                padding: 40px;
                text-align: center;
                max-width: 400px;
                width: 100%;
                box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            }}
            .icon {{
                width: 80px;
                height: 80px;
                border-radius: 50%;
                background: {status_color};
                margin: 0 auto 24px;
                display: flex;
                align-items: center;
                justify-content: center;
            }}
            .icon svg {{
                width: 40px;
                height: 40px;
                fill: white;
            }}
            h1 {{
                color: #333;
                font-size: 24px;
                margin-bottom: 16px;
            }}
            p {{
                color: #666;
                font-size: 16px;
                line-height: 1.5;
            }}
            .tip {{
                margin-top: 24px;
                padding: 12px;
                background: #f5f5f5;
                border-radius: 8px;
                font-size: 14px;
                color: #999;
            }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="icon">
                {"<svg viewBox='0 0 24 24'><path d='M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z'/></svg>" if success else "<svg viewBox='0 0 24 24'><path d='M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z'/></svg>"}
            </div>
            <h1>{"Authorization Successful" if success else "Authorization Failed"}</h1>
            <p>{message}</p>
            <div class="tip">
                {"Returning to app..." if success else "Please close this page and try again."}
            </div>
        </div>
        <div id="auth-data" style="display:none;">{auth_data_json}</div>
        {js_code}
    </body>
    </html>
    """
