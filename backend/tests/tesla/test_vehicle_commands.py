"""Tesla Fleet API vehicle commands tests.

This script tests vehicle command endpoints from the Fleet API.
WARNING: Some commands will actually control the vehicle!

Usage:
    # Run with pytest (mocked tests only)
    pytest tests/tesla/test_vehicle_commands.py -v

    # Run standalone with real token (CAUTION: will control vehicle)
    python tests/tesla/test_vehicle_commands.py --token YOUR_ACCESS_TOKEN
"""

import asyncio
import sys
from typing import Optional

import pytest

# Hits live tesla-http-proxy at 127.0.0.1:4443 with a fake OAuth
# token → every test returns 403. Excluded from default pytest run
# (see pyproject.toml addopts `-m "not integration"`). Opt in with:
#   cd backend && pytest -m integration tests/tesla/
pytestmark = pytest.mark.integration

sys.path.insert(0, "/home/dongxinbo/SourceCode/TePlanner/backend")

from app.integrations.tesla.client import TeslaClient
from app.integrations.tesla.exceptions import TeslaAPIError


class TestVehicleCommands:
    """Test cases for Tesla vehicle commands."""

    # ==================== Door & Window Control ====================

    @pytest.mark.asyncio
    async def test_door_lock(self, mocker):
        """Test door_lock command."""
        mock_response = {"response": {"result": True, "reason": ""}}

        client = TeslaClient("mock_token")
        mocker.patch.object(client, "_request", return_value=mock_response)

        result = await client.door_lock("12345")

        assert result["response"]["result"] is True
        await client.close()

    @pytest.mark.asyncio
    async def test_door_unlock(self, mocker):
        """Test door_unlock command."""
        mock_response = {"response": {"result": True, "reason": ""}}

        client = TeslaClient("mock_token")
        mocker.patch.object(client, "_request", return_value=mock_response)

        result = await client.door_unlock("12345")

        assert result["response"]["result"] is True
        await client.close()

    @pytest.mark.asyncio
    async def test_actuate_trunk(self, mocker):
        """Test actuate_trunk command."""
        mock_response = {"response": {"result": True, "reason": ""}}

        client = TeslaClient("mock_token")
        mocker.patch.object(client, "_request", return_value=mock_response)

        result = await client.actuate_trunk("12345", "rear")

        assert result["response"]["result"] is True
        await client.close()

    @pytest.mark.asyncio
    async def test_window_control(self, mocker):
        """Test window_control command."""
        mock_response = {"response": {"result": True, "reason": ""}}

        client = TeslaClient("mock_token")
        mocker.patch.object(client, "_request", return_value=mock_response)

        result = await client.window_control("12345", "close", 31.23, 121.47)

        assert result["response"]["result"] is True
        await client.close()

    @pytest.mark.asyncio
    async def test_charge_port_door_open(self, mocker):
        """Test charge_port_door_open command."""
        mock_response = {"response": {"result": True, "reason": ""}}

        client = TeslaClient("mock_token")
        mocker.patch.object(client, "_request", return_value=mock_response)

        result = await client.charge_port_door_open("12345")

        assert result["response"]["result"] is True
        await client.close()

    # ==================== Charging Control ====================

    @pytest.mark.asyncio
    async def test_charge_start(self, mocker):
        """Test charge_start command."""
        mock_response = {"response": {"result": True, "reason": ""}}

        client = TeslaClient("mock_token")
        mocker.patch.object(client, "_request", return_value=mock_response)

        result = await client.charge_start("12345")

        assert result["response"]["result"] is True
        await client.close()

    @pytest.mark.asyncio
    async def test_charge_stop(self, mocker):
        """Test charge_stop command."""
        mock_response = {"response": {"result": True, "reason": ""}}

        client = TeslaClient("mock_token")
        mocker.patch.object(client, "_request", return_value=mock_response)

        result = await client.charge_stop("12345")

        assert result["response"]["result"] is True
        await client.close()

    @pytest.mark.asyncio
    async def test_set_charge_limit(self, mocker):
        """Test set_charge_limit command."""
        mock_response = {"response": {"result": True, "reason": ""}}

        client = TeslaClient("mock_token")
        mocker.patch.object(client, "_request", return_value=mock_response)

        result = await client.set_charge_limit("12345", 80)

        assert result["response"]["result"] is True
        await client.close()

    @pytest.mark.asyncio
    async def test_set_charging_amps(self, mocker):
        """Test set_charging_amps command."""
        mock_response = {"response": {"result": True, "reason": ""}}

        client = TeslaClient("mock_token")
        mocker.patch.object(client, "_request", return_value=mock_response)

        result = await client.set_charging_amps("12345", 16)

        assert result["response"]["result"] is True
        await client.close()

    # ==================== Climate Control ====================

    @pytest.mark.asyncio
    async def test_auto_conditioning_start(self, mocker):
        """Test auto_conditioning_start command."""
        mock_response = {"response": {"result": True, "reason": ""}}

        client = TeslaClient("mock_token")
        mocker.patch.object(client, "_request", return_value=mock_response)

        result = await client.auto_conditioning_start("12345")

        assert result["response"]["result"] is True
        await client.close()

    @pytest.mark.asyncio
    async def test_auto_conditioning_stop(self, mocker):
        """Test auto_conditioning_stop command."""
        mock_response = {"response": {"result": True, "reason": ""}}

        client = TeslaClient("mock_token")
        mocker.patch.object(client, "_request", return_value=mock_response)

        result = await client.auto_conditioning_stop("12345")

        assert result["response"]["result"] is True
        await client.close()

    @pytest.mark.asyncio
    async def test_set_temps(self, mocker):
        """Test set_temps command."""
        mock_response = {"response": {"result": True, "reason": ""}}

        client = TeslaClient("mock_token")
        mocker.patch.object(client, "_request", return_value=mock_response)

        result = await client.set_temps("12345", 22.0, 22.0)

        assert result["response"]["result"] is True
        await client.close()

    @pytest.mark.asyncio
    async def test_set_climate_keeper_mode(self, mocker):
        """Test set_climate_keeper_mode command."""
        mock_response = {"response": {"result": True, "reason": ""}}

        client = TeslaClient("mock_token")
        mocker.patch.object(client, "_request", return_value=mock_response)

        # 0=off, 1=keep, 2=dog, 3=camp
        result = await client.set_climate_keeper_mode("12345", 2)

        assert result["response"]["result"] is True
        await client.close()

    @pytest.mark.asyncio
    async def test_remote_seat_heater_request(self, mocker):
        """Test remote_seat_heater_request command."""
        mock_response = {"response": {"result": True, "reason": ""}}

        client = TeslaClient("mock_token")
        mocker.patch.object(client, "_request", return_value=mock_response)

        # seat 0=driver, level 2=medium
        result = await client.remote_seat_heater_request("12345", 0, 2)

        assert result["response"]["result"] is True
        await client.close()

    # ==================== Navigation ====================

    @pytest.mark.asyncio
    async def test_navigation_request(self, mocker):
        """Test navigation_request command."""
        mock_response = {"response": {"result": True, "reason": ""}}

        client = TeslaClient("mock_token")
        mocker.patch.object(client, "_request", return_value=mock_response)

        result = await client.navigation_request("12345", "Shanghai, China")

        assert result["response"]["result"] is True
        await client.close()

    @pytest.mark.asyncio
    async def test_navigation_gps_request(self, mocker):
        """Test navigation_gps_request command."""
        mock_response = {"response": {"result": True, "reason": ""}}

        client = TeslaClient("mock_token")
        mocker.patch.object(client, "_request", return_value=mock_response)

        result = await client.navigation_gps_request("12345", 31.2304, 121.4737)

        assert result["response"]["result"] is True
        await client.close()

    @pytest.mark.asyncio
    async def test_navigation_sc_request(self, mocker):
        """Test navigation_sc_request command."""
        mock_response = {"response": {"result": True, "reason": ""}}

        client = TeslaClient("mock_token")
        mocker.patch.object(client, "_request", return_value=mock_response)

        result = await client.navigation_sc_request("12345", "sc_123456")

        assert result["response"]["result"] is True
        await client.close()

    # ==================== Media Control ====================

    @pytest.mark.asyncio
    async def test_media_toggle_playback(self, mocker):
        """Test media_toggle_playback command."""
        mock_response = {"response": {"result": True, "reason": ""}}

        client = TeslaClient("mock_token")
        mocker.patch.object(client, "_request", return_value=mock_response)

        result = await client.media_toggle_playback("12345")

        assert result["response"]["result"] is True
        await client.close()

    @pytest.mark.asyncio
    async def test_adjust_volume(self, mocker):
        """Test adjust_volume command."""
        mock_response = {"response": {"result": True, "reason": ""}}

        client = TeslaClient("mock_token")
        mocker.patch.object(client, "_request", return_value=mock_response)

        result = await client.adjust_volume("12345", 5.0)

        assert result["response"]["result"] is True
        await client.close()

    # ==================== Security & Modes ====================

    @pytest.mark.asyncio
    async def test_set_sentry_mode(self, mocker):
        """Test set_sentry_mode command."""
        mock_response = {"response": {"result": True, "reason": ""}}

        client = TeslaClient("mock_token")
        mocker.patch.object(client, "_request", return_value=mock_response)

        result = await client.set_sentry_mode("12345", True)

        assert result["response"]["result"] is True
        await client.close()

    @pytest.mark.asyncio
    async def test_set_valet_mode(self, mocker):
        """Test set_valet_mode command."""
        mock_response = {"response": {"result": True, "reason": ""}}

        client = TeslaClient("mock_token")
        mocker.patch.object(client, "_request", return_value=mock_response)

        result = await client.set_valet_mode("12345", True, "1234")

        assert result["response"]["result"] is True
        await client.close()

    # ==================== Other Commands ====================

    @pytest.mark.asyncio
    async def test_flash_lights(self, mocker):
        """Test flash_lights command."""
        mock_response = {"response": {"result": True, "reason": ""}}

        client = TeslaClient("mock_token")
        mocker.patch.object(client, "_request", return_value=mock_response)

        result = await client.flash_lights("12345")

        assert result["response"]["result"] is True
        await client.close()

    @pytest.mark.asyncio
    async def test_honk_horn(self, mocker):
        """Test honk_horn command."""
        mock_response = {"response": {"result": True, "reason": ""}}

        client = TeslaClient("mock_token")
        mocker.patch.object(client, "_request", return_value=mock_response)

        result = await client.honk_horn("12345")

        assert result["response"]["result"] is True
        await client.close()

    @pytest.mark.asyncio
    async def test_remote_start_drive(self, mocker):
        """Test remote_start_drive command."""
        mock_response = {"response": {"result": True, "reason": ""}}

        client = TeslaClient("mock_token")
        mocker.patch.object(client, "_request", return_value=mock_response)

        result = await client.remote_start_drive("12345")

        assert result["response"]["result"] is True
        await client.close()

    @pytest.mark.asyncio
    async def test_set_vehicle_name(self, mocker):
        """Test set_vehicle_name command."""
        mock_response = {"response": {"result": True, "reason": ""}}

        client = TeslaClient("mock_token")
        mocker.patch.object(client, "_request", return_value=mock_response)

        result = await client.set_vehicle_name("12345", "My New Tesla")

        assert result["response"]["result"] is True
        await client.close()

    @pytest.mark.asyncio
    async def test_command_failure_reason(self, mocker):
        """Test command failure with reason."""
        mock_response = {
            "response": {
                "result": False,
                "reason": "vehicle_unavailable",
            }
        }

        client = TeslaClient("mock_token")
        mocker.patch.object(client, "_request", return_value=mock_response)

        result = await client.door_lock("12345")

        assert result["response"]["result"] is False
        assert result["response"]["reason"] == "vehicle_unavailable"
        await client.close()


