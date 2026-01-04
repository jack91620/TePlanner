"""Tesla OAuth authentication."""

import base64
import hashlib
import secrets
from typing import Dict, Optional
from urllib.parse import urlencode

import httpx

from app.config import settings
from app.integrations.tesla.exceptions import TeslaAuthError


class TeslaAuth:
    """Tesla OAuth 2.0 authentication handler (Fleet API).

    China region uses .cn domains.
    """

    # China region URLs
    AUTH_URL = "https://auth.tesla.cn/oauth2/v3/authorize"
    TOKEN_URL = "https://auth.tesla.cn/oauth2/v3/token"

    # International URLs (for reference)
    # AUTH_URL = "https://auth.tesla.com/oauth2/v3/authorize"
    # TOKEN_URL = "https://auth.tesla.com/oauth2/v3/token"

    # Fleet API 权限范围
    SCOPES = [
        "openid",
        "email",
        "offline_access",
        "vehicle_device_data",
        "vehicle_location",
        "vehicle_cmds",
    ]

    def __init__(self):
        """Initialize Tesla auth handler."""
        self.client_id = settings.TESLA_CLIENT_ID
        self.client_secret = settings.TESLA_CLIENT_SECRET
        self.redirect_uri = settings.TESLA_REDIRECT_URI

    def _generate_code_verifier(self) -> str:
        """Generate PKCE code verifier."""
        return secrets.token_urlsafe(64)

    def _generate_code_challenge(self, verifier: str) -> str:
        """Generate PKCE code challenge from verifier (S256 method)."""
        digest = hashlib.sha256(verifier.encode()).digest()
        return base64.urlsafe_b64encode(digest).rstrip(b"=").decode()

    def get_authorization_url(self, state: Optional[str] = None) -> Dict[str, str]:
        """Generate OAuth authorization URL.

        Returns:
            Dict with 'url', 'state', and 'code_verifier' keys.
        """
        if state is None:
            state = secrets.token_urlsafe(32)

        # Generate PKCE code verifier and challenge
        code_verifier = self._generate_code_verifier()
        code_challenge = self._generate_code_challenge(code_verifier)

        params = {
            "client_id": self.client_id,
            "redirect_uri": self.redirect_uri,
            "response_type": "code",
            "scope": " ".join(self.SCOPES),
            "state": state,
            # PKCE parameters
            "code_challenge": code_challenge,
            "code_challenge_method": "S256",
        }

        url = f"{self.AUTH_URL}?{urlencode(params)}"

        return {
            "url": url,
            "state": state,
            "code_verifier": code_verifier,
        }

    async def exchange_code(
        self,
        code: str,
        code_verifier: str,
    ) -> Dict[str, str]:
        """Exchange authorization code for tokens.

        Args:
            code: Authorization code from callback.
            code_verifier: PKCE code verifier.

        Returns:
            Dict with access_token, refresh_token, expires_in.
        """
        async with httpx.AsyncClient() as client:
            response = await client.post(
                self.TOKEN_URL,
                data={
                    "grant_type": "authorization_code",
                    "client_id": self.client_id,
                    "client_secret": self.client_secret,
                    "code": code,
                    "redirect_uri": self.redirect_uri,
                    "code_verifier": code_verifier,
                },
            )

            if response.status_code != 200:
                error_detail = response.text
                raise TeslaAuthError(
                    f"Token exchange failed: {response.status_code} - {error_detail}"
                )

            return response.json()

    async def refresh_token(self, refresh_token: str) -> Dict[str, str]:
        """Refresh access token.

        Args:
            refresh_token: Refresh token.

        Returns:
            Dict with new access_token, refresh_token, expires_in.
        """
        async with httpx.AsyncClient() as client:
            response = await client.post(
                self.TOKEN_URL,
                data={
                    "grant_type": "refresh_token",
                    "client_id": self.client_id,
                    "client_secret": self.client_secret,
                    "refresh_token": refresh_token,
                },
            )

            if response.status_code != 200:
                error_detail = response.text
                raise TeslaAuthError(
                    f"Token refresh failed: {response.status_code} - {error_detail}"
                )

            return response.json()
