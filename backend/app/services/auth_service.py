"""Email/password registration + login service.

Extracted from `app/api/v1/auth.py` so the password-hashing + JWT
mint + Tesla-link probe logic is unit-testable without TestClient
and reusable from non-HTTP entry points (CLI, admin scripts).

Public entry points:

  - ``register_email_user(email, password, nickname, db)``: hash
    password, insert User, mint JWT. Raises EmailAlreadyExistsError
    if the email is taken.

  - ``login_email_user(email, password, db)``: verify password,
    check active, look up Tesla link, mint JWT. Raises
    InvalidCredentialsError / AccountDisabledError on the two
    distinct failure modes the handler maps to 401.

Both return an ``EmailAuthBundle`` dataclass; the handler wraps it
in the Pydantic response model.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import timedelta
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.core.security import (
    create_access_token,
    get_password_hash,
    verify_password,
)
from app.db.models import TeslaToken, User

logger = logging.getLogger(__name__)


class EmailAlreadyExistsError(Exception):
    """Email already registered — handler maps to 400."""


class InvalidCredentialsError(Exception):
    """Wrong email/password OR no password_hash on file (e.g. WeChat-
    only user trying to email-login). Handler maps to 401."""


class AccountDisabledError(Exception):
    """User row exists but is_active=False. Handler maps to 401."""


@dataclass(frozen=True)
class EmailAuthBundle:
    access_token: str
    expires_in: int
    user_id: int
    email: str
    nickname: Optional[str]
    has_tesla_linked: bool


async def register_email_user(
    email: str,
    password: str,
    nickname: Optional[str],
    db: AsyncSession,
) -> EmailAuthBundle:
    """Create a User, hash password, mint JWT, return bundle."""
    existing = (await db.execute(
        select(User).where(User.email == email)
    )).scalar_one_or_none()
    if existing is not None:
        raise EmailAlreadyExistsError(f"Email {email} already registered")

    user = User(
        email=email,
        password_hash=get_password_hash(password),
        nickname=nickname or email.split("@")[0],
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)

    return _bundle_for(user, has_tesla=False)


async def login_email_user(
    email: str,
    password: str,
    db: AsyncSession,
) -> EmailAuthBundle:
    """Authenticate email/password, mint JWT, return bundle."""
    user = (await db.execute(
        select(User).where(User.email == email)
    )).scalar_one_or_none()

    if user is None or not user.password_hash:
        raise InvalidCredentialsError("Invalid email or password")
    if not verify_password(password, user.password_hash):
        raise InvalidCredentialsError("Invalid email or password")
    if not user.is_active:
        raise AccountDisabledError("Account is disabled")

    has_tesla = (await db.execute(
        select(TeslaToken).where(TeslaToken.user_id == user.id)
    )).scalar_one_or_none() is not None

    return _bundle_for(user, has_tesla=has_tesla)


def _bundle_for(user: User, has_tesla: bool) -> EmailAuthBundle:
    expires_minutes = settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES
    token = create_access_token(
        data={"sub": str(user.id), "email": user.email},
        expires_delta=timedelta(minutes=expires_minutes),
    )
    return EmailAuthBundle(
        access_token=token,
        expires_in=expires_minutes * 60,
        user_id=user.id,
        email=user.email,
        nickname=user.nickname,
        has_tesla_linked=has_tesla,
    )
