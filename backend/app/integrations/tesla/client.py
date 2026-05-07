"""Tesla Fleet API client."""

import asyncio
from typing import Any, Dict, List, Optional

import httpx

from app.config import settings
from app.integrations.tesla.exceptions import (
    TeslaAPIError,
    TeslaVehicleOfflineError,
)


class TeslaClient:
    """Tesla Fleet API client.

    Implements all endpoints from Tesla Fleet API documentation.
    """

    def __init__(self, access_token: str, use_fleet_api: bool = True):
        """Initialize Tesla client with access token.

        Args:
            access_token: OAuth access token
            use_fleet_api: If True, use Fleet API; otherwise use Owner API
        """
        self.access_token = access_token
        self.base_url = (
            settings.TESLA_FLEET_API_BASE_URL
            if use_fleet_api
            else settings.TESLA_API_BASE_URL
        )
        # Phase 7 (VCP): vehicle commands (set_charge_limit etc.) must be
        # signed and routed through tesla-http-proxy. The proxy mirrors
        # the same REST URL shape as the deprecated direct endpoint, so
        # we just swap the base URL for command requests. Reads
        # (vehicle_data, wake_up, list_vehicles) keep going direct.
        self.command_proxy_url = settings.TESLA_VEHICLE_COMMAND_PROXY_URL
        self._client: Optional[httpx.AsyncClient] = None
        self._command_client: Optional[httpx.AsyncClient] = None

    async def _get_client(self) -> httpx.AsyncClient:
        """Get or create HTTP client for direct fleet API calls (reads)."""
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

    async def _get_command_client(self) -> httpx.AsyncClient:
        """Get or create HTTP client for tesla-http-proxy (signed commands).

        Proxy presents a self-signed TLS cert; verify is disabled because
        the connection target is `127.0.0.1` over localhost loopback —
        TLS exists only because the proxy refuses plaintext, not for
        confidentiality against an MITM that doesn't apply here.
        """
        if self._command_client is None:
            self._command_client = httpx.AsyncClient(
                base_url=self.command_proxy_url,
                headers={
                    "Authorization": f"Bearer {self.access_token}",
                    "Content-Type": "application/json",
                },
                timeout=30.0,
                verify=False,
            )
        return self._command_client

    async def close(self):
        """Close the HTTP client."""
        if self._client:
            await self._client.aclose()
            self._client = None
        if self._command_client:
            await self._command_client.aclose()
            self._command_client = None

    async def __aenter__(self):
        """Async context manager entry."""
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Async context manager exit."""
        await self.close()

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

            # Handle specific error codes
            if response.status_code == 408:
                raise TeslaVehicleOfflineError("unknown")

            response.raise_for_status()
            return response.json()
        except httpx.HTTPStatusError as e:
            raise TeslaAPIError(
                f"Tesla API error: {e.response.status_code} - {e.response.text}",
                status_code=e.response.status_code,
            )
        except httpx.RequestError as e:
            raise TeslaAPIError(f"Request failed: {str(e)}")

    # ==================== Vehicle Endpoints ====================

    async def list_vehicles(self) -> Dict[str, Any]:
        """Get list of user's vehicles.

        GET /api/1/vehicles
        """
        return await self._request("GET", "/api/1/vehicles")

    async def get_vehicle(self, vehicle_tag: str) -> Dict[str, Any]:
        """Get vehicle basic info.

        GET /api/1/vehicles/{vehicle_tag}
        """
        return await self._request("GET", f"/api/1/vehicles/{vehicle_tag}")

    async def get_vehicle_data(
        self,
        vehicle_tag: str,
        endpoints: Optional[List[str]] = None,
    ) -> Dict[str, Any]:
        """Get vehicle complete data.

        GET /api/1/vehicles/{vehicle_tag}/vehicle_data

        Args:
            vehicle_tag: Vehicle ID or VIN
            endpoints: Optional list of data endpoints to include
        """
        params = {}
        if endpoints:
            params["endpoints"] = ";".join(endpoints)
        return await self._request(
            "GET",
            f"/api/1/vehicles/{vehicle_tag}/vehicle_data",
            params=params,
        )

    async def get_vehicle_specs(self, vin: str) -> Dict[str, Any]:
        """Get vehicle specifications.

        GET /api/1/vehicles/{vin}/specs
        """
        return await self._request("GET", f"/api/1/vehicles/{vin}/specs")

    async def wake_up(self, vehicle_tag: str) -> Dict[str, Any]:
        """Wake up the vehicle.

        POST /api/1/vehicles/{vehicle_tag}/wake_up
        """
        return await self._request(
            "POST", f"/api/1/vehicles/{vehicle_tag}/wake_up"
        )

    async def is_mobile_enabled(self, vehicle_tag: str) -> Dict[str, Any]:
        """Check if mobile access is enabled.

        GET /api/1/vehicles/{vehicle_tag}/mobile_enabled
        """
        return await self._request(
            "GET", f"/api/1/vehicles/{vehicle_tag}/mobile_enabled"
        )

    async def get_fleet_status(self, vins: List[str]) -> Dict[str, Any]:
        """Get fleet status for multiple vehicles.

        POST /api/1/vehicles/fleet_status
        """
        return await self._request(
            "POST",
            "/api/1/vehicles/fleet_status",
            json={"vins": vins},
        )

    async def get_nearby_charging_sites(
        self,
        vehicle_tag: str,
        count: int = 10,
        radius: int = 50,
    ) -> Dict[str, Any]:
        """Get nearby charging sites.

        GET /api/1/vehicles/{vehicle_tag}/nearby_charging_sites
        """
        return await self._request(
            "GET",
            f"/api/1/vehicles/{vehicle_tag}/nearby_charging_sites",
            params={"count": count, "radius": radius},
        )

    async def get_drivers(self, vehicle_tag: str) -> Dict[str, Any]:
        """Get vehicle authorized drivers.

        GET /api/1/vehicles/{vehicle_tag}/drivers
        """
        return await self._request(
            "GET", f"/api/1/vehicles/{vehicle_tag}/drivers"
        )

    async def get_recent_alerts(self, vehicle_tag: str) -> Dict[str, Any]:
        """Get recent vehicle alerts.

        GET /api/1/vehicles/{vehicle_tag}/recent_alerts
        """
        return await self._request(
            "GET", f"/api/1/vehicles/{vehicle_tag}/recent_alerts"
        )

    async def get_release_notes(self, vehicle_tag: str) -> Dict[str, Any]:
        """Get firmware release notes.

        GET /api/1/vehicles/{vehicle_tag}/release_notes
        """
        return await self._request(
            "GET", f"/api/1/vehicles/{vehicle_tag}/release_notes"
        )

    async def get_service_data(self, vehicle_tag: str) -> Dict[str, Any]:
        """Get vehicle service/maintenance data.

        GET /api/1/vehicles/{vehicle_tag}/service_data
        """
        return await self._request(
            "GET", f"/api/1/vehicles/{vehicle_tag}/service_data"
        )

    # ==================== Vehicle Commands ====================

    async def _send_command(
        self,
        vehicle_tag: str,
        command: str,
        data: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """Send a SIGNED command to the vehicle via tesla-http-proxy.

        POST {proxy}/api/1/vehicles/{vehicle_tag}/command/{command}

        Tesla deprecated the direct REST command endpoint on 2023-10-09
        and now requires Vehicle Command Protocol (signed commands).
        We route through a local tesla-http-proxy that holds the
        partner private key and signs each request before forwarding
        to Tesla Fleet API.
        """
        client = await self._get_command_client()
        endpoint = f"/api/1/vehicles/{vehicle_tag}/command/{command}"
        try:
            response = await client.post(endpoint, json=data or {})
            if response.status_code == 408:
                raise TeslaVehicleOfflineError("unknown")
            response.raise_for_status()
            return response.json()
        except httpx.HTTPStatusError as e:
            raise TeslaAPIError(
                f"Tesla API error: {e.response.status_code} - {e.response.text}",
                status_code=e.response.status_code,
            )
        except httpx.RequestError as e:
            raise TeslaAPIError(f"Request failed: {str(e)}")

    # Door & Window Control
    async def door_lock(self, vehicle_tag: str) -> Dict[str, Any]:
        """Lock vehicle doors."""
        return await self._send_command(vehicle_tag, "door_lock")

    async def door_unlock(self, vehicle_tag: str) -> Dict[str, Any]:
        """Unlock vehicle doors."""
        return await self._send_command(vehicle_tag, "door_unlock")

    async def actuate_trunk(
        self, vehicle_tag: str, which_trunk: str = "rear"
    ) -> Dict[str, Any]:
        """Open/close trunk.

        Args:
            which_trunk: "front" or "rear"
        """
        return await self._send_command(
            vehicle_tag, "actuate_trunk", {"which_trunk": which_trunk}
        )

    async def window_control(
        self,
        vehicle_tag: str,
        command: str,
        lat: float = 0,
        lon: float = 0,
    ) -> Dict[str, Any]:
        """Control windows.

        Args:
            command: "vent" or "close"
            lat, lon: Vehicle location (required for security)
        """
        return await self._send_command(
            vehicle_tag,
            "window_control",
            {"command": command, "lat": lat, "lon": lon},
        )

    async def sun_roof_control(
        self, vehicle_tag: str, state: str
    ) -> Dict[str, Any]:
        """Control sun roof.

        Args:
            state: "stop", "close", or "vent"
        """
        return await self._send_command(
            vehicle_tag, "sun_roof_control", {"state": state}
        )

    async def charge_port_door_open(self, vehicle_tag: str) -> Dict[str, Any]:
        """Open charge port door."""
        return await self._send_command(vehicle_tag, "charge_port_door_open")

    async def charge_port_door_close(self, vehicle_tag: str) -> Dict[str, Any]:
        """Close charge port door."""
        return await self._send_command(vehicle_tag, "charge_port_door_close")

    # Charging Control
    async def charge_start(self, vehicle_tag: str) -> Dict[str, Any]:
        """Start charging."""
        return await self._send_command(vehicle_tag, "charge_start")

    async def charge_stop(self, vehicle_tag: str) -> Dict[str, Any]:
        """Stop charging."""
        return await self._send_command(vehicle_tag, "charge_stop")

    async def set_charge_limit(
        self, vehicle_tag: str, percent: int
    ) -> Dict[str, Any]:
        """Set charge limit percentage.

        Args:
            percent: 50-100
        """
        return await self._send_command(
            vehicle_tag, "set_charge_limit", {"percent": percent}
        )

    async def set_charging_amps(
        self, vehicle_tag: str, amps: int
    ) -> Dict[str, Any]:
        """Set charging amperage.

        Args:
            amps: Charging current in amps
        """
        return await self._send_command(
            vehicle_tag, "set_charging_amps", {"charging_amps": amps}
        )

    async def charge_standard(self, vehicle_tag: str) -> Dict[str, Any]:
        """Set standard charge mode."""
        return await self._send_command(vehicle_tag, "charge_standard")

    async def charge_max_range(self, vehicle_tag: str) -> Dict[str, Any]:
        """Set max range charge mode."""
        return await self._send_command(vehicle_tag, "charge_max_range")

    # Climate Control
    async def auto_conditioning_start(self, vehicle_tag: str) -> Dict[str, Any]:
        """Start HVAC."""
        return await self._send_command(vehicle_tag, "auto_conditioning_start")

    async def auto_conditioning_stop(self, vehicle_tag: str) -> Dict[str, Any]:
        """Stop HVAC."""
        return await self._send_command(vehicle_tag, "auto_conditioning_stop")

    async def set_temps(
        self,
        vehicle_tag: str,
        driver_temp: float,
        passenger_temp: float,
    ) -> Dict[str, Any]:
        """Set cabin temperatures.

        Args:
            driver_temp: Driver side temp in Celsius
            passenger_temp: Passenger side temp in Celsius
        """
        return await self._send_command(
            vehicle_tag,
            "set_temps",
            {"driver_temp": driver_temp, "passenger_temp": passenger_temp},
        )

    async def set_preconditioning_max(
        self, vehicle_tag: str, on: bool
    ) -> Dict[str, Any]:
        """Set preconditioning to max."""
        return await self._send_command(
            vehicle_tag, "set_preconditioning_max", {"on": on}
        )

    async def set_climate_keeper_mode(
        self, vehicle_tag: str, mode: int
    ) -> Dict[str, Any]:
        """Set climate keeper mode.

        Args:
            mode: 0=off, 1=keep, 2=dog, 3=camp
        """
        return await self._send_command(
            vehicle_tag, "set_climate_keeper_mode", {"climate_keeper_mode": mode}
        )

    async def set_cabin_overheat_protection(
        self,
        vehicle_tag: str,
        on: bool,
        fan_only: bool = False,
    ) -> Dict[str, Any]:
        """Set cabin overheat protection."""
        return await self._send_command(
            vehicle_tag,
            "set_cabin_overheat_protection",
            {"on": on, "fan_only": fan_only},
        )

    # Seat & Steering Wheel Heating
    async def remote_seat_heater_request(
        self,
        vehicle_tag: str,
        seat: int,
        level: int,
    ) -> Dict[str, Any]:
        """Set seat heater level.

        Args:
            seat: 0=driver, 1=passenger, 2=rear-left, 4=rear-center, 5=rear-right
            level: 0=off, 1=low, 2=medium, 3=high
        """
        return await self._send_command(
            vehicle_tag,
            "remote_seat_heater_request",
            {"heater": seat, "level": level},
        )

    async def remote_steering_wheel_heater_request(
        self, vehicle_tag: str, on: bool
    ) -> Dict[str, Any]:
        """Set steering wheel heater."""
        return await self._send_command(
            vehicle_tag,
            "remote_steering_wheel_heater_request",
            {"on": on},
        )

    # Navigation
    async def navigation_request(
        self,
        vehicle_tag: str,
        address: str,
        locale: str = "en-US",
    ) -> Dict[str, Any]:
        """Send navigation destination.

        Args:
            address: Destination address string
            locale: Locale for address parsing
        """
        return await self._send_command(
            vehicle_tag,
            "navigation_request",
            {"type": "share_ext_content_raw", "value": {"android.intent.extra.TEXT": address}, "locale": locale},
        )

    async def navigation_gps_request(
        self,
        vehicle_tag: str,
        lat: float,
        lon: float,
        order: int = 1,
    ) -> Dict[str, Any]:
        """Navigate to GPS coordinates.

        Args:
            lat: Latitude
            lon: Longitude
            order: Waypoint order (1 for single destination)
        """
        return await self._send_command(
            vehicle_tag,
            "navigation_gps_request",
            {"lat": lat, "lon": lon, "order": order},
        )

    async def navigation_sc_request(
        self,
        vehicle_tag: str,
        supercharger_id: str,
        order: int = 1,
    ) -> Dict[str, Any]:
        """Navigate to Supercharger.

        Args:
            supercharger_id: Supercharger location ID
            order: Waypoint order
        """
        return await self._send_command(
            vehicle_tag,
            "navigation_sc_request",
            {"id": supercharger_id, "order": order},
        )

    # Media Control
    async def media_toggle_playback(self, vehicle_tag: str) -> Dict[str, Any]:
        """Toggle media playback."""
        return await self._send_command(vehicle_tag, "media_toggle_playback")

    async def media_next_track(self, vehicle_tag: str) -> Dict[str, Any]:
        """Next track."""
        return await self._send_command(vehicle_tag, "media_next_track")

    async def media_prev_track(self, vehicle_tag: str) -> Dict[str, Any]:
        """Previous track."""
        return await self._send_command(vehicle_tag, "media_prev_track")

    async def adjust_volume(
        self, vehicle_tag: str, volume: float
    ) -> Dict[str, Any]:
        """Adjust volume.

        Args:
            volume: Volume level 0.0-11.0
        """
        return await self._send_command(
            vehicle_tag, "adjust_volume", {"volume": volume}
        )

    # Security & Modes
    async def set_sentry_mode(
        self, vehicle_tag: str, on: bool
    ) -> Dict[str, Any]:
        """Enable/disable sentry mode."""
        return await self._send_command(
            vehicle_tag, "set_sentry_mode", {"on": on}
        )

    async def set_valet_mode(
        self,
        vehicle_tag: str,
        on: bool,
        password: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Enable/disable valet mode.

        Args:
            on: Enable or disable
            password: 4-digit PIN (required when enabling)
        """
        data = {"on": on}
        if password:
            data["password"] = password
        return await self._send_command(vehicle_tag, "set_valet_mode", data)

    # Speed Limit
    async def speed_limit_activate(
        self, vehicle_tag: str, pin: str
    ) -> Dict[str, Any]:
        """Activate speed limit mode.

        Args:
            pin: 4-digit PIN
        """
        return await self._send_command(
            vehicle_tag, "speed_limit_activate", {"pin": pin}
        )

    async def speed_limit_deactivate(
        self, vehicle_tag: str, pin: str
    ) -> Dict[str, Any]:
        """Deactivate speed limit mode."""
        return await self._send_command(
            vehicle_tag, "speed_limit_deactivate", {"pin": pin}
        )

    async def speed_limit_set_limit(
        self, vehicle_tag: str, limit_mph: int
    ) -> Dict[str, Any]:
        """Set speed limit.

        Args:
            limit_mph: Speed limit in mph (50-90)
        """
        return await self._send_command(
            vehicle_tag, "speed_limit_set_limit", {"limit_mph": limit_mph}
        )

    # Other Commands
    async def remote_start_drive(self, vehicle_tag: str) -> Dict[str, Any]:
        """Remote start the vehicle."""
        return await self._send_command(vehicle_tag, "remote_start_drive")

    async def flash_lights(self, vehicle_tag: str) -> Dict[str, Any]:
        """Flash vehicle lights."""
        return await self._send_command(vehicle_tag, "flash_lights")

    async def honk_horn(self, vehicle_tag: str) -> Dict[str, Any]:
        """Honk vehicle horn."""
        return await self._send_command(vehicle_tag, "honk_horn")

    async def trigger_homelink(
        self,
        vehicle_tag: str,
        lat: float,
        lon: float,
    ) -> Dict[str, Any]:
        """Trigger HomeLink.

        Args:
            lat, lon: Vehicle location (for security verification)
        """
        return await self._send_command(
            vehicle_tag, "trigger_homelink", {"lat": lat, "lon": lon}
        )

    async def set_vehicle_name(
        self, vehicle_tag: str, name: str
    ) -> Dict[str, Any]:
        """Set vehicle display name."""
        return await self._send_command(
            vehicle_tag, "set_vehicle_name", {"vehicle_name": name}
        )

    async def schedule_software_update(
        self, vehicle_tag: str, offset_sec: int = 0
    ) -> Dict[str, Any]:
        """Schedule software update.

        Args:
            offset_sec: Seconds from now to start update
        """
        return await self._send_command(
            vehicle_tag, "schedule_software_update", {"offset_sec": offset_sec}
        )

    async def cancel_software_update(self, vehicle_tag: str) -> Dict[str, Any]:
        """Cancel scheduled software update."""
        return await self._send_command(vehicle_tag, "cancel_software_update")

    # ==================== Charging Endpoints ====================

    async def get_charging_history(
        self,
        page: int = 1,
        per_page: int = 20,
    ) -> Dict[str, Any]:
        """Get charging history.

        GET /api/1/dx/charging/history
        """
        return await self._request(
            "GET",
            "/api/1/dx/charging/history",
            params={"page": page, "per_page": per_page},
        )

    async def get_charging_invoice(self, invoice_id: str) -> Dict[str, Any]:
        """Get charging invoice.

        GET /api/1/dx/charging/invoice/{id}
        """
        return await self._request(
            "GET", f"/api/1/dx/charging/invoice/{invoice_id}"
        )

    async def get_charging_sessions(
        self,
        vin: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Get charging sessions.

        GET /api/1/dx/charging/sessions
        """
        params = {}
        if vin:
            params["vin"] = vin
        return await self._request(
            "GET", "/api/1/dx/charging/sessions", params=params
        )

    # ==================== Helper Methods ====================

    async def ensure_vehicle_online(
        self,
        vehicle_tag: str,
        max_attempts: int = 5,
    ) -> Dict[str, Any]:
        """Ensure vehicle is online, wake up if needed.

        Args:
            vehicle_tag: Vehicle ID or VIN
            max_attempts: Maximum wake up attempts

        Returns:
            Vehicle data when online
        """
        for attempt in range(max_attempts):
            try:
                data = await self.get_vehicle_data(vehicle_tag)
                response = data.get("response", {})
                if response.get("state") == "online":
                    return data
            except TeslaAPIError as e:
                if e.status_code != 408:
                    raise

            # Try to wake up
            await self.wake_up(vehicle_tag)
            await asyncio.sleep(2 ** attempt)

        raise TeslaVehicleOfflineError(vehicle_tag)

    # Convenience methods for common data access
    async def get_charge_state(self, vehicle_tag: str) -> Dict[str, Any]:
        """Get vehicle charge state."""
        data = await self.get_vehicle_data(
            vehicle_tag,
            endpoints=["charge_state"],
        )
        return data.get("response", {}).get("charge_state", {})

    async def get_drive_state(self, vehicle_tag: str) -> Dict[str, Any]:
        """Get vehicle drive state (location, heading, speed).

        Uses location_data endpoint to ensure GPS coordinates are included.
        """
        data = await self.get_vehicle_data(
            vehicle_tag,
            endpoints=["location_data", "drive_state"],
        )
        return data.get("response", {}).get("drive_state", {})

    async def get_vehicle_config(self, vehicle_tag: str) -> Dict[str, Any]:
        """Get vehicle configuration."""
        data = await self.get_vehicle_data(vehicle_tag)
        return data.get("response", {}).get("vehicle_config", {})

    async def get_climate_state(self, vehicle_tag: str) -> Dict[str, Any]:
        """Get vehicle climate state."""
        data = await self.get_vehicle_data(vehicle_tag)
        return data.get("response", {}).get("climate_state", {})

    async def get_gui_settings(self, vehicle_tag: str) -> Dict[str, Any]:
        """Get GUI settings."""
        data = await self.get_vehicle_data(vehicle_tag)
        return data.get("response", {}).get("gui_settings", {})
