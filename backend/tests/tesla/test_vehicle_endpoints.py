"""Tesla Fleet API vehicle endpoints tests.

This script tests all vehicle information endpoints from the Fleet API.
Requires a valid OAuth access token to run against real API.

Usage:
    # Run with pytest
    pytest tests/tesla/test_vehicle_endpoints.py -v

    # Run standalone with real token
    python tests/tesla/test_vehicle_endpoints.py --token YOUR_ACCESS_TOKEN
"""

import asyncio
import json
import sys
from typing import Any, Dict, Optional

import pytest

# Tesla Fleet API integration — needs live OAuth token. Excluded
# from default pytest run; opt in with `pytest -m integration`.
pytestmark = pytest.mark.integration

# Add project root to path for standalone execution
sys.path.insert(0, "/home/dongxinbo/SourceCode/TePlanner/backend")

from app.integrations.tesla.client import TeslaClient
from app.integrations.tesla.exceptions import TeslaAPIError, TeslaVehicleOfflineError


class TestVehicleEndpoints:
    """Test cases for Tesla vehicle endpoints."""

    @pytest.fixture
    def mock_client(self, mocker):
        """Create a mocked Tesla client."""
        client = TeslaClient("mock_token")
        return client

    # ==================== Unit Tests (Mocked) ====================

    @pytest.mark.asyncio
    async def test_list_vehicles_structure(self, mocker):
        """Test list_vehicles returns expected structure."""
        mock_response = {
            "response": [
                {
                    "id": "12345",
                    "vehicle_id": 67890,
                    "vin": "5YJ3E1EA1KF000001",
                    "display_name": "My Tesla",
                    "state": "online",
                }
            ],
            "count": 1,
        }

        client = TeslaClient("mock_token")
        mocker.patch.object(client, "_request", return_value=mock_response)

        result = await client.list_vehicles()

        assert "response" in result
        assert isinstance(result["response"], list)
        assert len(result["response"]) == 1
        assert result["response"][0]["vin"] == "5YJ3E1EA1KF000001"

        await client.close()

    @pytest.mark.asyncio
    async def test_get_vehicle_data_structure(self, mocker):
        """Test get_vehicle_data returns expected structure."""
        mock_response = {
            "response": {
                "id": "12345",
                "vehicle_id": 67890,
                "vin": "5YJ3E1EA1KF000001",
                "display_name": "My Tesla",
                "state": "online",
                "charge_state": {
                    "battery_level": 75,
                    "battery_range": 200.5,
                    "charging_state": "Disconnected",
                },
                "drive_state": {
                    "latitude": 31.2304,
                    "longitude": 121.4737,
                    "heading": 90,
                },
                "climate_state": {
                    "inside_temp": 22.0,
                    "outside_temp": 18.0,
                    "is_climate_on": False,
                },
                "vehicle_config": {
                    "car_type": "model3",
                    "exterior_color": "White",
                },
            }
        }

        client = TeslaClient("mock_token")
        mocker.patch.object(client, "_request", return_value=mock_response)

        result = await client.get_vehicle_data("12345")

        response = result["response"]
        assert response["state"] == "online"
        assert response["charge_state"]["battery_level"] == 75
        assert response["drive_state"]["latitude"] == 31.2304
        assert response["climate_state"]["inside_temp"] == 22.0

        await client.close()

    @pytest.mark.asyncio
    async def test_wake_up_vehicle(self, mocker):
        """Test wake_up sends correct request."""
        mock_response = {
            "response": {
                "id": "12345",
                "state": "online",
            }
        }

        client = TeslaClient("mock_token")
        mocker.patch.object(client, "_request", return_value=mock_response)

        result = await client.wake_up("12345")

        assert result["response"]["state"] == "online"
        await client.close()

    @pytest.mark.asyncio
    async def test_get_nearby_charging_sites(self, mocker):
        """Test get_nearby_charging_sites returns charging stations."""
        mock_response = {
            "response": {
                "superchargers": [
                    {
                        "id": "sc1",
                        "name": "Shanghai Supercharger",
                        "location": {"lat": 31.2, "long": 121.4},
                        "available_stalls": 5,
                        "total_stalls": 10,
                    }
                ],
                "destination_charging": [
                    {
                        "id": "dc1",
                        "name": "Hotel Charger",
                        "location": {"lat": 31.3, "long": 121.5},
                    }
                ],
            }
        }

        client = TeslaClient("mock_token")
        mocker.patch.object(client, "_request", return_value=mock_response)

        result = await client.get_nearby_charging_sites("12345")

        assert "superchargers" in result["response"]
        assert len(result["response"]["superchargers"]) == 1
        assert result["response"]["superchargers"][0]["available_stalls"] == 5

        await client.close()

    @pytest.mark.asyncio
    async def test_ensure_vehicle_online_success(self, mocker):
        """Test ensure_vehicle_online wakes up sleeping vehicle."""
        # First call returns asleep, second returns online
        responses = [
            {"response": {"state": "asleep"}},
            {"response": {"state": "online"}},
        ]

        client = TeslaClient("mock_token")
        call_count = 0

        async def mock_get_vehicle_data(vehicle_tag):
            nonlocal call_count
            result = responses[min(call_count, len(responses) - 1)]
            call_count += 1
            return result

        mocker.patch.object(client, "get_vehicle_data", side_effect=mock_get_vehicle_data)
        mocker.patch.object(client, "wake_up", return_value={"response": {}})
        mocker.patch("asyncio.sleep", return_value=None)

        result = await client.ensure_vehicle_online("12345")

        assert result["response"]["state"] == "online"
        await client.close()

    @pytest.mark.asyncio
    async def test_get_charge_state_convenience(self, mocker):
        """Test get_charge_state convenience method."""
        mock_response = {
            "response": {
                "charge_state": {
                    "battery_level": 80,
                    "charging_state": "Complete",
                    "time_to_full_charge": 0,
                }
            }
        }

        client = TeslaClient("mock_token")
        mocker.patch.object(client, "get_vehicle_data", return_value=mock_response)

        result = await client.get_charge_state("12345")

        assert result["battery_level"] == 80
        assert result["charging_state"] == "Complete"

        await client.close()

    @pytest.mark.asyncio
    async def test_get_drive_state_convenience(self, mocker):
        """Test get_drive_state convenience method."""
        mock_response = {
            "response": {
                "drive_state": {
                    "latitude": 31.2304,
                    "longitude": 121.4737,
                    "heading": 180,
                    "speed": None,
                }
            }
        }

        client = TeslaClient("mock_token")
        mocker.patch.object(client, "get_vehicle_data", return_value=mock_response)

        result = await client.get_drive_state("12345")

        assert result["latitude"] == 31.2304
        assert result["longitude"] == 121.4737

        await client.close()

    @pytest.mark.asyncio
    async def test_api_error_handling(self, mocker):
        """Test API error handling."""
        client = TeslaClient("mock_token")
        mocker.patch.object(
            client,
            "_request",
            side_effect=TeslaAPIError("Unauthorized", status_code=401),
        )

        with pytest.raises(TeslaAPIError) as exc_info:
            await client.list_vehicles()

        assert exc_info.value.status_code == 401

        await client.close()


