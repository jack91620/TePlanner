"""Tesla Token Manager.

Handles automatic token refresh and secure storage.
"""

import asyncio
from datetime import datetime, timedelta
from typing import Optional

from app.config import settings
from app.integrations.tesla.auth import TeslaAuth
from app.integrations.tesla.exceptions import TeslaAuthError


class TeslaTokenManager:
    """Manages Tesla OAuth tokens with automatic refresh."""

    # Refresh token 5 minutes before expiry
    REFRESH_BUFFER_SECONDS = 300

    def __init__(
        self,
        access_token: str,
        refresh_token: str,
        expires_at: datetime,
    ):
        """Initialize token manager.

        Args:
            access_token: Current access token
            refresh_token: Refresh token for renewal
            expires_at: When the access token expires
        """
        self.access_token = access_token
        self.refresh_token = refresh_token
        self.expires_at = expires_at
        self._auth = TeslaAuth()
        self._refresh_lock = asyncio.Lock()

    @classmethod
    def from_oauth_response(
        cls,
        response: dict,
        issued_at: Optional[datetime] = None,
    ) -> "TeslaTokenManager":
        """Create from OAuth token response.

        Args:
            response: OAuth response with access_token, refresh_token, expires_in
            issued_at: When the token was issued (default: now)
        """
        issued_at = issued_at or datetime.utcnow()
        expires_in = response.get("expires_in", 28800)  # Default 8 hours

        return cls(
            access_token=response["access_token"],
            refresh_token=response["refresh_token"],
            expires_at=issued_at + timedelta(seconds=expires_in),
        )

    def is_expired(self) -> bool:
        """Check if token is expired or about to expire."""
        buffer = timedelta(seconds=self.REFRESH_BUFFER_SECONDS)
        return datetime.utcnow() >= (self.expires_at - buffer)

    async def get_valid_token(self) -> str:
        """Get a valid access token, refreshing if necessary.

        Returns:
            Valid access token
        """
        if not self.is_expired():
            return self.access_token

        # Use lock to prevent multiple simultaneous refreshes
        async with self._refresh_lock:
            # Double-check after acquiring lock
            if not self.is_expired():
                return self.access_token

            await self._refresh()
            return self.access_token

    async def _refresh(self) -> None:
        """Refresh the access token."""
        try:
            response = await self._auth.refresh_token(self.refresh_token)

            self.access_token = response["access_token"]
            # Some providers return a new refresh token
            if "refresh_token" in response:
                self.refresh_token = response["refresh_token"]

            expires_in = response.get("expires_in", 28800)
            self.expires_at = datetime.utcnow() + timedelta(seconds=expires_in)

        except TeslaAuthError as e:
            # Refresh token might be revoked
            raise TeslaAuthError(
                f"Token refresh failed. User may need to re-authorize: {e}"
            )

    def to_dict(self) -> dict:
        """Export tokens for storage.

        Returns:
            Dict with tokens and expiry for database storage
        """
        return {
            "access_token": self.access_token,
            "refresh_token": self.refresh_token,
            "expires_at": self.expires_at.isoformat(),
        }

    @classmethod
    def from_dict(cls, data: dict) -> "TeslaTokenManager":
        """Create from stored data.

        Args:
            data: Dict with access_token, refresh_token, expires_at
        """
        expires_at = data["expires_at"]
        if isinstance(expires_at, str):
            expires_at = datetime.fromisoformat(expires_at)

        return cls(
            access_token=data["access_token"],
            refresh_token=data["refresh_token"],
            expires_at=expires_at,
        )


# Example usage with user database
class UserTeslaService:
    """Service for managing user's Tesla connection."""

    async def get_user_tesla_client(self, user_id: str):
        """Get Tesla client for a user with valid token.

        Args:
            user_id: User ID

        Returns:
            TeslaClient with valid token, or None if not bound
        """
        from app.integrations.tesla.client import TeslaClient

        # TODO: Load from database
        # user = await db.get_user(user_id)
        # if not user.tesla_tokens:
        #     return None

        # token_manager = TeslaTokenManager.from_dict(user.tesla_tokens)
        # valid_token = await token_manager.get_valid_token()

        # # Update stored tokens if refreshed
        # await db.update_user_tesla_tokens(user_id, token_manager.to_dict())

        # return TeslaClient(valid_token)
        pass

    async def bind_tesla_account(
        self,
        user_id: str,
        oauth_response: dict,
    ) -> bool:
        """Bind Tesla account to user.

        Args:
            user_id: User ID
            oauth_response: OAuth token response

        Returns:
            True if successful
        """
        token_manager = TeslaTokenManager.from_oauth_response(oauth_response)

        # TODO: Save to database
        # await db.update_user(user_id, {
        #     "tesla_tokens": token_manager.to_dict(),
        #     "tesla_bound_at": datetime.utcnow(),
        # })

        return True

    async def unbind_tesla_account(self, user_id: str) -> bool:
        """Unbind Tesla account from user.

        Args:
            user_id: User ID

        Returns:
            True if successful
        """
        # TODO: Clear from database
        # await db.update_user(user_id, {
        #     "tesla_tokens": None,
        #     "tesla_bound_at": None,
        # })

        return True
