#!/usr/bin/env python
"""Tesla Fleet API test runner.

This script provides a unified interface to run all Tesla API tests.
Reads TESLA_ACCESS_TOKEN from .env file by default.

Usage:
    # Run integration tests (reads token from .env)
    python tests/tesla/run_tests.py

    # Run with explicit token
    python tests/tesla/run_tests.py --token YOUR_ACCESS_TOKEN

    # Run specific test category
    python tests/tesla/run_tests.py --category vehicles
    python tests/tesla/run_tests.py --category commands
    python tests/tesla/run_tests.py --category charging

    # Run unit tests only (mocked, no real API calls)
    python tests/tesla/run_tests.py --unit

    # Run safe mode (skip potentially disruptive commands)
    python tests/tesla/run_tests.py --safe

Examples:
    # Full integration test (default)
    python tests/tesla/run_tests.py

    # Test only vehicle info endpoints
    python tests/tesla/run_tests.py --category vehicles

    # Test only charging endpoints
    python tests/tesla/run_tests.py --category charging
"""

import argparse
import asyncio
import os
import subprocess
import sys
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

# Load .env file
from dotenv import load_dotenv

load_dotenv(project_root / ".env")

from tests.tesla.test_vehicle_endpoints import run_integration_tests as run_vehicle_tests
from tests.tesla.test_vehicle_commands import run_integration_tests as run_command_tests
from tests.tesla.test_charging_endpoints import run_integration_tests as run_charging_tests


def get_token_from_env() -> str:
    """Get Tesla access token from environment."""
    token = os.getenv("TESLA_ACCESS_TOKEN", "")
    if not token:
        print("ERROR: TESLA_ACCESS_TOKEN not found in .env file")
        print("Please complete OAuth authorization first and add token to .env")
        print("\nTo get a token:")
        print("  1. Start the backend server: uvicorn app.main:app --reload")
        print("  2. Visit: http://localhost:8000/api/v1/auth/tesla/authorize")
        print("  3. Complete Tesla login and copy the access_token")
        print("  4. Add to .env: TESLA_ACCESS_TOKEN=your_token_here")
        sys.exit(1)
    return token


def run_unit_tests(verbose: bool = True) -> int:
    """Run unit tests with pytest.

    Returns:
        Exit code (0 for success)
    """
    print("=" * 60)
    print("Running Unit Tests (Mocked)")
    print("=" * 60)

    test_dir = Path(__file__).parent
    cmd = [
        sys.executable,
        "-m",
        "pytest",
        str(test_dir),
        "-v" if verbose else "-q",
        "--tb=short",
    ]

    result = subprocess.run(cmd, cwd=str(test_dir.parent.parent))
    return result.returncode


async def run_integration_tests(
    token: str,
    vehicle_id: str | None = None,
    category: str = "all",
    safe_mode: bool = False,
):
    """Run integration tests against real API.

    Args:
        token: OAuth access token
        vehicle_id: Optional specific vehicle ID
        category: Test category (all, vehicles, commands, charging)
        safe_mode: If True, skip potentially disruptive commands
    """
    print("\n" + "=" * 60)
    print("Running Integration Tests (Real API)")
    print("=" * 60)
    print(f"Category: {category}")
    print(f"Safe Mode: {safe_mode}")
    print("=" * 60)

    if category in ("all", "vehicles"):
        print("\n>>> Vehicle Endpoints Tests <<<")
        await run_vehicle_tests(token, vehicle_id)

    if category in ("all", "commands"):
        print("\n>>> Vehicle Commands Tests <<<")
        await run_command_tests(token, vehicle_id, safe_mode)

    if category in ("all", "charging"):
        print("\n>>> Charging Endpoints Tests <<<")
        await run_charging_tests(token, vehicle_id)


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Tesla Fleet API Test Runner",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )

    # Test type selection
    parser.add_argument(
        "--unit",
        action="store_true",
        help="Run unit tests only (mocked, no API calls)",
    )

    # Integration test options
    parser.add_argument(
        "--token",
        help="OAuth access token (default: from .env TESLA_ACCESS_TOKEN)",
    )
    parser.add_argument(
        "--vehicle",
        help="Specific vehicle ID to test",
    )
    parser.add_argument(
        "--category",
        choices=["all", "vehicles", "commands", "charging"],
        default="all",
        help="Test category to run (default: all)",
    )
    parser.add_argument(
        "--safe",
        action="store_true",
        help="Safe mode: skip potentially disruptive commands",
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="Less verbose output",
    )

    args = parser.parse_args()

    # If unit tests only
    if args.unit:
        exit_code = run_unit_tests(verbose=not args.quiet)
        sys.exit(exit_code)

    # Get token from args or env
    token = args.token or get_token_from_env()

    # Run integration tests
    asyncio.run(
        run_integration_tests(
            token=token,
            vehicle_id=args.vehicle,
            category=args.category,
            safe_mode=args.safe,
        )
    )

    print("\n" + "=" * 60)
    print("All tests completed!")
    print("=" * 60)


if __name__ == "__main__":
    main()
