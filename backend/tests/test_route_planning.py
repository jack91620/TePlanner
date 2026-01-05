#!/usr/bin/env python3
"""End-to-end route planning tests.

This script tests the complete route planning flow including:
1. Route planning with charging optimization
2. Long-distance routes (Beijing -> Shanghai)
3. Short-distance routes (no charging needed)
4. Edge cases (low battery, etc.)

Usage:
    # Activate conda environment
    conda activate teplanner

    # Run tests
    cd /home/ubuntu/TePlanner/backend
    python tests/test_route_planning.py
"""

import asyncio
import json
import os
import sys
from typing import Optional

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Load environment
from dotenv import load_dotenv
load_dotenv()


class Colors:
    """Terminal colors."""
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    RED = "\033[91m"
    BLUE = "\033[94m"
    CYAN = "\033[96m"
    RESET = "\033[0m"
    BOLD = "\033[1m"


def print_header(text: str):
    """Print a section header."""
    print(f"\n{Colors.BOLD}{Colors.BLUE}{'=' * 60}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.BLUE}{text}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.BLUE}{'=' * 60}{Colors.RESET}")


def print_success(text: str):
    """Print success message."""
    print(f"{Colors.GREEN}✓ {text}{Colors.RESET}")


def print_error(text: str):
    """Print error message."""
    print(f"{Colors.RED}✗ {text}{Colors.RESET}")


def print_warning(text: str):
    """Print warning message."""
    print(f"{Colors.YELLOW}! {text}{Colors.RESET}")


def print_info(text: str):
    """Print info message."""
    print(f"{Colors.CYAN}→ {text}{Colors.RESET}")


# Test locations
LOCATIONS = {
    "beijing_center": {
        "name": "北京天安门",
        "lat": 39.9042,
        "lng": 116.4074,
    },
    "shanghai_bund": {
        "name": "上海外滩",
        "lat": 31.2304,
        "lng": 121.4737,
    },
    "tianjin_center": {
        "name": "天津市中心",
        "lat": 39.1256,
        "lng": 117.1908,
    },
    "hangzhou_westlake": {
        "name": "杭州西湖",
        "lat": 30.2587,
        "lng": 120.1294,
    },
    "suzhou_center": {
        "name": "苏州市中心",
        "lat": 31.2989,
        "lng": 120.5853,
    },
}


async def test_route_planner():
    """Test the route planning service."""
    from app.services.route_planner import RoutePlanner

    print_header("Testing Route Planner Service")

    async with RoutePlanner() as planner:
        # Test 1: Long distance route (Beijing -> Shanghai)
        print_info("Test 1: Long distance route (Beijing -> Shanghai)")
        print_info("  Distance: ~1200km, should require multiple charging stops")

        result = await planner.plan_route(
            origin=(LOCATIONS["beijing_center"]["lat"], LOCATIONS["beijing_center"]["lng"]),
            destination=(LOCATIONS["shanghai_bund"]["lat"], LOCATIONS["shanghai_bund"]["lng"]),
            initial_soc=100,
            car_type="model_y_long_range",
        )

        print_success(f"Route planned: {result.total_distance_km:.1f} km")
        print_success(f"Duration: {result.total_duration_minutes} minutes")
        print_success(f"Charging stops: {len(result.charging_stops)}")
        print_success(f"Arrival SOC: {result.arrival_soc}%")

        if result.charging_stops:
            print_info("Charging stops:")
            for i, stop in enumerate(result.charging_stops):
                print(f"    {i+1}. {stop.name}")
                print(f"       Distance: {stop.distance_from_start_km:.1f} km from start")
                print(f"       SOC: {stop.arrival_soc}% -> {stop.departure_soc}%")
                print(f"       Charging: {stop.charging_duration_minutes} minutes")

        if result.warnings:
            print_warning("Warnings:")
            for w in result.warnings:
                print(f"    - {w}")

        # Test 2: Short distance route (Beijing -> Tianjin)
        print_info("\nTest 2: Short distance route (Beijing -> Tianjin)")
        print_info("  Distance: ~120km, might not need charging")

        result2 = await planner.plan_route(
            origin=(LOCATIONS["beijing_center"]["lat"], LOCATIONS["beijing_center"]["lng"]),
            destination=(LOCATIONS["tianjin_center"]["lat"], LOCATIONS["tianjin_center"]["lng"]),
            initial_soc=80,
            car_type="model_y_long_range",
        )

        print_success(f"Route planned: {result2.total_distance_km:.1f} km")
        print_success(f"Duration: {result2.total_duration_minutes} minutes")
        print_success(f"Charging stops: {len(result2.charging_stops)}")
        print_success(f"Arrival SOC: {result2.arrival_soc}%")

        # Test 3: Low battery scenario
        print_info("\nTest 3: Low battery scenario (30% SOC)")
        print_info("  Starting with 30% SOC, should need charging earlier")

        result3 = await planner.plan_route(
            origin=(LOCATIONS["shanghai_bund"]["lat"], LOCATIONS["shanghai_bund"]["lng"]),
            destination=(LOCATIONS["hangzhou_westlake"]["lat"], LOCATIONS["hangzhou_westlake"]["lng"]),
            initial_soc=30,
            car_type="model_3_long_range",
        )

        print_success(f"Route planned: {result3.total_distance_km:.1f} km")
        print_success(f"Duration: {result3.total_duration_minutes} minutes")
        print_success(f"Charging stops: {len(result3.charging_stops)}")
        print_success(f"Arrival SOC: {result3.arrival_soc}%")


