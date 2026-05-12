"""Cross-platform share codes for automations + hub quick actions.

Owner posts a payload + share type; server mints a 6-char base32 code
(no 0/O/1/I/l) and stores it for 30 days. Recipients GET by code to
import on iOS / Android / Harmony.

Privacy: payloads are stored as opaque JSON. The CALLER strips
user-specific fields before POST — server doesn't enforce schema
because share-format extensions ship faster than backend migrations.
We do enforce min_app_version on GET so a 2026-05-12 share that uses
capability X can't be imported by an older client that doesn't
understand X.
"""

from __future__ import annotations

import json
import logging
import secrets
from datetime import datetime, timedelta
from typing import Any, Literal, Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Response, status
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user, get_db
from app.db.models import Share, User

logger = logging.getLogger(__name__)
router = APIRouter()


# 32-char base32-friendly alphabet — excludes 0/O/1/I/l so codes
# stay readable over the phone or on a low-DPI screenshot.
SHARE_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
SHARE_CODE_LENGTH = 6
SHARE_CODE_INSERT_RETRIES = 5
DEFAULT_EXPIRY_DAYS = 30
ShareType = Literal["action", "rule"]


def _mint_code() -> str:
    return "".join(
        secrets.choice(SHARE_CODE_ALPHABET) for _ in range(SHARE_CODE_LENGTH)
    )


def _normalize_code(raw: str) -> str:
    """Strip whitespace and the optional `XXXX-XX` dash users may type
    when reading codes off a screenshot, and uppercase. Returns the
    raw lookup key. Letters not in the alphabet pass through — caller
    sees a 404, not a misleading 400, since malformed codes look
    identical to non-existent ones to an attacker."""
    return raw.replace("-", "").replace(" ", "").upper()


class ShareCreateRequest(BaseModel):
    share_type: ShareType = Field(
        ..., description="'action' = hub quick action; 'rule' = automation rule.",
    )
    payload: dict[str, Any] = Field(
        ...,
        description=(
            "The shared item, with user-specific fields already stripped "
            "client-side (no user_id, no vehicle_id, no internal action_id)."
        ),
    )
    expires_in_days: int = Field(
        default=DEFAULT_EXPIRY_DAYS, ge=1, le=365,
        description="How long the code stays valid. 30 by default.",
    )
    min_app_version: Optional[str] = Field(
        default=None,
        description=(
            "CFBundleVersion / Android versionCode the share was authored "
            "against. Importer < this version gets 412."
        ),
    )


class ShareResponse(BaseModel):
    code: str
    share_type: ShareType
    created_at: datetime
    expires_at: datetime
    view_count: int
    min_app_version: Optional[str]
    revoked: bool = False


class ShareDetailResponse(ShareResponse):
    payload: dict[str, Any]


class ShareListResponse(BaseModel):
    shares: list[ShareResponse]


@router.post("", response_model=ShareDetailResponse, status_code=status.HTTP_201_CREATED)
async def create_share(
    body: ShareCreateRequest,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> ShareDetailResponse:
    """Mint a share. Returns the code + full payload echo so the
    iOS client can immediately render the share sheet without a
    second roundtrip."""
    payload_text = json.dumps(body.payload, ensure_ascii=False)
    now = datetime.utcnow()
    expires_at = now + timedelta(days=body.expires_in_days)

    # Retry on the small chance of a base32 collision. After
    # SHARE_CODE_INSERT_RETRIES failures we give up loudly — better
    # than silently corrupting an existing share.
    last_error: Optional[Exception] = None
    for _ in range(SHARE_CODE_INSERT_RETRIES):
        code = _mint_code()
        row = Share(
            code=code,
            share_type=body.share_type,
            payload_json=payload_text,
            owner_user_id=user.id,
            created_at=now,
            expires_at=expires_at,
            min_app_version=body.min_app_version,
            view_count=0,
        )
        db.add(row)
        try:
            await db.commit()
            break
        except IntegrityError as exc:
            await db.rollback()
            last_error = exc
            continue
    else:
        logger.error("shares: ran out of code-collision retries: %s", last_error)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Could not allocate a share code; please retry.",
        )

    await db.refresh(row)
    return ShareDetailResponse(
        code=row.code,
        share_type=row.share_type,  # type: ignore[arg-type]
        created_at=row.created_at,
        expires_at=row.expires_at,
        view_count=row.view_count,
        min_app_version=row.min_app_version,
        payload=body.payload,
        revoked=False,
    )


