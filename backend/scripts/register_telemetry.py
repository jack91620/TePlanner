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
# fleet_telemetry_config requires VCP-signed delivery — Tesla rejects
# direct Fleet API calls. Route through tesla-http-proxy which holds
# our partner private key and signs the request before forwarding.
VCP_PROXY_URL = os.getenv(
    "TESLA_VEHICLE_COMMAND_PROXY_URL", "https://127.0.0.1:4443"
)
DEFAULT_HOSTNAME = "fleet.teplanner.cloud"
DEFAULT_PORT = 8443
# Path on the production VM where the LE intermediate + ISRG root
# bundle lives. Vehicle uses this to verify our server.
DEFAULT_CA_PATH = "/tmp/le-bundle.pem"


# Fields the vehicle should emit + minimum interval (seconds)
# between consecutive emits per field. Names must match
# fleet-telemetry/protos/vehicle_data.proto Field enum exactly.
# Trunk/frunk are inside the DoorState struct — one subscription
# covers doors + both trunks. Windows are 4 separate top-level
# fields (Fd/Fp/Rd/Rp).
DEFAULT_FIELDS = {
    "ClimateKeeperMode":            {"interval_seconds": 30},
    "SentryMode":                   {"interval_seconds": 60},
    "CabinOverheatProtectionMode":  {"interval_seconds": 60},
    "ChargeState":                  {"interval_seconds": 60},
    "BatteryLevel":                 {"interval_seconds": 300},
    "Soc":                          {"interval_seconds": 300},
    "Locked":                       {"interval_seconds": 30},
    "Gear":                         {"interval_seconds": 10},
    "DoorState":                    {"interval_seconds": 10},
    "FdWindow":                     {"interval_seconds": 30},
    "FpWindow":                     {"interval_seconds": 30},
    "RdWindow":                     {"interval_seconds": 30},
    "RpWindow":                     {"interval_seconds": 30},
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


async def get_user_access_token_for_vin(vin: str) -> str | None:
    """Look up the latest user-OAuth access token for the user that
    owns `vin`. Refreshes if expired. fleet_telemetry_config rejects
    partner (M2M) tokens with VIN not_found — needs user authorization-
    code token because the vehicle binding lives at the user level.
    """
    sys.path.insert(0, str(Path(__file__).parent.parent))
    from datetime import datetime, timedelta
    from app.core.security import TokenEncryption
    from app.db.models import TeslaToken, Vehicle
    from app.db.session import async_session
    from app.integrations.tesla import TeslaAuth
    from sqlalchemy import select

    async with async_session() as db:
        veh_q = select(Vehicle).where(Vehicle.vin == vin).limit(1)
        veh = (await db.execute(veh_q)).scalar_one_or_none()
        if not veh:
            return None
        tok_q = (
            select(TeslaToken)
            .where(TeslaToken.user_id == veh.user_id)
            .order_by(TeslaToken.updated_at.desc())
            .limit(1)
        )
        tok = (await db.execute(tok_q)).scalar_one_or_none()
        if not tok:
            return None

        encryption = TokenEncryption()
        if tok.expires_at is None or tok.expires_at < datetime.utcnow():
            try:
                refresh_plain = encryption.decrypt(tok.refresh_token)
            except Exception:
                refresh_plain = tok.refresh_token
            new_tokens = await TeslaAuth().refresh_token(refresh_plain)
            tok.access_token = encryption.encrypt(new_tokens["access_token"])
            tok.refresh_token = encryption.encrypt(new_tokens["refresh_token"])
            tok.expires_at = datetime.utcnow() + timedelta(
                seconds=new_tokens.get("expires_in", 3600)
            )
            await db.commit()
            return new_tokens["access_token"]
        try:
            return encryption.decrypt(tok.access_token)
        except Exception:
            return tok.access_token


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
    # Route via VCP proxy: it signs the request with our partner private
    # key and forwards to Tesla. verify=False because proxy uses a
    # self-signed cert on 127.0.0.1.
    async with httpx.AsyncClient(timeout=30, verify=False) as client:
        r = await client.post(
            f"{VCP_PROXY_URL}/api/1/vehicles/fleet_telemetry_config",
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
            },
            json=body,
        )
        print(f"status: {r.status_code}")
        print(f"response: {r.text[:1500]}")
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

    # Try the user-level access token first (required for fleet_telemetry_config).
    # Falls back to partner token if no user token is on file.
    print("Looking up user access token for first VIN...")
    token = await get_user_access_token_for_vin(args.vin[0])
    if token:
        print("  using user OAuth access token")
    else:
        print("  no user token found — falling back to partner token")
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