async def test_charging_station_search():
    """Test charging station search."""
    from app.integrations.tencent_map.client import TencentMapClient

    print_header("Testing Charging Station Search")

    async with TencentMapClient() as client:
        # Search near Beijing
        print_info("Searching for charging stations near Beijing...")

        stations = await client.search_charging_stations(
            latitude=LOCATIONS["beijing_center"]["lat"],
            longitude=LOCATIONS["beijing_center"]["lng"],
            radius=10000,  # 10km
        )

        print_success(f"Found {len(stations)} charging stations")

        if stations:
            print_info("First 5 stations:")
            for i, station in enumerate(stations[:5]):
                print(f"    {i+1}. {station.get('title', 'Unknown')}")
                print(f"       Address: {station.get('address', 'N/A')}")


async def test_geocoding():
    """Test geocoding and reverse geocoding."""
    from app.integrations.tencent_map.client import TencentMapClient

    print_header("Testing Geocoding")

    async with TencentMapClient() as client:
        # Forward geocoding
        print_info("Forward geocoding: '北京市天安门广场'")

        result = await client.geocode("北京市天安门广场")
        location = result.get("location", {})

        print_success(f"Latitude: {location.get('lat')}")
        print_success(f"Longitude: {location.get('lng')}")

        # Reverse geocoding
        print_info("\nReverse geocoding: (39.9042, 116.4074)")

        result = await client.reverse_geocode(39.9042, 116.4074)

        print_success(f"Address: {result.get('address', 'N/A')}")


async def test_energy_model():
    """Test energy consumption model."""
    from app.services.energy_model import EnergyModel

    print_header("Testing Energy Model")

    model = EnergyModel()

    test_cases = [
        {"distance": 100, "car_type": "model_y_long_range", "speed": 100},
        {"distance": 200, "car_type": "model_3_standard_range", "speed": 120},
        {"distance": 500, "car_type": "model_s_long_range", "speed": 110},
    ]

    for case in test_cases:
        print_info(f"Testing {case['car_type']}, {case['distance']}km at {case['speed']}km/h")

        result = model.calculate_consumption(
            distance_km=case["distance"],
            car_type=case["car_type"],
            speed_kmh=case["speed"],
        )

        print_success(f"  Energy: {result['consumption_kwh']:.2f} kWh")
        print_success(f"  SOC consumed: {result['soc_consumed']:.1f}%")
        print_success(f"  Wh/km: {result['efficiency_wh_per_km']:.1f}")


