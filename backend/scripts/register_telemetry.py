#!/usr/bin/env python
"""Register Fleet Telemetry config for the user's vehicle(s).

Pushes a config to Tesla's partner endpoint that tells the vehicle:
  - which server (fleet.teplanner.cloud:8443) to push state changes to
  - which CA cert chain to trust for that server
  - which fields to emit + minimum interval per field

Tesla then forwards the config to the named VINs over their existing
data link. The vehicle establishes an mTLS WebSocket to our server
and starts streaming state changes.

Run from backend/:
    python scripts/register_telemetry.py --vin LRWXP2EK1MC123456

Reads partner credentials and CA cert path from .env / args.
"""

import argparse
import asyncio
import os
import sys
import time
from pathlib import Path

import httpx
from dotenv import load_dotenv

load_dotenv()


FLEET_API_BASE = os.getenv(
    "TESLA_FLEET_API_BASE_URL", "https://fleet-api.prd.cn.vn.cloud.tesla.cn"
)
DEFAULT_HOSTNAME = "fleet.teplanner.cloud"
DEFAULT_PORT = 8443
# Path on the production VM where the LE intermediate + ISRG root
# bundle lives. Vehicle uses this to verify our server.
DEFAULT_CA_PATH = "/tmp/le-bundle.pem"


# Fields the vehicle should emit + minimum interval (seconds)
# between consecutive emits per field. Tuned for our automation
# triggers — anything that drives a preset:
DEFAULT_FIELDS = {
    "ClimateKeeperMode": {"interval_seconds": 30},
    "SentryMode": {"interval_seconds": 60},
    "CabinOverheatProtectionMode": {"interval_seconds": 60},
    "ChargeState": {"interval_seconds": 60},
    "BatteryLevel": {"interval_seconds": 300},
    "Soc": {"interval_seconds": 300},
    "Locked": {"interval_seconds": 30},
    "Gear": {"interval_seconds": 10},
    "DoorState": {"interval_seconds": 10},
    "FrontTrunkOpen": {"interval_seconds": 30},
    "RearTrunkOpen": {"interval_seconds": 30},
    "WindowsOpen": {"interval_seconds": 30},
}


async def get_partner_token() -> str:
    client_id = os.getenv("TESLA_CLIENT_ID")
    client_secret = os.getenv("TESLA_CLIENT_SECRET")
    if not client_id or not client_secret:
        print("ERROR: TESLA_CLIENT_ID / TESLA_CLIENT_SECRET required")
        sys.exit(1)
    async with httpx.AsyncClient() as client:
        r = await client.post(
            "https://auth.tesla.cn/oauth2/v3/token",
            data={
                "grant_type": "client_credentials",
                "client_id": client_id,
                "client_secret": client_secret,
                "scope": "openid vehicle_device_data vehicle_cmds",
                "audience": FLEET_API_BASE,
            },
        )
        if r.status_code != 200:
            print(f"ERROR: token fetch failed {r.status_code}: {r.text}")
            sys.exit(1)
        return r.json()["access_token"]


async def register_config(
    token: str,
    vins: list[str],
    hostname: str,
    port: int,
    ca_pem: str,
    exp_seconds: int,
) -> dict:
    """POST /api/1/vehicles/fleet_telemetry_config — partner-level
    bulk config delivery. Tesla pushes to each VIN in the list."""
    body = {
        "config": {
            "hostname": hostname,
            "port": port,
            "ca": ca_pem,
            "fields": DEFAULT_FIELDS,
            "exp": int(time.time()) + exp_seconds,
        },
        "vins": vins,
    }
    async with httpx.AsyncClient(timeout=30) as client:
        r = await client.post(
            f"{FLEET_API_BASE}/api/1/vehicles/fleet_telemetry_config",
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
            },
            json=body,
        )
        print(f"status: {r.status_code}")
        print(f"response: {r.text[:1000]}")
        if r.status_code == 200:
            return r.json()
        return {"error": r.text}


async def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--vin", action="append", required=True,
        help="VIN to register. Repeat for multiple cars.",
    )
    parser.add_argument(
        "--hostname", default=DEFAULT_HOSTNAME,
        help="Telemetry server hostname (default fleet.teplanner.cloud)",
    )
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument(
        "--ca-file", default=DEFAULT_CA_PATH,
        help="Path to CA cert bundle (intermediate + root) the vehicle "
             "should trust. Defaults to the Let's Encrypt bundle "
             "we built in phase-3.",
    )
    parser.add_argument(
        "--days", type=int, default=30,
        help="Config expiration window (default 30 days). Renew before this elapses.",
    )
    args = parser.parse_args()

    ca_path = Path(args.ca_file)
    if not ca_path.is_file():
        print(f"ERROR: CA file not found: {ca_path}")
        sys.exit(1)
    ca_pem = ca_path.read_text()

    print("=" * 60)
    print("Fleet Telemetry Config Registration")
    print("=" * 60)
    print(f"VINs:     {args.vin}")
    print(f"Server:   {args.hostname}:{args.port}")
    print(f"CA file:  {ca_path} ({len(ca_pem)} bytes)")
    print(f"Exp days: {args.days}")
    print()

    print("Getting partner token...")
    token = await get_partner_token()

    print("Registering config...")
    result = await register_config(
        token=token,
        vins=args.vin,
        hostname=args.hostname,
        port=args.port,
        ca_pem=ca_pem,
        exp_seconds=args.days * 86400,
    )

    print()
    print("=" * 60)
    if "error" in result:
        print("FAILED")
        sys.exit(1)
    print("OK")
    return result


if __name__ == "__main__":
    asyncio.run(main())
