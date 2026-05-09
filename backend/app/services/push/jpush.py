"""JPush (极光推送) sender — Phase E.

Aggregator service that fans pushes out to the OEM channels in
mainland China (Mi / Huawei legacy / OPPO / vivo). We target the
v3 REST API with HTTP basic auth (AppKey:MasterSecret).

Configuration:
  JPUSH_APP_KEY            — JPush app key (12 hex chars)
  JPUSH_MASTER_SECRET      — JPush master secret (24 hex chars)
  JPUSH_API_URL            — defaults to https://api.jpush.cn/v3/push
  JPUSH_PRODUCTION         — "true" for prod APNs cert, else dev

Routes by `provider_token` (the JPush registration_id the SDK hands
back). When that's missing we treat the call as no-op (logged, not
raised) so the dispatcher's other channels stay independent.
"""

from __future__ import annotations

import base64
import logging
from typing import Optional

import httpx

from app.config import settings

logger = logging.getLogger(__name__)


class JPushClient:
    DEFAULT_URL = "https://api.jpush.cn/v3/push"

    def __init__(self) -> None:
        self._app_key = getattr(settings, "JPUSH_APP_KEY", "") or ""
        self._master_secret = getattr(settings, "JPUSH_MASTER_SECRET", "") or ""
        self._api_url = getattr(settings, "JPUSH_API_URL", "") or self.DEFAULT_URL
        self._production = (
            str(getattr(settings, "JPUSH_PRODUCTION", "false")).lower() == "true"
        )
        self._configured = bool(self._app_key and self._master_secret)
        if not self._configured:
            logger.info(
                "JPush not configured (JPUSH_APP_KEY / JPUSH_MASTER_SECRET missing) "
                "— Android push sending disabled"
            )

    @property
    def configured(self) -> bool:
        return self._configured

    def _auth_header(self) -> str:
        raw = f"{self._app_key}:{self._master_secret}".encode("ascii")
        return "Basic " + base64.b64encode(raw).decode("ascii")

    def _build_payload(
        self,
        registration_id: str,
        title: str,
        body: str,
        custom_data: Optional[dict],
    ) -> dict:
        notification: dict = {
            "alert": body,
            "android": {"alert": body, "title": title},
            "ios": {
                "alert": {"title": title, "body": body},
                "sound": "default",
            },
        }
        payload: dict = {
            "platform": "all",
            "audience": {"registration_id": [registration_id]},
            "notification": notification,
            "options": {"apns_production": self._production},
        }
        if custom_data:
            payload["message"] = {
                "msg_content": body,
                "title": title,
                "extras": custom_data,
            }
        return payload

    async def send(
        self,
        provider_token: str,
        title: str,
        body: str,
        custom_data: Optional[dict] = None,
    ) -> bool:
        """Send via JPush. ``provider_token`` is the JPush
        registration_id the client SDK hands back at install time.
        Returns True on 200, False otherwise; never raises so the
        dispatcher's other channels survive a JPush outage.
        """
        if not self._configured:
            logger.debug("JPush send skipped (not configured): %s — %s", title, body)
            return False
        if not provider_token:
            logger.warning("JPush send skipped: empty registration_id for title=%s", title)
            return False

        payload = self._build_payload(provider_token, title, body, custom_data)
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.post(
                    self._api_url,
                    headers={
                        "Authorization": self._auth_header(),
                        "Content-Type": "application/json",
                    },
                    json=payload,
                )
            if 200 <= response.status_code < 300:
                logger.info(
                    "JPush sent: rid=%s… title=%s msg_id=%s",
                    provider_token[:8],
                    title,
                    response.json().get("msg_id") if response.content else "?",
                )
                return True
            logger.warning(
                "JPush rejected: rid=%s… title=%s status=%s body=%s",
                provider_token[:8],
                title,
                response.status_code,
                response.text[:200],
            )
            return False
        except Exception as exc:
            logger.exception("JPush send failed: %s", exc)
            return False


jpush_client = JPushClient()
