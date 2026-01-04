"""Security utilities."""

from datetime import datetime, timedelta, timezone
from typing import Optional

from jose import JWTError, jwt
from cryptography.fernet import Fernet

from app.config import settings


def create_access_token(
    data: dict,
    expires_delta: Optional[timedelta] = None,
) -> str:
    """Create JWT access token."""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(
            minutes=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES
        )
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(
        to_encode,
        settings.JWT_SECRET_KEY,
        algorithm=settings.JWT_ALGORITHM,
    )
    return encoded_jwt


def decode_access_token(token: str) -> Optional[dict]:
    """Decode and verify JWT access token."""
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM],
        )
        return payload
    except JWTError:
        return None


class TokenEncryption:
    """Encrypt/decrypt Tesla tokens for storage."""

    def __init__(self):
        """Initialize with encryption key."""
        key = settings.TESLA_TOKEN_ENCRYPTION_KEY
        if key:
            self.fernet = Fernet(key.encode())
        else:
            self.fernet = None

    def encrypt(self, token: str) -> str:
        """Encrypt a token."""
        if not self.fernet:
            raise ValueError("Encryption key not configured")
        return self.fernet.encrypt(token.encode()).decode()

    def decrypt(self, encrypted_token: str) -> str:
        """Decrypt a token."""
        if not self.fernet:
            raise ValueError("Encryption key not configured")
        return self.fernet.decrypt(encrypted_token.encode()).decode()