@router.get("/mine", response_model=ShareListResponse)
async def list_my_shares(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> ShareListResponse:
    """Owner's own shares, newest first. Used by the "我的分享" tab
    so the user can see which codes are live and revoke them."""
    stmt = (
        select(Share)
        .where(Share.owner_user_id == user.id)
        .order_by(Share.created_at.desc())
        .limit(100)
    )
    rows = (await db.execute(stmt)).scalars().all()
    return ShareListResponse(
        shares=[
            ShareResponse(
                code=r.code,
                share_type=r.share_type,  # type: ignore[arg-type]
                created_at=r.created_at,
                expires_at=r.expires_at,
                view_count=r.view_count,
                min_app_version=r.min_app_version,
                revoked=r.revoked_at is not None,
            )
            for r in rows
        ]
    )


@router.get("/{code}", response_model=ShareDetailResponse)
async def get_share(
    code: str,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
    x_app_version: Optional[str] = Header(default=None),
) -> ShareDetailResponse:
    """Fetch a share by code. 404 = not found / never existed.
    410 = expired or revoked. 412 = client version < min_app_version.
    On success, increments view_count for owner analytics."""
    lookup = _normalize_code(code)
    row = await db.get(Share, lookup)
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Share code not found.",
        )
    now = datetime.utcnow()
    if row.revoked_at is not None or row.expires_at < now:
        raise HTTPException(
            status_code=status.HTTP_410_GONE,
            detail="Share code has expired or been revoked.",
        )
    if row.min_app_version is not None and x_app_version is not None:
        if _version_lt(x_app_version, row.min_app_version):
            raise HTTPException(
                status_code=status.HTTP_412_PRECONDITION_FAILED,
                detail=(
                    f"This share requires app version {row.min_app_version} or later "
                    f"(you are on {x_app_version}). Please update to import."
                ),
            )

    row.view_count = (row.view_count or 0) + 1
    await db.commit()
    await db.refresh(row)

    try:
        payload = json.loads(row.payload_json)
    except json.JSONDecodeError:
        logger.exception("shares: payload_json corrupt for code=%s", lookup)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Share payload is corrupt.",
        )
    return ShareDetailResponse(
        code=row.code,
        share_type=row.share_type,  # type: ignore[arg-type]
        created_at=row.created_at,
        expires_at=row.expires_at,
        view_count=row.view_count,
        min_app_version=row.min_app_version,
        payload=payload,
        revoked=False,
    )


@router.delete("/{code}")
async def revoke_share(
    code: str,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> Response:
    """Owner-only revoke. Sets revoked_at; future GETs return 410.
    We don't hard-delete the row so view_count remains visible in
    /shares/mine for the owner's records."""
    lookup = _normalize_code(code)
    row = await db.get(Share, lookup)
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    if row.owner_user_id != user.id:
        # 404 (not 403) so attackers can't probe for valid codes
        # they don't own.
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    if row.revoked_at is None:
        row.revoked_at = datetime.utcnow()
        await db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


def _version_lt(a: str, b: str) -> bool:
    """Compare two CFBundleVersion-style strings. Both are typically
    monotone integers ("38", "39") but we tolerate the iOS dotted
    form too ("0.0.39") by lex-comparing each component as int.
    Returns True iff a < b."""
    def parts(s: str) -> tuple[int, ...]:
        out: list[int] = []
        for p in s.split("."):
            try:
                out.append(int(p))
            except ValueError:
                return tuple(out)
        return tuple(out)

    return parts(a) < parts(b)
