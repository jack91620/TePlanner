"""Tesla OAuth authentication."""

import secrets
from typing import Dict, Optional
from urllib.parse import urlencode

import httpx

from app.config import settings
from app.integrations.tesla.exceptions import TeslaAuthError


class TeslaAuth:
    """Tesla OAuth 2.0 authentication handler."""

    AUTH_URL = "https://auth.tesla.com/oauth2/v3/authorize"
    TOKEN_URL = "https://auth.tesla.com/oauth2/v3/token"
    REDIRECT_URI = "https://your-domain.com/api/v1/auth/tesla/callback"
    SCOPES = ["openid", "email", "offline_access", "vehicle_device_data"]

    def __init__(self):
        """Initialize Tesla auth handler."""
        self.client_id = settings.TESLA_CLIENT_ID
        self.client_secret = settings.TESLA_CLIENT_SECRET

    def get_authorization_url(self, state: Optional[str] = None) -> Dict[str, str]:
        """Generate OAuth authorization URL.

        Returns:
            Dict with 'url' and 'state' keys.
        """
        if state is None:
            state = secrets.token_urlsafe(32)

        # Generate code verifier and challenge for PKCE
        code_verifier = secrets.token_urlsafe(64)

        params = {
            "client_id": self.client_id,
            "redirect_uri": self.REDIRECT_URI,
            "response_type": "code",
            "scope": " ".join(self.SCOPES),
            "state": state,
            # For PKCE flow
            "code_challenge": code_verifier,  # Should be SHA256 hash
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
                    "code": code,
                    "redirect_uri": self.REDIRECT_URI,
                    "code_verifier": code_verifier,
                },
            )

            if response.status_code != 200:
                raise TeslaAuthError(
                    f"Token exchange failed: {response.status_code}"
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
                    "refresh_token": refresh_token,
                },
            )

            if response.status_code != 200:
                raise TeslaAuthError(
                    f"Token refresh failed: {response.status_code}"
                )

            return response.json()
