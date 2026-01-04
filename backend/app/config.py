"""Application configuration."""

from typing import List

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings."""

    # App
    APP_NAME: str = "TePlanner"
    APP_ENV: str = "development"
    DEBUG: bool = True
    SECRET_KEY: str = "change-me-in-production"

    # Server
    HOST: str = "0.0.0.0"
    PORT: int = 8000

    # Database
    DATABASE_URL: str = "sqlite+aiosqlite:///./teplanner.db"

    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"

    # Tesla API
    TESLA_API_BASE_URL: str = "https://owner-api.teslamotors.com"
    TESLA_CLIENT_ID: str = ""
    TESLA_CLIENT_SECRET: str = ""
    TESLA_TOKEN_ENCRYPTION_KEY: str = ""

    # Tencent Map API
    TENCENT_MAP_KEY: str = ""
    TENCENT_MAP_SECRET: str = ""

    # WeChat
    WECHAT_APP_ID: str = ""
    WECHAT_APP_SECRET: str = ""

    # JWT
    JWT_SECRET_KEY: str = "jwt-secret-key"
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    JWT_REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # CORS
    CORS_ORIGINS: List[str] = ["*"]

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


settings = Settings()
