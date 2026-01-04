"""Authentication endpoints."""

from typing import Optional

from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import RedirectResponse
from pydantic import BaseModel

from app.integrations.tesla import TeslaAuth

router = APIRouter()

# 临时存储 OAuth state 和 code_verifier（生产环境应使用 Redis）
_oauth_states: dict = {}


class TeslaAuthResponse(BaseModel):
    """Tesla authorization URL response."""

    url: str
    state: str


class TeslaCallbackRequest(BaseModel):
    """Tesla OAuth callback request."""

    code: str
    state: str


class TeslaTokenResponse(BaseModel):
    """Tesla token response."""

    access_token: str
    refresh_token: str
    expires_in: int
    token_type: str


@router.post("/wechat/login")
async def wechat_login(code: str):
    """WeChat miniprogram login."""
    # TODO: Implement WeChat login
    return {"message": "WeChat login endpoint", "code": code}


@router.get("/tesla/authorize", response_model=TeslaAuthResponse)
async def tesla_authorize():
    """获取 Tesla OAuth 授权 URL.

    Returns:
        包含授权 URL 和 state 的响应
    """
    auth = TeslaAuth()
    result = auth.get_authorization_url()

    # 存储 state 和 code_verifier 的映射关系
    _oauth_states[result["state"]] = result["code_verifier"]

    return TeslaAuthResponse(
        url=result["url"],
        state=result["state"],
    )


@router.get("/tesla/callback")
async def tesla_callback(
    code: str = Query(..., description="Authorization code from Tesla"),
    state: str = Query(..., description="State parameter for CSRF protection"),
):
    """处理 Tesla OAuth 回调.

    Args:
        code: Tesla 返回的授权码
        state: 用于 CSRF 保护的 state 参数

    Returns:
        Token 信息或错误
    """
    # 验证 state 并获取 code_verifier
    code_verifier = _oauth_states.pop(state, None)
    if not code_verifier:
        raise HTTPException(
            status_code=400,
            detail="Invalid or expired state parameter",
        )

    try:
        auth = TeslaAuth()
        tokens = await auth.exchange_code(code, code_verifier)

        return {
            "success": True,
            "message": "Tesla 账号授权成功",
            "access_token": tokens.get("access_token"),
            "refresh_token": tokens.get("refresh_token"),
            "expires_in": tokens.get("expires_in"),
            "token_type": tokens.get("token_type", "Bearer"),
        }
    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail=f"Token exchange failed: {str(e)}",
        )


@router.post("/tesla/callback", response_model=dict)
async def tesla_callback_post(request: TeslaCallbackRequest):
    """处理 Tesla OAuth 回调 (POST 方式).

    用于小程序端发送授权码。
    """
    code_verifier = _oauth_states.pop(request.state, None)
    if not code_verifier:
        raise HTTPException(
            status_code=400,
            detail="Invalid or expired state parameter",
        )

    try:
        auth = TeslaAuth()
        tokens = await auth.exchange_code(request.code, code_verifier)

        return {
            "success": True,
            "message": "Tesla 账号授权成功",
            "access_token": tokens.get("access_token"),
            "refresh_token": tokens.get("refresh_token"),
            "expires_in": tokens.get("expires_in"),
        }
    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail=f"Token exchange failed: {str(e)}",
        )


@router.post("/tesla/refresh")
async def tesla_refresh_token(refresh_token: str):
    """刷新 Tesla access token.

    Args:
        refresh_token: 刷新令牌

    Returns:
        新的 token 信息
    """
    try:
        auth = TeslaAuth()
        tokens = await auth.refresh_token(refresh_token)

        return {
            "success": True,
            "access_token": tokens.get("access_token"),
            "refresh_token": tokens.get("refresh_token"),
            "expires_in": tokens.get("expires_in"),
        }
    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail=f"Token refresh failed: {str(e)}",
        )


@router.get("/tesla/test")
async def tesla_test():
    """测试 Tesla OAuth 配置.

    返回当前配置信息（不包含敏感数据）。
    """
    from app.config import settings

    auth = TeslaAuth()
    auth_data = auth.get_authorization_url()

    return {
        "status": "ok",
        "config": {
            "client_id": settings.TESLA_CLIENT_ID,
            "redirect_uri": settings.TESLA_REDIRECT_URI,
            "fleet_api_url": settings.TESLA_FLEET_API_BASE_URL,
        },
        "auth_url_preview": auth_data["url"][:100] + "...",
        "state": auth_data["state"],
    }
