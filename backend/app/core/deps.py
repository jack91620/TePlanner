"""FastAPI dependencies."""

from datetime import datetime, timezone
from typing import Optional

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.core.security import TokenEncryption, decode_access_token
from app.db.models import TeslaToken, User, Vehicle
from app.db.session import get_db
from app.integrations.tesla import TeslaClient

# Security scheme
security = HTTPBearer(auto_error=False)


async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Get the current authenticated user.

    Args:
        credentials: JWT token from Authorization header.
        db: Database session.

    Returns:
        The authenticated user.

    Raises:
        HTTPException: If token is invalid or user not found.
    """
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = credentials.credentials
    payload = decode_access_token(token)

    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload",
        )

    result = await db.execute(select(User).where(User.id == int(user_id)))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is disabled",
        )

    return user


async def get_current_user_optional(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: AsyncSession = Depends(get_db),
) -> Optional[User]:
    """Get the current user if authenticated, otherwise None.

    Useful for endpoints that work with or without authentication.
    """
    if not credentials:
        return None

    try:
        return await get_current_user(credentials, db)
    except HTTPException:
        return None


async def get_tesla_client(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> TeslaClient:
    """Get Tesla client with user's access token.

    Args:
        user: The authenticated user.
        db: Database session.

    Returns:
        TeslaClient configured with user's access token.

    Raises:
        HTTPException: If user has no Tesla token linked.
    """
    result = await db.execute(
        select(TeslaToken)
        .where(TeslaToken.user_id == user.id)
        .order_by(TeslaToken.updated_at.desc())
    )
    tesla_token = result.scalar_one_or_none()

    if not tesla_token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Tesla account not linked. Please authorize Tesla first.",
        )

    # Check if token is expired (handle None expires_at)
    is_expired = (
        tesla_token.expires_at is None or
        tesla_token.expires_at < datetime.now(timezone.utc)
    )
    if is_expired:
        # Try to refresh the token
        try:
            from app.integrations.tesla import TeslaAuth

            encryption = TokenEncryption()
            refresh_token = encryption.decrypt(tesla_token.refresh_token)

            auth = TeslaAuth()
            new_tokens = await auth.refresh_token(refresh_token)

            # Update token in database
            tesla_token.access_token = encryption.encrypt(new_tokens["access_token"])
            tesla_token.refresh_token = encryption.encrypt(new_tokens["refresh_token"])
            tesla_token.expires_at = datetime.now(timezone.utc) + \
                timedelta(seconds=new_tokens.get("expires_in", 3600))
            await db.commit()

            access_token = new_tokens["access_token"]
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Tesla token expired and refresh failed: {str(e)}",
            )
    else:
        # Decrypt and use existing token
        encryption = TokenEncryption()
        try:
            access_token = encryption.decrypt(tesla_token.access_token)
        except Exception:
            # Token might not be encrypted (legacy)
            access_token = tesla_token.access_token

    return TeslaClient(access_token=access_token)


async def get_user_vehicle(
    vehicle_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Vehicle:
    """Get a specific vehicle owned by the user.

    Args:
        vehicle_id: Vehicle ID to fetch.
        user: The authenticated user.
        db: Database session.

    Returns:
        The vehicle if found and owned by user.

    Raises:
        HTTPException: If vehicle not found or not owned by user.
    """
    result = await db.execute(
        select(Vehicle).where(
            Vehicle.user_id == user.id,
            Vehicle.vehicle_id == vehicle_id,
        )
    )
    vehicle = result.scalar_one_or_none()

    if not vehicle:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehicle not found",
        )

    return vehicle


# Import timedelta here to avoid circular import issues
from datetime import timedelta
