"""Authentication endpoints."""

from fastapi import APIRouter, HTTPException

router = APIRouter()


@router.post("/wechat/login")
async def wechat_login(code: str):
    """WeChat miniprogram login."""
    # TODO: Implement WeChat login
    return {"message": "WeChat login endpoint", "code": code}


@router.post("/tesla/authorize")
async def tesla_authorize():
    """Get Tesla OAuth authorization URL."""
    # TODO: Implement Tesla OAuth
    return {"auth_url": "https://auth.tesla.com/oauth2/v3/authorize?..."}


@router.post("/tesla/callback")
async def tesla_callback(code: str, state: str):
    """Handle Tesla OAuth callback."""
    # TODO: Exchange code for tokens
    return {"message": "Tesla OAuth callback", "code": code}


@router.post("/tesla/refresh")
async def tesla_refresh_token(refresh_token: str):
    """Refresh Tesla access token."""
    # TODO: Implement token refresh
    return {"message": "Token refresh endpoint"}
