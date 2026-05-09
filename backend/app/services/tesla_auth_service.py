"""Tesla OAuth + token persistence service.

Extracted from `app/api/v1/auth.py` so the same logic powers all
three callers (GET /tesla/callback for HTML WebView, POST
/tesla/callback for native iOS, POST /tesla/refresh) without
copy-pasting the encrypt + upsert dance three times.

Public entry points:

  - ``exchange_and_store(code, code_verifier, user_id, db)``: run
    the OAuth code-grant exchange, encrypt the resulting access /
    refresh tokens, upsert into TeslaToken. Returns the plain
    tokens + expires_in for the caller (handler / WebView render
    HTML / mini program SDK).

  - ``refresh_and_store(refresh_token, user_id, db)``: same shape
    for the refresh-token grant. user_id may be None — in that case
    we just call Tesla and return the new tokens without persisting
    (callers like the iOS bootstrap that only want a fresh access
    token without touching the DB).

Both raise ``TeslaAuthError`` on Tesla-side failure; handlers map to
HTTP 400 / HTML error page. Encrypt failures propagate as 500 — the
audit on 2026-05-09 confirmed Fernet is always configured in prod.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import TokenEncryption
from app.db.models import TeslaToken, User
from app.integrations.tesla.auth import TeslaAuth

logger = logging.getLogger(__name__)


class TeslaAuthError(Exception):
    """OAuth grant returned no usable tokens, or upstream Tesla error.
    Handler-level code translates to HTTP 400."""


@dataclass(frozen=True)
class TeslaTokenBundle:
    access_token: str
    refresh_token: str
    expires_in: int


async def exchange_and_store(
    code: str,
    code_verifier: str,
    user_id: Optional[int],
    db: AsyncSession,
) -> TeslaTokenBundle:
    """Exchange auth code for tokens; persist if user_id given.

    Steps:
      1. POST to Tesla /oauth2/v3/token with the PKCE code_verifier.
      2. Validate Tesla returned both access + refresh.
      3. If user_id is set:
         a. Confirm the user exists.
         b. Encrypt both tokens with Fernet (raises if Fernet not
            configured — caller maps to 500).
         c. Upsert into TeslaToken keyed on user_id.
      4. Return the plain tokens + expires_in for the caller.

    Raises TeslaAuthError if the upstream call fails or the response
    is missing tokens.
    """
    try:
        tokens = await TeslaAuth().exchange_code(code, code_verifier)
    except Exception as exc:
        raise TeslaAuthError(f"Tesla code exchange failed: {exc}") from exc

    access = tokens.get("access_token")
    refresh = tokens.get("refresh_token")
    expires_in = int(tokens.get("expires_in", 3600))
    if not access or not refresh:
        raise TeslaAuthError("Tesla returned no access/refresh token")

    if user_id is not None:
        await _persist_tokens(
            db=db,
            user_id=user_id,
            access_token=access,
            refresh_token=refresh,
            expires_in=expires_in,
        )

    return TeslaTokenBundle(
        access_token=access,
        refresh_token=refresh,
        expires_in=expires_in,
    )


async def refresh_and_store(
    refresh_token_in: str,
    user_id: Optional[int],
    db: AsyncSession,
) -> TeslaTokenBundle:
    """Refresh-token grant. Same shape as exchange_and_store.

    user_id is optional; when None, we still hit Tesla and return
    fresh tokens without writing to the DB (used by the bootstrap
    path where the iOS client just wants a fresh access token).
    """
    try:
        tokens = await TeslaAuth().refresh_token(refresh_token_in)
    except Exception as exc:
        raise TeslaAuthError(f"Tesla token refresh failed: {exc}") from exc

    access = tokens.get("access_token")
    refresh = tokens.get("refresh_token")
    expires_in = int(tokens.get("expires_in", 3600))
    if not access or not refresh:
        raise TeslaAuthError("Tesla refresh returned no tokens")

    if user_id is not None:
        # Refresh is update-only: skip if no row exists rather than
        # creating one with no original linked Tesla account.
        result = await db.execute(
            select(TeslaToken).where(TeslaToken.user_id == user_id)
        )
        existing = result.scalar_one_or_none()
        if existing is not None:
            encryption = TokenEncryption()
            existing.access_token = encryption.encrypt(access)
            existing.refresh_token = encryption.encrypt(refresh)
            existing.expires_at = datetime.utcnow() + timedelta(seconds=expires_in)
            await db.commit()

    return TeslaTokenBundle(
        access_token=access,
        refresh_token=refresh,
        expires_in=expires_in,
    )


async def _persist_tokens(
    db: AsyncSession,
    user_id: int,
    access_token: str,
    refresh_token: str,
    expires_in: int,
) -> None:
    """Upsert a TeslaToken row for the user. Skips if the user record
    doesn't exist (silent — callers consider this a no-op rather than
    an error, since OAuth state could outlive the user account)."""
    user_row = await db.execute(
        select(User).where(User.id == user_id)
    )
    if user_row.scalar_one_or_none() is None:
        logger.warning(
            "tesla token persist skipped: user %s no longer exists",
            user_id,
        )
        return

    encryption = TokenEncryption()
    encrypted_access = encryption.encrypt(access_token)
    encrypted_refresh = encryption.encrypt(refresh_token)
    expires_at = datetime.utcnow() + timedelta(seconds=expires_in)

    existing = (await db.execute(
        select(TeslaToken).where(TeslaToken.user_id == user_id)
    )).scalar_one_or_none()

    if existing is not None:
        existing.access_token = encrypted_access
        existing.refresh_token = encrypted_refresh
        existing.expires_at = expires_at
    else:
        db.add(TeslaToken(
            user_id=user_id,
            access_token=encrypted_access,
            refresh_token=encrypted_refresh,
            expires_at=expires_at,
        ))

    await db.commit()
