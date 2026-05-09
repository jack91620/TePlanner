"""APNs (Apple Push Notification service) sender — Phase E re-home.

Moved from `app.services.apns` to `app.services.push.apns` so the
push-multiplex package owns every per-platform client. The legacy
import path stays as a shim for one release while internal callers
migrate.
"""

from __future__ import annotations

import logging
from typing import Optional

from app.config import settings

logger = logging.getLogger(__name__)


class APNsClient:
    """Lazy wrapper. The actual aioapns NotificationRequest / APNs
    object is created on first send so we don't import aioapns at
    module load time on dev machines without it installed.
    """

    def __init__(self) -> None:
        self._apns = None
        self._configured = bool(
            settings.APNS_AUTH_KEY_PATH
            and settings.APNS_KEY_ID
            and settings.APNS_TEAM_ID
        )
        if not self._configured:
            logger.info(
                "APNs not configured (auth key / key id / team id missing) — "
                "push sending disabled"
            )

    @property
    def configured(self) -> bool:
        return self._configured

    async def _get_apns(self):
        if self._apns is None:
            from aioapns import APNs

            use_sandbox = settings.APNS_ENVIRONMENT.lower() == "sandbox"
            self._apns = APNs(
                key=settings.APNS_AUTH_KEY_PATH,
                key_id=settings.APNS_KEY_ID,
                team_id=settings.APNS_TEAM_ID,
                topic=settings.APNS_BUNDLE_ID,
                use_sandbox=use_sandbox,
            )
        return self._apns

    async def send(
        self,
        device_token: str,
        title: str,
        body: str,
        category: Optional[str] = None,
        thread_id: Optional[str] = None,
        custom_data: Optional[dict] = None,
    ) -> bool:
        if not self._configured:
            logger.debug("APNs send skipped (not configured): %s — %s", title, body)
            return False

        from aioapns import NotificationRequest

        try:
            apns = await self._get_apns()
            payload = {
                "aps": {
                    "alert": {"title": title, "body": body},
                    "sound": "default",
                }
            }
            if category:
                payload["aps"]["category"] = category
            if thread_id:
                payload["aps"]["thread-id"] = thread_id
            if custom_data:
                payload.update(custom_data)

            request = NotificationRequest(
                device_token=device_token,
                message=payload,
            )
            response = await apns.send_notification(request)
            if response.is_successful:
                logger.info(
                    "APNs sent: token=%s… title=%s",
                    device_token[:8],
                    title,
                )
                return True
            logger.warning(
                "APNs rejected: token=%s… title=%s status=%s description=%s",
                device_token[:8],
                title,
                response.status,
                response.description,
            )
            return False
        except Exception as exc:
            logger.exception("APNs send failed: %s", exc)
            return False


apns_client = APNsClient()
