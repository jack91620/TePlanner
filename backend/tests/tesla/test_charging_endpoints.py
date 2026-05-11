"""Tesla Fleet API charging endpoints tests.

This script tests charging-related endpoints from the Fleet API.

Usage:
    # Run with pytest
    pytest tests/tesla/test_charging_endpoints.py -v

    # Run standalone with real token
    python tests/tesla/test_charging_endpoints.py --token YOUR_ACCESS_TOKEN
"""

import asyncio
import sys
from typing import Optional

import pytest

# Tesla Fleet API integration — needs live OAuth token. Excluded
# from default pytest run; opt in with `pytest -m integration`.
pytestmark = pytest.mark.integration

sys.path.insert(0, "/home/dongxinbo/SourceCode/TePlanner/backend")

from app.integrations.tesla.client import TeslaClient
from app.integrations.tesla.exceptions import TeslaAPIError


class TestChargingEndpoints:
    """Test cases for Tesla charging endpoints."""

    @pytest.mark.asyncio
    async def test_get_charging_history(self, mocker):
        """Test get_charging_history endpoint."""
        mock_response = {
            "response": {
                "data": [
                    {
                        "id": "ch_123",
                        "session_id": "sess_456",
                        "vin": "5YJ3E1EA1KF000001",
                        "site_name": "Shanghai Supercharger",
                        "charge_start_datetime": "2024-01-15T10:00:00Z",
                        "charge_stop_datetime": "2024-01-15T10:45:00Z",
                        "energy_added_kwh": 35.5,
                        "miles_added": 120.0,
                        "charge_cost": 45.50,
                        "currency": "CNY",
                    }
                ],
                "total_count": 1,
                "page": 1,
                "per_page": 20,
            }
        }

        client = TeslaClient("mock_token")
        mocker.patch.object(client, "_request", return_value=mock_response)

        result = await client.get_charging_history()

        assert "response" in result
        assert len(result["response"]["data"]) == 1
        assert result["response"]["data"][0]["energy_added_kwh"] == 35.5

        await client.close()

    @pytest.mark.asyncio
    async def test_get_charging_history_pagination(self, mocker):
        """Test get_charging_history with pagination."""
        mock_response = {
            "response": {
                "data": [],
                "total_count": 100,
                "page": 2,
                "per_page": 10,
            }
        }

        client = TeslaClient("mock_token")
        mock_request = mocker.patch.object(
            client, "_request", return_value=mock_response
        )

        result = await client.get_charging_history(page=2, per_page=10)

        # Verify pagination params were passed
        mock_request.assert_called_once()
        call_args = mock_request.call_args
        assert call_args.kwargs["params"]["page"] == 2
        assert call_args.kwargs["params"]["per_page"] == 10

        await client.close()

    @pytest.mark.asyncio
    async def test_get_charging_invoice(self, mocker):
        """Test get_charging_invoice endpoint."""
        mock_response = {
            "response": {
                "id": "inv_123",
                "session_id": "sess_456",
                "invoice_date": "2024-01-15",
                "amount": 45.50,
                "currency": "CNY",
                "status": "paid",
                "download_url": "https://tesla.com/invoice/123.pdf",
                "details": {
                    "energy_kwh": 35.5,
                    "duration_minutes": 45,
                    "location": "Shanghai Supercharger",
                    "rate_per_kwh": 1.28,
                },
            }
        }

        client = TeslaClient("mock_token")
        mocker.patch.object(client, "_request", return_value=mock_response)

        result = await client.get_charging_invoice("inv_123")

        assert result["response"]["id"] == "inv_123"
        assert result["response"]["amount"] == 45.50
        assert result["response"]["details"]["energy_kwh"] == 35.5

        await client.close()

    @pytest.mark.asyncio
    async def test_get_charging_sessions(self, mocker):
        """Test get_charging_sessions endpoint."""
        mock_response = {
            "response": {
                "data": [
                    {
                        "session_id": "sess_123",
                        "vin": "5YJ3E1EA1KF000001",
                        "start_time": "2024-01-15T10:00:00Z",
                        "end_time": "2024-01-15T10:45:00Z",
                        "energy_kwh": 35.5,
                        "peak_power_kw": 150,
                        "average_power_kw": 47.3,
                        "location": {
                            "name": "Shanghai Supercharger",
                            "latitude": 31.2304,
                            "longitude": 121.4737,
                        },
                    }
                ]
            }
        }

        client = TeslaClient("mock_token")
        mocker.patch.object(client, "_request", return_value=mock_response)

        result = await client.get_charging_sessions()

        assert len(result["response"]["data"]) == 1
        assert result["response"]["data"][0]["peak_power_kw"] == 150

        await client.close()

    @pytest.mark.asyncio
    async def test_get_charging_sessions_by_vin(self, mocker):
        """Test get_charging_sessions filtered by VIN."""
        mock_response = {"response": {"data": []}}

        client = TeslaClient("mock_token")
        mock_request = mocker.patch.object(
            client, "_request", return_value=mock_response
        )

        await client.get_charging_sessions(vin="5YJ3E1EA1KF000001")

        # Verify VIN param was passed
        call_args = mock_request.call_args
        assert call_args.kwargs["params"]["vin"] == "5YJ3E1EA1KF000001"

        await client.close()

    @pytest.mark.asyncio
    async def test_get_nearby_charging_sites_detailed(self, mocker):
        """Test get_nearby_charging_sites with detailed response."""
        mock_response = {
            "response": {
                "congestion_sync_time_utc_secs": 1705320000,
                "superchargers": [
                    {
                        "location": {"lat": 31.2304, "long": 121.4737},
                        "name": "Shanghai - Lujiazui",
                        "type": "supercharger",
                        "distance_miles": 2.5,
                        "available_stalls": 8,
                        "total_stalls": 12,
                        "site_closed": False,
                        "amenities": ["restrooms", "wifi", "food"],
                    },
                    {
                        "location": {"lat": 31.2000, "long": 121.4500},
                        "name": "Shanghai - Jing'an",
                        "type": "supercharger",
                        "distance_miles": 5.1,
                        "available_stalls": 2,
                        "total_stalls": 8,
                        "site_closed": False,
                    },
                ],
                "destination_charging": [
                    {
                        "location": {"lat": 31.2400, "long": 121.4800},
                        "name": "Grand Hyatt Shanghai",
                        "type": "destination",
                        "distance_miles": 1.2,
                    }
                ],
            }
        }

        client = TeslaClient("mock_token")
        mocker.patch.object(client, "_request", return_value=mock_response)

        result = await client.get_nearby_charging_sites("12345", count=20, radius=100)

        response = result["response"]
        assert len(response["superchargers"]) == 2
        assert response["superchargers"][0]["available_stalls"] == 8
        assert len(response["destination_charging"]) == 1

        await client.close()


