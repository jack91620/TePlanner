"""Phase E — push dispatcher.

Routes by ``DeviceToken.platform``: APNs for iOS, JPush for Android,
Huawei Push Kit for HarmonyOS NEXT. Callers provide a (user_id,
title, body, ?custom_data) bundle and the dispatcher fans out to
every active token for that user. Per-platform send results are
counted independently so a JPush outage doesn't hide successful APNs
deliveries from the metrics.

Backwards compat: a row whose `platform == "apns"` always uses
`token` (the raw APNs hex token); rows for `jpush` / `harmony` use
`provider_token` and fall back to `token` if it's null (helps during
the iOS-first transition window).
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import DeviceToken
from app.services.push.apns import apns_client
from app.services.push.harmony_push import harmony_push_client
from app.services.push.jpush import jpush_client

logger = logging.getLogger(__name__)


@dataclass
class DispatchSummary:
    devices: int
    sent: int
    failed: int
    skipped: int
    by_platform: dict[str, int]


class PushDispatcher:
    """Single entry-point for the automation engine + endpoints."""

    async def send(
        self,
        db: AsyncSession,
        user_id: int,
        title: str,
        body: str,
        category: Optional[str] = None,
        thread_id: Optional[str] = None,
        custom_data: Optional[dict] = None,
    ) -> DispatchSummary:
        stmt = select(DeviceToken).where(DeviceToken.user_id == user_id)
        rows = (await db.execute(stmt)).scalars().all()
        if not rows:
            return DispatchSummary(0, 0, 0, 0, {})

        sent = 0
        failed = 0
        skipped = 0
        by_platform: dict[str, int] = {}
        for row in rows:
            platform = (row.platform or "apns").lower()
            by_platform[platform] = by_platform.get(platform, 0) + 1

            ok: Optional[bool]
            if platform in ("apns", "ios"):
                ok = await apns_client.send(
                    device_token=row.token,
                    title=title,
                    body=body,
                    category=category,
                    thread_id=thread_id,
                    custom_data=custom_data,
                )
            elif platform == "jpush":
                ok = await jpush_client.send(
                    provider_token=row.provider_token or row.token,
                    title=title,
                    body=body,
                    custom_data=custom_data,
                )
            elif platform == "harmony":
                ok = await harmony_push_client.send(
                    provider_token=row.provider_token or row.token,
                    title=title,
                    body=body,
                    custom_data=custom_data,
                )
            else:
                logger.warning(
                    "PushDispatcher: unknown platform %r on device_tokens.id=%s — skipping",
                    platform,
                    row.id,
                )
                skipped += 1
                continue

            if ok:
                sent += 1
            else:
                failed += 1

        return DispatchSummary(
            devices=len(rows),
            sent=sent,
            failed=failed,
            skipped=skipped,
            by_platform=by_platform,
        )


push_dispatcher = PushDispatcher()
