"""WeChat Mini Program API client."""

from typing import Any, Dict, Optional

import httpx

from app.config import settings


class WeChatClient:
    """Client for WeChat Mini Program APIs."""

    BASE_URL = "https://api.weixin.qq.com"

    def __init__(
        self,
        app_id: Optional[str] = None,
        app_secret: Optional[str] = None,
    ):
        """Initialize WeChat client.

        Args:
            app_id: WeChat App ID, defaults to settings.
            app_secret: WeChat App Secret, defaults to settings.
        """
        self.app_id = app_id or settings.WECHAT_APP_ID
        self.app_secret = app_secret or settings.WECHAT_APP_SECRET
        self._client: Optional[httpx.AsyncClient] = None

    async def _get_client(self) -> httpx.AsyncClient:
        """Get or create HTTP client."""
        if self._client is None:
            self._client = httpx.AsyncClient(
                base_url=self.BASE_URL,
                timeout=30.0,
            )
        return self._client

    async def close(self):
        """Close the HTTP client."""
        if self._client:
            await self._client.aclose()
            self._client = None

    async def __aenter__(self):
        """Async context manager entry."""
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Async context manager exit."""
        await self.close()

    async def code2session(self, code: str) -> Dict[str, Any]:
        """Exchange login code for session info.

        This is the main API for WeChat Mini Program login.
        Exchange the wx.login() code for openid and session_key.

        Args:
            code: Login code from wx.login()

        Returns:
            Dict containing:
            - openid: User's unique identifier
            - session_key: Session key for decrypting user info
            - unionid: (optional) Union ID if bound to open platform

        Raises:
            WeChatAPIError: If the API call fails
        """
        client = await self._get_client()

        response = await client.get(
            "/sns/jscode2session",
            params={
                "appid": self.app_id,
                "secret": self.app_secret,
                "js_code": code,
                "grant_type": "authorization_code",
            },
        )

        response.raise_for_status()
        data = response.json()

        if "errcode" in data and data["errcode"] != 0:
            raise WeChatAPIError(
                code=data.get("errcode"),
                message=data.get("errmsg", "Unknown error"),
            )

        return data

    async def get_access_token(self) -> str:
        """Get access token for server-side API calls.

        Returns:
            Access token string

        Raises:
            WeChatAPIError: If the API call fails
        """
        client = await self._get_client()

        response = await client.get(
            "/cgi-bin/token",
            params={
                "grant_type": "client_credential",
                "appid": self.app_id,
                "secret": self.app_secret,
            },
        )

        response.raise_for_status()
        data = response.json()

        if "errcode" in data and data["errcode"] != 0:
            raise WeChatAPIError(
                code=data.get("errcode"),
                message=data.get("errmsg", "Unknown error"),
            )

        return data.get("access_token", "")

    async def get_phone_number(
        self,
        code: str,
        access_token: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Get user's phone number from encrypted data.

        Requires user to grant phone number permission in Mini Program.

        Args:
            code: Code from button tap
            access_token: Access token, will fetch if not provided

        Returns:
            Dict containing phone_info with:
            - phoneNumber: Full phone number with country code
            - purePhoneNumber: Phone number without country code
            - countryCode: Country code

        Raises:
            WeChatAPIError: If the API call fails
        """
        if not access_token:
            access_token = await self.get_access_token()

        client = await self._get_client()

        response = await client.post(
            "/wxa/business/getuserphonenumber",
            params={"access_token": access_token},
            json={"code": code},
        )

        response.raise_for_status()
        data = response.json()

        if data.get("errcode", 0) != 0:
            raise WeChatAPIError(
                code=data.get("errcode"),
                message=data.get("errmsg", "Unknown error"),
            )

        return data.get("phone_info", {})


class WeChatAPIError(Exception):
    """WeChat API error."""

    def __init__(self, code: int, message: str):
        self.code = code
        self.message = message
        super().__init__(f"WeChat API Error {code}: {message}")