# ==================== Integration Tests (Real API) ====================


async def run_integration_tests(access_token: str, vehicle_id: Optional[str] = None):
    """Run integration tests against real Tesla API.

    Args:
        access_token: Valid OAuth access token
        vehicle_id: Optional specific vehicle ID to test
    """
    print("=" * 60)
    print("Tesla Fleet API - Charging Endpoints Integration Tests")
    print("=" * 60)

    async with TeslaClient(access_token) as client:
        # Get vehicle first
        print("\n[SETUP] Getting vehicle list...")
        try:
            result = await client.list_vehicles()
            vehicles = result.get("response", [])

            if not vehicles:
                print("No vehicles found.")
                return

            test_vehicle = vehicle_id or vehicles[0].get("id")
            test_vin = vehicles[0].get("vin")
            print(f"Using vehicle: {vehicles[0].get('display_name')}")
            print(f"VIN: {test_vin}")

        except TeslaAPIError as e:
            print(f"FAILED: {e}")
            return

        # Test 1: Get charging history
        print("\n[TEST 1] Get Charging History")
        print("-" * 40)
        try:
            result = await client.get_charging_history(page=1, per_page=5)
            response = result.get("response", {})

            sessions = response.get("data", [])
            print(f"Total sessions: {response.get('total_count', 'N/A')}")
            print(f"Showing first {len(sessions)} sessions:")

            for session in sessions[:3]:
                print(f"\n  Session: {session.get('session_id', 'N/A')}")
                print(f"  Location: {session.get('site_name', 'N/A')}")
                print(f"  Energy: {session.get('energy_added_kwh', 'N/A')} kWh")
                print(f"  Cost: {session.get('charge_cost', 'N/A')} {session.get('currency', '')}")

        except TeslaAPIError as e:
            print(f"FAILED: {e}")
            if e.status_code == 403:
                print("Note: This endpoint may require fleet account access")

        # Test 2: Get nearby charging sites
        print("\n[TEST 2] Get Nearby Charging Sites")
        print("-" * 40)
        try:
            # First wake up vehicle
            await client.ensure_vehicle_online(test_vehicle)

            result = await client.get_nearby_charging_sites(test_vehicle)
            response = result.get("response", {})

            superchargers = response.get("superchargers", [])
            print(f"Superchargers nearby: {len(superchargers)}")

            for sc in superchargers[:5]:
                print(f"\n  {sc.get('name')}")
                print(f"  Distance: {sc.get('distance_miles', 'N/A')} miles")
                print(f"  Available: {sc.get('available_stalls', 'N/A')}/{sc.get('total_stalls', 'N/A')} stalls")

            dest = response.get("destination_charging", [])
            print(f"\nDestination chargers: {len(dest)}")
            for dc in dest[:3]:
                print(f"  - {dc.get('name')}")

        except TeslaAPIError as e:
            print(f"FAILED: {e}")

        # Test 3: Get charging sessions (fleet only)
        print("\n[TEST 3] Get Charging Sessions")
        print("-" * 40)
        try:
            result = await client.get_charging_sessions(vin=test_vin)
            response = result.get("response", {})

            sessions = response.get("data", [])
            print(f"Sessions found: {len(sessions)}")

            for session in sessions[:3]:
                print(f"\n  Session: {session.get('session_id')}")
                print(f"  Energy: {session.get('energy_kwh')} kWh")
                print(f"  Peak Power: {session.get('peak_power_kw')} kW")

        except TeslaAPIError as e:
            print(f"FAILED: {e}")
            if e.status_code == 403:
                print("Note: This endpoint may require fleet account access")

        # Test 4: Get current charge state
        print("\n[TEST 4] Get Current Charge State")
        print("-" * 40)
        try:
            result = await client.get_charge_state(test_vehicle)

            print(f"Battery Level: {result.get('battery_level')}%")
            print(f"Usable Battery: {result.get('usable_battery_level')}%")
            print(f"Battery Range: {result.get('battery_range')} miles")
            print(f"Est Range: {result.get('est_battery_range')} miles")
            print(f"Ideal Range: {result.get('ideal_battery_range')} miles")
            print(f"Charging State: {result.get('charging_state')}")
            print(f"Charge Limit: {result.get('charge_limit_soc')}%")
            print(f"Charge Port: {result.get('charge_port_door_open')}")

            if result.get("charging_state") == "Charging":
                print(f"\n  Charge Rate: {result.get('charge_rate')} mph")
                print(f"  Charger Power: {result.get('charger_power')} kW")
                print(f"  Time to Full: {result.get('time_to_full_charge')} hours")
                print(f"  Charger Voltage: {result.get('charger_voltage')} V")
                print(f"  Charger Current: {result.get('charger_actual_current')} A")

        except TeslaAPIError as e:
            print(f"FAILED: {e}")

    print("\n" + "=" * 60)
    print("Charging Tests Complete")
    print("=" * 60)


def main():
    """Main entry point for standalone execution."""
    import argparse

    parser = argparse.ArgumentParser(description="Test Tesla Fleet API charging endpoints")
    parser.add_argument("--token", required=True, help="OAuth access token")
    parser.add_argument("--vehicle", help="Specific vehicle ID to test")

    args = parser.parse_args()

    asyncio.run(run_integration_tests(args.token, args.vehicle))


if __name__ == "__main__":
    main()
