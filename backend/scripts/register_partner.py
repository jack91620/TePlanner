#!/usr/bin/env python
"""Register Tesla Fleet API Partner Account.

This script registers the application as a partner in the Tesla Fleet API.
Required before making API calls.

Usage:
    python scripts/register_partner.py
"""

import asyncio
import os
import sys
from pathlib import Path

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent.parent))

import httpx
from dotenv import load_dotenv

load_dotenv()


async def get_partner_token() -> str:
    """Get partner token using client credentials flow."""
    client_id = os.getenv("TESLA_CLIENT_ID")
    client_secret = os.getenv("TESLA_CLIENT_SECRET")

    if not client_id or not client_secret:
        print("ERROR: TESLA_CLIENT_ID and TESLA_CLIENT_SECRET required in .env")
        sys.exit(1)

    print("Getting partner token via client credentials...")

    async with httpx.AsyncClient() as client:
        response = await client.post(
            "https://auth.tesla.cn/oauth2/v3/token",
            data={
                "grant_type": "client_credentials",
                "client_id": client_id,
                "client_secret": client_secret,
                "scope": "openid vehicle_device_data vehicle_cmds vehicle_charging_cmds",
                "audience": "https://fleet-api.prd.cn.vn.cloud.tesla.cn",
            },
        )

        if response.status_code != 200:
            print(f"ERROR: Failed to get partner token: {response.status_code}")
            print(response.text)
            sys.exit(1)

        data = response.json()
        print(f"Partner token obtained (expires in {data.get('expires_in')} seconds)")
        return data["access_token"]


async def register_partner(token: str, domain: str) -> dict:
    """Register partner account in the region."""
    fleet_api_url = os.getenv(
        "TESLA_FLEET_API_BASE_URL", "https://fleet-api.prd.cn.vn.cloud.tesla.cn"
    )

    print(f"\nRegistering partner account at {fleet_api_url} for domain={domain}...")

    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{fleet_api_url}/api/1/partner_accounts",
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
            },
            json={
                "domain": domain,
            },
        )

        print(f"Response status: {response.status_code}")
        print(f"Response: {response.text}")

        if response.status_code == 200:
            print("\nPartner account registered successfully!")
            return response.json()
        elif response.status_code == 409:
            print("\nPartner account already registered.")
            return {"status": "already_registered"}
        else:
            print(f"\nERROR: Registration failed")
            return {"error": response.text}


async def register_partner_public_key(token: str, domain: str) -> dict:
    """Phase 7 (VCP): register the partner ECDH public key. Tesla pulls
    the actual key bytes from
    https://{domain}/.well-known/appspecific/com.tesla.3p.public-key.pem
    so the body just identifies the domain.
    """
    fleet_api_url = os.getenv(
        "TESLA_FLEET_API_BASE_URL", "https://fleet-api.prd.cn.vn.cloud.tesla.cn"
    )

    print(f"\nRegistering partner public key for domain={domain}...")

    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{fleet_api_url}/api/1/partner_accounts/public_key",
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
            },
            json={"domain": domain},
        )

        print(f"Response status: {response.status_code}")
        print(f"Response: {response.text}")

        if response.status_code == 200:
            print("\nPartner public key registered successfully!")
            return response.json()
        elif response.status_code == 409:
            print("\nPartner public key already registered.")
            return {"status": "already_registered"}
        else:
            print(f"\nERROR: Public key registration failed")
            return {"error": response.text}


async def main():
    print("=" * 60)
    print("Tesla Fleet API Partner Registration")
    print("=" * 60)

    domain = os.getenv("TESLA_PARTNER_DOMAIN", "api.teplanner.cloud")

    # Step 1: Get partner token
    partner_token = await get_partner_token()

    # Step 2: Register partner account (idempotent)
    await register_partner(partner_token, domain)

    # Step 3: Register VCP partner public key (needed for vehicle commands)
    result = await register_partner_public_key(partner_token, domain)

    print("\n" + "=" * 60)
    print("Done!")
    print("=" * 60)

    return result


if __name__ == "__main__":
    asyncio.run(main())