# ==================== Integration Tests (Real API) ====================


async def run_integration_tests(access_token: str, vehicle_id: Optional[str] = None):
    """Run integration tests against real Tesla API.

    Args:
        access_token: Valid OAuth access token
        vehicle_id: Optional specific vehicle ID to test
    """
    print("=" * 60)
    print("Tesla Fleet API - Vehicle Endpoints Integration Tests")
    print("=" * 60)

    async with TeslaClient(access_token) as client:
        # Test 1: List vehicles
        print("\n[TEST 1] List Vehicles")
        print("-" * 40)
        try:
            result = await client.list_vehicles()
            vehicles = result.get("response", [])
            print(f"Found {len(vehicles)} vehicle(s)")

            if not vehicles:
                print("No vehicles found. Cannot continue tests.")
                return

            for v in vehicles:
                print(f"  - {v.get('display_name')} ({v.get('vin')})")
                print(f"    State: {v.get('state')}")
                print(f"    ID: {v.get('id')}")

            # Use first vehicle or specified vehicle
            test_vehicle = vehicle_id or vehicles[0].get("id")
            test_vin = vehicles[0].get("vin")
            print(f"\nUsing vehicle ID: {test_vehicle}")

        except TeslaAPIError as e:
            print(f"FAILED: {e}")
            return

        # Test 2: Get vehicle info
        print("\n[TEST 2] Get Vehicle Info")
        print("-" * 40)
        try:
            result = await client.get_vehicle(test_vehicle)
            response = result.get("response", {})
            print(f"Vehicle: {response.get('display_name')}")
            print(f"State: {response.get('state')}")
        except TeslaAPIError as e:
            print(f"FAILED: {e}")

        # Test 3: Wake up vehicle (if asleep)
        print("\n[TEST 3] Wake Up Vehicle")
        print("-" * 40)
        try:
            result = await client.wake_up(test_vehicle)
            response = result.get("response", {})
            print(f"State after wake_up: {response.get('state')}")
        except TeslaAPIError as e:
            print(f"FAILED: {e}")

        # Test 4: Get vehicle data
        print("\n[TEST 4] Get Vehicle Data")
        print("-" * 40)
        try:
            result = await client.get_vehicle_data(test_vehicle)
            response = result.get("response", {})

            charge_state = response.get("charge_state", {})
            print(f"Battery Level: {charge_state.get('battery_level')}%")
            print(f"Battery Range: {charge_state.get('battery_range')} miles")
            print(f"Charging State: {charge_state.get('charging_state')}")

            drive_state = response.get("drive_state", {})
            print(f"Location: ({drive_state.get('latitude')}, {drive_state.get('longitude')})")
            print(f"Heading: {drive_state.get('heading')} degrees")

            climate_state = response.get("climate_state", {})
            print(f"Inside Temp: {climate_state.get('inside_temp')} C")
            print(f"Outside Temp: {climate_state.get('outside_temp')} C")

        except TeslaAPIError as e:
            print(f"FAILED: {e}")

        # Test 5: Get charge state (convenience method)
        print("\n[TEST 5] Get Charge State")
        print("-" * 40)
        try:
            result = await client.get_charge_state(test_vehicle)
            print(f"Battery Level: {result.get('battery_level')}%")
            print(f"Usable Battery: {result.get('usable_battery_level')}%")
            print(f"Charge Rate: {result.get('charge_rate')} mph")
            print(f"Time to Full: {result.get('time_to_full_charge')} hours")
        except TeslaAPIError as e:
            print(f"FAILED: {e}")

        # Test 6: Get drive state (convenience method)
        print("\n[TEST 6] Get Drive State")
        print("-" * 40)
        try:
            result = await client.get_drive_state(test_vehicle)
            print(f"Latitude: {result.get('latitude')}")
            print(f"Longitude: {result.get('longitude')}")
            print(f"Heading: {result.get('heading')}")
            print(f"Speed: {result.get('speed')}")
        except TeslaAPIError as e:
            print(f"FAILED: {e}")

        # Test 7: Get nearby charging sites
        print("\n[TEST 7] Get Nearby Charging Sites")
        print("-" * 40)
        try:
            result = await client.get_nearby_charging_sites(test_vehicle)
            response = result.get("response", {})

            superchargers = response.get("superchargers", [])
            print(f"Superchargers nearby: {len(superchargers)}")
            for sc in superchargers[:3]:
                print(f"  - {sc.get('name')}: {sc.get('available_stalls')}/{sc.get('total_stalls')} stalls")

            dest_charging = response.get("destination_charging", [])
            print(f"Destination chargers nearby: {len(dest_charging)}")

        except TeslaAPIError as e:
            print(f"FAILED: {e}")

        # Test 8: Check mobile enabled
        print("\n[TEST 8] Check Mobile Enabled")
        print("-" * 40)
        try:
            result = await client.is_mobile_enabled(test_vehicle)
            print(f"Mobile Access Enabled: {result.get('response')}")
        except TeslaAPIError as e:
            print(f"FAILED: {e}")

        # Test 9: Get vehicle specs
        print("\n[TEST 9] Get Vehicle Specs")
        print("-" * 40)
        try:
            result = await client.get_vehicle_specs(test_vin)
            response = result.get("response", {})
            print(f"Model: {response.get('model')}")
            print(f"Trim: {response.get('trim')}")
            print(f"Year: {response.get('year')}")
        except TeslaAPIError as e:
            print(f"FAILED: {e}")

        # Test 10: Get climate state (convenience method)
        print("\n[TEST 10] Get Climate State")
        print("-" * 40)
        try:
            result = await client.get_climate_state(test_vehicle)
            print(f"Inside Temp: {result.get('inside_temp')} C")
            print(f"Outside Temp: {result.get('outside_temp')} C")
            print(f"Climate On: {result.get('is_climate_on')}")
            print(f"Preconditioning: {result.get('is_preconditioning')}")
        except TeslaAPIError as e:
            print(f"FAILED: {e}")

    print("\n" + "=" * 60)
    print("Integration Tests Complete")
    print("=" * 60)


def main():
    """Main entry point for standalone execution."""
    import argparse

    parser = argparse.ArgumentParser(description="Test Tesla Fleet API vehicle endpoints")
    parser.add_argument("--token", required=True, help="OAuth access token")
    parser.add_argument("--vehicle", help="Specific vehicle ID to test")

    args = parser.parse_args()

    asyncio.run(run_integration_tests(args.token, args.vehicle))


if __name__ == "__main__":
    main()
