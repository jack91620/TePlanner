"""User schemas."""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class UserBase(BaseModel):
    """Base user schema."""

    nickname: Optional[str] = None
    avatar_url: Optional[str] = None


class UserCreate(UserBase):
    """User creation schema."""

    wechat_openid: str
    wechat_unionid: Optional[str] = None


class UserUpdate(UserBase):
    """User update schema."""

    pass


class UserResponse(UserBase):
    """User response schema."""

    id: int
    wechat_openid: str
    has_tesla_linked: bool = False
    created_at: datetime

    model_config = {"from_attributes": True}
