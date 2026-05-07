"""Device push-token endpoints.

iOS posts its APNs device token after the user grants notification
permission (and on each subsequent launch in case the token rotates
— Apple recommends sending it every launch). The polling layer reads
back tokens by user_id when a rule fires.
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
from app.services.apns import apns_client

logger = logging.getLogger(__name__)
router = APIRouter()


class RegisterDeviceRequest(BaseModel):
    token: str = Field(..., min_length=10, max_length=200, description="Hex APNs device token")
    bundle_id: Optional[str] = None


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
    stmt = select(DeviceToken).where(
        DeviceToken.user_id == user.id,
        DeviceToken.token == request.token,
    )
    existing = (await db.execute(stmt)).scalar_one_or_none()

    if existing:
        existing.last_seen_at = datetime.utcnow()
        if request.bundle_id:
            existing.bundle_id = request.bundle_id
        await db.flush()
        logger.info("device token re-registered: user=%s id=%s", user.id, existing.id)
        return RegisterDeviceResponse(success=True, device_id=existing.id)

    row = DeviceToken(
        user_id=user.id,
        token=request.token,
        platform="ios",
        bundle_id=request.bundle_id,
    )
    db.add(row)
    await db.flush()
    logger.info("device token registered: user=%s id=%s token=%s…", user.id, row.id, request.token[:8])
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
    Useful while wiring up — flip APNs creds, hit this endpoint, see
    if a notification lands on the phone.
    """
    if not apns_client.configured:
        raise HTTPException(503, "APNs is not configured on the server")

    stmt = select(DeviceToken).where(DeviceToken.user_id == user.id)
    tokens = (await db.execute(stmt)).scalars().all()
    if not tokens:
        raise HTTPException(404, "No devices registered for this user")

    sent = 0
    failed = 0
    for entry in tokens:
        ok = await apns_client.send(
            device_token=entry.token,
            title=request.title,
            body=request.body,
            category="DEBUG",
        )
        if ok:
            sent += 1
        else:
            failed += 1

    return {"devices": len(tokens), "sent": sent, "failed": failed}
