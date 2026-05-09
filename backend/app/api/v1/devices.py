"""Device push-token endpoints.

iOS posts its APNs device token after the user grants notification
permission (and on each subsequent launch in case the token rotates
— Apple recommends sending it every launch). Phase E adds Android
(JPush) and HarmonyOS (Huawei Push Kit) registration through the
same endpoint; the `platform` field discriminates.
"""

import logging
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user, get_db
from app.db.models import DeviceToken, User
from app.services.push import push_dispatcher

logger = logging.getLogger(__name__)
router = APIRouter()


VALID_PLATFORMS = {"apns", "jpush", "harmony"}


class RegisterDeviceRequest(BaseModel):
    token: str = Field(..., min_length=10, max_length=200,
                        description="Provider device token (APNs hex / JPush registration_id / Huawei push token)")
    bundle_id: Optional[str] = None
    # Phase E — accept "apns" / "jpush" / "harmony"; legacy clients
    # without this field default to "apns" (= the only channel pre-E).
    platform: str = Field("apns", max_length=20)
    # Phase E — provider-specific identifier when distinct from `token`.
    # JPush has both an installation token and a registration_id;
    # callers should send the registration_id here when known.
    provider_token: Optional[str] = Field(None, max_length=255)


class RegisterDeviceResponse(BaseModel):
    success: bool
    device_id: int


@router.post("/register", response_model=RegisterDeviceResponse)
async def register_device(
    request: RegisterDeviceRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> RegisterDeviceResponse:
    """Upsert (user_id, token). Re-registering an existing token just
    bumps last_seen_at — that lets the polling layer prune stale rows
    later (e.g. tokens not seen for 30 days are likely uninstalled).
    """
    platform = request.platform.lower()
    # Backwards compat: legacy "ios" → "apns".
    if platform == "ios":
        platform = "apns"
    if platform not in VALID_PLATFORMS:
        raise HTTPException(
            400,
            f"unknown platform {request.platform!r}; expected one of {sorted(VALID_PLATFORMS)}",
        )

    stmt = select(DeviceToken).where(
        DeviceToken.user_id == user.id,
        DeviceToken.token == request.token,
    )
    existing = (await db.execute(stmt)).scalar_one_or_none()

    if existing:
        existing.last_seen_at = datetime.utcnow()
        if request.bundle_id:
            existing.bundle_id = request.bundle_id
        existing.platform = platform
        if request.provider_token is not None:
            existing.provider_token = request.provider_token
        await db.flush()
        logger.info(
            "device token re-registered: user=%s id=%s platform=%s",
            user.id, existing.id, platform,
        )
        return RegisterDeviceResponse(success=True, device_id=existing.id)

    row = DeviceToken(
        user_id=user.id,
        token=request.token,
        platform=platform,
        provider_token=request.provider_token,
        bundle_id=request.bundle_id,
    )
    db.add(row)
    await db.flush()
    logger.info(
        "device token registered: user=%s id=%s platform=%s token=%s…",
        user.id, row.id, platform, request.token[:8],
    )
    return RegisterDeviceResponse(success=True, device_id=row.id)


class TestPushRequest(BaseModel):
    title: str = "TePlanner 测试推送"
    body: str = "如果你看到这条通知，APNs 已打通。"


@router.post("/test-push")
async def test_push(
    request: TestPushRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Send a debug push to all of this user's registered devices.
    Phase E — routes through PushDispatcher so APNs / JPush / Huawei
    Push Kit all receive it according to each token's platform field.
    """
    summary = await push_dispatcher.send(
        db=db,
        user_id=user.id,
        title=request.title,
        body=request.body,
        category="DEBUG",
    )
    if summary.devices == 0:
        raise HTTPException(404, "No devices registered for this user")
    return {
        "devices": summary.devices,
        "sent": summary.sent,
        "failed": summary.failed,
        "skipped": summary.skipped,
        "by_platform": summary.by_platform,
    }


@router.post("/run-automation-tick")
async def run_automation_tick(
    user: User = Depends(get_current_user),
) -> dict:
    """Trigger a single polling tick on demand. Used for end-to-end
    debugging: hit this, watch server.log, verify a push lands. Doesn't
    take args — runs the full eligible-user loop.
    """
    from app.services.cron_tick import run_one_tick

    polled = await run_one_tick()
    return {"polled_users": polled}