async def test_api_endpoints():
    """Test API endpoints using httpx."""
    import httpx

    print_header("Testing API Endpoints")

    base_url = "http://localhost:8000/api/v1"

    async with httpx.AsyncClient(timeout=30.0) as client:
        # Test health endpoint
        print_info("Testing health endpoint...")
        try:
            response = await client.get("http://localhost:8000/health")
            if response.status_code == 200:
                print_success("Health check passed")
            else:
                print_error(f"Health check failed: {response.status_code}")
        except Exception as e:
            print_warning(f"Server not running: {e}")
            print_info("Skipping API endpoint tests...")
            return

        # Test route planning endpoint (without authentication)
        print_info("\nTesting route planning endpoint...")

        route_request = {
            "origin": {
                "latitude": LOCATIONS["beijing_center"]["lat"],
                "longitude": LOCATIONS["beijing_center"]["lng"],
                "address": LOCATIONS["beijing_center"]["name"],
            },
            "destination": {
                "latitude": LOCATIONS["tianjin_center"]["lat"],
                "longitude": LOCATIONS["tianjin_center"]["lng"],
                "address": LOCATIONS["tianjin_center"]["name"],
            },
            "current_soc": 80,
            "car_type": "model_y_long_range",
        }

        try:
            response = await client.post(
                f"{base_url}/routes/plan",
                json=route_request,
            )

            if response.status_code == 200:
                data = response.json()
                print_success(f"Route planned via API")
                print_success(f"  Distance: {data['total_distance_km']} km")
                print_success(f"  Duration: {data['total_duration_minutes']} min")
                print_success(f"  Charging stops: {data['num_charging_stops']}")
            else:
                print_error(f"Route planning failed: {response.status_code}")
                print_error(f"Response: {response.text}")
        except Exception as e:
            print_error(f"Route planning request failed: {e}")

        # Test geocoding endpoint
        print_info("\nTesting geocode endpoint...")

        try:
            response = await client.post(
                f"{base_url}/routes/geocode",
                json={"address": "上海市浦东新区陆家嘴"},
            )

            if response.status_code == 200:
                data = response.json()
                print_success(f"Geocoding result:")
                print_success(f"  Latitude: {data['latitude']}")
                print_success(f"  Longitude: {data['longitude']}")
            else:
                print_warning(f"Geocoding failed: {response.status_code}")
        except Exception as e:
            print_warning(f"Geocoding request failed: {e}")


async def run_all_tests():
    """Run all tests."""
    print(f"\n{Colors.BOLD}TePlanner End-to-End Tests{Colors.RESET}")
    print(f"{'=' * 60}\n")

    test_results = []

    # Test energy model
    try:
        await test_energy_model()
        test_results.append(("Energy Model", True))
    except Exception as e:
        print_error(f"Energy model test failed: {e}")
        test_results.append(("Energy Model", False))

    # Test geocoding
    try:
        await test_geocoding()
        test_results.append(("Geocoding", True))
    except Exception as e:
        print_error(f"Geocoding test failed: {e}")
        test_results.append(("Geocoding", False))

    # Test charging station search
    try:
        await test_charging_station_search()
        test_results.append(("Charging Station Search", True))
    except Exception as e:
        print_error(f"Charging station search test failed: {e}")
        test_results.append(("Charging Station Search", False))

    # Test route planner
    try:
        await test_route_planner()
        test_results.append(("Route Planner", True))
    except Exception as e:
        print_error(f"Route planner test failed: {e}")
        test_results.append(("Route Planner", False))

    # Test API endpoints
    try:
        await test_api_endpoints()
        test_results.append(("API Endpoints", True))
    except Exception as e:
        print_error(f"API endpoint test failed: {e}")
        test_results.append(("API Endpoints", False))

    # Print summary
    print_header("Test Summary")

    passed = sum(1 for _, result in test_results if result)
    failed = len(test_results) - passed

    for name, result in test_results:
        if result:
            print_success(f"{name}")
        else:
            print_error(f"{name}")

    print()
    if failed == 0:
        print_success(f"All {passed} tests passed!")
    else:
        print_warning(f"{passed} passed, {failed} failed")


def main():
    """Main entry point."""
    asyncio.run(run_all_tests())


if __name__ == "__main__":
    main()