# ==================== Integration Tests (Real API) ====================


async def run_integration_tests(
    access_token: str,
    vehicle_id: Optional[str] = None,
    safe_mode: bool = True,
):
    """Run integration tests against real Tesla API.

    WARNING: This will send real commands to the vehicle!

    Args:
        access_token: Valid OAuth access token
        vehicle_id: Optional specific vehicle ID to test
        safe_mode: If True, only run safe commands (flash, honk)
    """
    print("=" * 60)
    print("Tesla Fleet API - Vehicle Commands Integration Tests")
    print("=" * 60)
    print(f"Safe Mode: {safe_mode}")
    if not safe_mode:
        print("WARNING: Unsafe commands will be executed!")

    async with TeslaClient(access_token) as client:
        # Get vehicle
        print("\n[SETUP] Getting vehicle list...")
        try:
            result = await client.list_vehicles()
            vehicles = result.get("response", [])

            if not vehicles:
                print("No vehicles found.")
                return

            test_vehicle = vehicle_id or vehicles[0].get("id")
            print(f"Using vehicle: {vehicles[0].get('display_name')} ({test_vehicle})")

        except TeslaAPIError as e:
            print(f"FAILED: {e}")
            return

        # Wake up vehicle first
        print("\n[SETUP] Waking up vehicle...")
        try:
            await client.ensure_vehicle_online(test_vehicle)
            print("Vehicle is online")
        except Exception as e:
            print(f"FAILED: {e}")
            return

        # Test 1: Flash lights (safe)
        print("\n[TEST 1] Flash Lights")
        print("-" * 40)
        try:
            result = await client.flash_lights(test_vehicle)
            response = result.get("response", {})
            print(f"Result: {response.get('result')}")
            print(f"Reason: {response.get('reason', 'N/A')}")
        except TeslaAPIError as e:
            print(f"FAILED: {e}")

        # Test 2: Honk horn (safe but noisy)
        if not safe_mode:
            print("\n[TEST 2] Honk Horn")
            print("-" * 40)
            try:
                result = await client.honk_horn(test_vehicle)
                response = result.get("response", {})
                print(f"Result: {response.get('result')}")
            except TeslaAPIError as e:
                print(f"FAILED: {e}")

        # Test 3: Door lock (safe)
        print("\n[TEST 3] Door Lock")
        print("-" * 40)
        try:
            result = await client.door_lock(test_vehicle)
            response = result.get("response", {})
            print(f"Result: {response.get('result')}")
        except TeslaAPIError as e:
            print(f"FAILED: {e}")

        # Test 4: Climate control (safe)
        if not safe_mode:
            print("\n[TEST 4] Start Climate")
            print("-" * 40)
            try:
                result = await client.auto_conditioning_start(test_vehicle)
                response = result.get("response", {})
                print(f"Result: {response.get('result')}")

                await asyncio.sleep(2)

                # Stop it
                result = await client.auto_conditioning_stop(test_vehicle)
                print(f"Stopped: {result.get('response', {}).get('result')}")
            except TeslaAPIError as e:
                print(f"FAILED: {e}")

        # Test 5: Set charge limit (safe if car is not charging)
        if not safe_mode:
            print("\n[TEST 5] Set Charge Limit")
            print("-" * 40)
            try:
                # Get current limit
                charge_state = await client.get_charge_state(test_vehicle)
                current_limit = charge_state.get("charge_limit_soc")
                print(f"Current limit: {current_limit}%")

                # Set to 80%
                result = await client.set_charge_limit(test_vehicle, 80)
                response = result.get("response", {})
                print(f"Set to 80%: {response.get('result')}")

                # Restore original
                if current_limit:
                    await client.set_charge_limit(test_vehicle, current_limit)
                    print(f"Restored to: {current_limit}%")

            except TeslaAPIError as e:
                print(f"FAILED: {e}")

        # Test 6: Sentry mode
        if not safe_mode:
            print("\n[TEST 6] Sentry Mode Toggle")
            print("-" * 40)
            try:
                # Get current state
                vehicle_data = await client.get_vehicle_data(test_vehicle)
                current_state = vehicle_data.get("response", {}).get("vehicle_state", {}).get("sentry_mode")
                print(f"Current sentry mode: {current_state}")

                # Toggle
                result = await client.set_sentry_mode(test_vehicle, not current_state)
                response = result.get("response", {})
                print(f"Toggle result: {response.get('result')}")

                # Restore
                await client.set_sentry_mode(test_vehicle, current_state)
                print(f"Restored to: {current_state}")

            except TeslaAPIError as e:
                print(f"FAILED: {e}")

        # Test 7: Open charge port (safe if not plugged in)
        print("\n[TEST 7] Open Charge Port")
        print("-" * 40)
        try:
            result = await client.charge_port_door_open(test_vehicle)
            response = result.get("response", {})
            print(f"Result: {response.get('result')}")
        except TeslaAPIError as e:
            print(f"FAILED: {e}")

    print("\n" + "=" * 60)
    print("Command Tests Complete")
    print("=" * 60)


def main():
    """Main entry point for standalone execution."""
    import argparse

    parser = argparse.ArgumentParser(description="Test Tesla Fleet API vehicle commands")
    parser.add_argument("--token", required=True, help="OAuth access token")
    parser.add_argument("--vehicle", help="Specific vehicle ID to test")
    parser.add_argument(
        "--unsafe",
        action="store_true",
        help="Run unsafe commands (honk, climate, etc)",
    )

    args = parser.parse_args()

    asyncio.run(
        run_integration_tests(
            args.token,
            args.vehicle,
            safe_mode=not args.unsafe,
        )
    )


if __name__ == "__main__":
    main()
