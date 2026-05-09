"""Huawei Push Kit (HarmonyOS NEXT) sender — Phase E.

HMS Push Kit v3 REST API. Two-step flow per documented contract:
  1. POST  https://oauth-login.cloud.huawei.com/oauth2/v3/token
     → app_id + app_secret → access_token (1 hour TTL)
  2. POST  https://push-api.cloud.huawei.com/v3/{appId}/messages:send
     Authorization: Bearer <access_token>
     body: { "message": { "token": [...], "notification": {...} } }

Configuration:
  HUAWEI_PUSH_APP_ID       — AGC project app id (numeric string)
  HUAWEI_PUSH_APP_SECRET   — AGC project secret
  HUAWEI_PUSH_TOKEN_URL    — defaults to oauth-login.cloud.huawei.com
  HUAWEI_PUSH_API_URL      — defaults to push-api.cloud.huawei.com

Caches the OAuth access_token in-memory until expiry; refreshes
lazily on next send. Errors logged + return False (never raise) —
HarmonyOS is the smallest channel today, an outage there can't
take iOS / Android down with it.
"""

from __future__ import annotations

import logging
import time
from typing import Optional

import httpx

from app.config import settings

logger = logging.getLogger(__name__)


class HarmonyPushClient:
    DEFAULT_TOKEN_URL = "https://oauth-login.cloud.huawei.com/oauth2/v3/token"
    DEFAULT_API_BASE = "https://push-api.cloud.huawei.com"

    def __init__(self) -> None:
        self._app_id = getattr(settings, "HUAWEI_PUSH_APP_ID", "") or ""
        self._app_secret = getattr(settings, "HUAWEI_PUSH_APP_SECRET", "") or ""
        self._token_url = (
            getattr(settings, "HUAWEI_PUSH_TOKEN_URL", "") or self.DEFAULT_TOKEN_URL
        )
        self._api_base = (
            getattr(settings, "HUAWEI_PUSH_API_URL", "") or self.DEFAULT_API_BASE
        )
        self._access_token: Optional[str] = None
        self._token_expires_at: float = 0.0
        self._configured = bool(self._app_id and self._app_secret)
        if not self._configured:
            logger.info(
                "Huawei Push not configured (HUAWEI_PUSH_APP_ID / "
                "HUAWEI_PUSH_APP_SECRET missing) — HarmonyOS push sending disabled"
            )

    @property
    def configured(self) -> bool:
        return self._configured

    async def _get_access_token(self) -> Optional[str]:
        if self._access_token and time.time() < self._token_expires_at - 30:
            return self._access_token
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.post(
                    self._token_url,
                    data={
                        "grant_type": "client_credentials",
                        "client_id": self._app_id,
                        "client_secret": self._app_secret,
                    },
                )
            if response.status_code != 200:
                logger.warning(
                    "Huawei OAuth failed: status=%s body=%s",
                    response.status_code,
                    response.text[:200],
                )
                return None
            payload = response.json()
            self._access_token = payload.get("access_token")
            self._token_expires_at = time.time() + int(payload.get("expires_in", 3600))
            return self._access_token
        except Exception as exc:
            logger.exception("Huawei OAuth exception: %s", exc)
            return None

    def _build_payload(
        self,
        provider_token: str,
        title: str,
        body: str,
        custom_data: Optional[dict],
    ) -> dict:
        message: dict = {
            "token": [provider_token],
            "notification": {"title": title, "body": body},
            "android": {
                "notification": {
                    "title": title,
                    "body": body,
                    "click_action": {"type": 3},
                },
            },
        }
        if custom_data:
            # HMS routes data via a JSON-stringified `data` field (top-
            # level); receivers parse it themselves. We pass through.
            import json as _json
            message["data"] = _json.dumps(custom_data, ensure_ascii=False)
        return {"validate_only": False, "message": message}

    async def send(
        self,
        provider_token: str,
        title: str,
        body: str,
        custom_data: Optional[dict] = None,
    ) -> bool:
        if not self._configured:
            logger.debug("Huawei Push skipped (not configured): %s — %s", title, body)
            return False
        if not provider_token:
            logger.warning("Huawei Push skipped: empty provider_token for title=%s", title)
            return False

        access_token = await self._get_access_token()
        if not access_token:
            return False

        url = f"{self._api_base}/v3/{self._app_id}/messages:send"
        payload = self._build_payload(provider_token, title, body, custom_data)
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.post(
                    url,
                    headers={
                        "Authorization": f"Bearer {access_token}",
                        "Content-Type": "application/json;charset=utf-8",
                    },
                    json=payload,
                )
            if response.status_code == 200:
                code = response.json().get("code") if response.content else "?"
                if code == "80000000":
                    logger.info(
                        "Huawei Push sent: token=%s… title=%s msg_id=%s",
                        provider_token[:8],
                        title,
                        response.json().get("requestId", "?"),
                    )
                    return True
                logger.warning(
                    "Huawei Push rejected: token=%s… code=%s body=%s",
                    provider_token[:8],
                    code,
                    response.text[:200],
                )
                return False
            logger.warning(
                "Huawei Push HTTP failed: token=%s… status=%s body=%s",
                provider_token[:8],
                response.status_code,
                response.text[:200],
            )
            return False
        except Exception as exc:
            logger.exception("Huawei Push send failed: %s", exc)
            return False


harmony_push_client = HarmonyPushClient()
