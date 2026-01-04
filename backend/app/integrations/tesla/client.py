"""Tesla API client."""

from typing import Any, Dict, Optional

import httpx

from app.config import settings
from app.integrations.tesla.exceptions import TeslaAPIError


class TeslaClient:
    """Tesla API client for Owner API (MVP) and Fleet API (future)."""

    def __init__(self, access_token: str):
        """Initialize Tesla client with access token."""
        self.access_token = access_token
        self.base_url = settings.TESLA_API_BASE_URL
        self._client: Optional[httpx.AsyncClient] = None

    async def _get_client(self) -> httpx.AsyncClient:
        """Get or create HTTP client."""
        if self._client is None:
            self._client = httpx.AsyncClient(
                base_url=self.base_url,
                headers={
                    "Authorization": f"Bearer {self.access_token}",
                    "Content-Type": "application/json",
                },
                timeout=30.0,
            )
        return self._client

    async def close(self):
        """Close the HTTP client."""
        if self._client:
            await self._client.aclose()
            self._client = None

    async def _request(
        self,
        method: str,
        endpoint: str,
        **kwargs,
    ) -> Dict[str, Any]:
        """Make an API request."""
        client = await self._get_client()
        try:
            response = await client.request(method, endpoint, **kwargs)
            response.raise_for_status()
            return response.json()
        except httpx.HTTPStatusError as e:
            raise TeslaAPIError(
                f"Tesla API error: {e.response.status_code}",
                status_code=e.response.status_code,
            )
        except httpx.RequestError as e:
            raise TeslaAPIError(f"Request failed: {str(e)}")

    async def get_vehicles(self) -> Dict[str, Any]:
        """Get list of user's vehicles."""
        return await self._request("GET", "/api/1/vehicles")

    async def get_vehicle_data(self, vehicle_id: str) -> Dict[str, Any]:
        """Get vehicle data including battery and location."""
        return await self._request(
            "GET", f"/api/1/vehicles/{vehicle_id}/vehicle_data"
        )

    async def wake_up(self, vehicle_id: str) -> Dict[str, Any]:
        """Wake up the vehicle."""
        return await self._request(
            "POST", f"/api/1/vehicles/{vehicle_id}/wake_up"
        )

    async def get_charge_state(self, vehicle_id: str) -> Dict[str, Any]:
        """Get vehicle charge state."""
        data = await self.get_vehicle_data(vehicle_id)
        return data.get("response", {}).get("charge_state", {})

    async def get_drive_state(self, vehicle_id: str) -> Dict[str, Any]:
        """Get vehicle drive state (location, heading, speed)."""
        data = await self.get_vehicle_data(vehicle_id)
        return data.get("response", {}).get("drive_state", {})

    async def get_vehicle_config(self, vehicle_id: str) -> Dict[str, Any]:
        """Get vehicle configuration."""
        data = await self.get_vehicle_data(vehicle_id)
        return data.get("response", {}).get("vehicle_config", {})
