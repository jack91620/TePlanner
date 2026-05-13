"""Application configuration."""

from typing import List

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings."""

    # App
    APP_NAME: str = "Tautomation"
    APP_ENV: str = "development"
    DEBUG: bool = True
    SECRET_KEY: str = "change-me-in-production"

    # Server
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    WORKERS: int = 1

    # Logging
    LOG_LEVEL: str = "INFO"
    LOG_FORMAT: str = "json"

    # Database
    DATABASE_URL: str = "sqlite+aiosqlite:///./teplanner.db"

    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"

    # Tesla API
    # Owner API (非官方，作为备用)
    TESLA_API_BASE_URL: str = "https://owner-api.teslamotors.com"
    # Fleet API (官方)
    TESLA_FLEET_API_BASE_URL: str = "https://fleet-api.prd.na.vn.cloud.tesla.com"
    # Phase 7 (VCP): tesla-http-proxy 本地 endpoint，用于发送签名后的
    # 车辆命令（set_charge_limit / climate_keeper_mode / sentry / preheat
    # 等）。Tesla 已废弃直接 REST 命令端点，所有命令必须经 partner key
    # 签名。Proxy 本地侦听 127.0.0.1:4443，自签 TLS。
    TESLA_VEHICLE_COMMAND_PROXY_URL: str = "https://127.0.0.1:4443"

    # AMap Web Service (高德 Web 服务) —— used by the backend for
    # geocoding / driving routes / nearby + along-route POI search.
    # Replaces Tencent map services so the project depends on a single
    # map vendor across iOS SDK + backend.
    AMAP_WEB_API_KEY: str = ""
    TESLA_CLIENT_ID: str = ""
    TESLA_CLIENT_SECRET: str = ""
    TESLA_TOKEN_ENCRYPTION_KEY: str = ""
    TESLA_REDIRECT_URI: str = "http://localhost:8000/api/v1/auth/tesla/callback"
    TESLA_ACCESS_TOKEN: str = ""
    TESLA_REFRESH_TOKEN: str = ""

    # Tencent Map API
    TENCENT_MAP_KEY: str = ""
    TENCENT_MAP_SECRET: str = ""
    # TENCENT_MAP_API_KEY removed in Phase 8.1 — backend migrated to AMap
    # Web Service. Kept as no-op str so Pydantic doesn't choke on
    # legacy `.env` entries while we phase them out, but no code
    # reads it any more.
    TENCENT_MAP_API_KEY: str = ""

    # WeChat
    WECHAT_APP_ID: str = ""
    WECHAT_APP_SECRET: str = ""

    # JWT
    JWT_SECRET_KEY: str = "jwt-secret-key"
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    JWT_REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # Automation polling loop. Every N seconds the backend pulls fresh
    # vehicle state for users that have both a Tesla token and a
    # registered APNs device, runs the rules engine, and fires pushes
    # on transitions. 0 disables the loop entirely (handy for tests
    # and migrations).
    AUTOMATION_POLL_INTERVAL_SECONDS: int = 300  # 5min default

    # Phase 6 — cron-only tick (replaces polling). Wakes the engine
    # periodically so cron-trigger rules (WEEKDAY_PREHEAT etc.) fire
    # on time. State-driven rules now evaluate from inside the
    # Telemetry consumer the moment a tel:* row gets a transition,
    # so this loop NO LONGER fetches /vehicle_data — pure in-memory
    # ticking. 30s default is generous; cron rules need ~1min
    # resolution at worst.
    AUTOMATION_CRON_TICK_SECONDS: int = 30

    # Phase 4 — Fleet Telemetry ingestion. fleet-telemetry runs as a
    # separate systemd unit on the same VM and publishes vehicle
    # state-change events on a ZMQ PUB socket. The backend consumer
    # SUBs to this address to write per-entity `since` timestamps into
    # AutomationState. Empty string disables the consumer (default —
    # local dev usually doesn't have fleet-telemetry running).
    TELEMETRY_ZMQ_ADDR: str = ""

    # APNs (Apple Push Notification service)
    # Path to .p8 auth key downloaded from developer.apple.com
    # (Keys → Apple Push Notifications service). Empty disables push.
    APNS_AUTH_KEY_PATH: str = ""
    APNS_KEY_ID: str = ""           # 10-char Key ID from Apple Developer
    APNS_TEAM_ID: str = ""          # 10-char Team ID (matches Xcode signing)
    APNS_BUNDLE_ID: str = "com.teplanner.ios"
    # "production" for TestFlight + App Store builds (which is the only
    # APNs environment Apple accepts for non-development certs);
    # "sandbox" only for dev builds with the development cert.
    APNS_ENVIRONMENT: str = "production"

    # F.1 — opt-in alembic auto-migrate on lifespan startup. Off in
    # production because alembic upgrade head can race with cron_tick
    # workers under uvicorn --reload, hanging the lifespan event and
    # 500'ing every write endpoint. Set "true" on dev or fresh boxes.
    DB_AUTO_MIGRATE: str = "false"

    # Phase E — JPush (Android via Mi/Huawei legacy/OPPO/vivo OEM
    # channels in mainland China). Empty disables; dispatcher logs
    # one notice and skips Android tokens.
    JPUSH_APP_KEY: str = ""
    JPUSH_MASTER_SECRET: str = ""
    JPUSH_API_URL: str = ""              # default: api.jpush.cn
    JPUSH_PRODUCTION: str = "false"      # "true" for prod APNs cert path

    # Phase E — Huawei Push Kit (HarmonyOS NEXT). Empty disables.
    HUAWEI_PUSH_APP_ID: str = ""
    HUAWEI_PUSH_APP_SECRET: str = ""
    HUAWEI_PUSH_TOKEN_URL: str = ""      # default: oauth-login.cloud.huawei.com
    HUAWEI_PUSH_API_URL: str = ""        # default: push-api.cloud.huawei.com

    # LLM (Phase 12 — natural-language automation / quick-action config).
    # The backend default goes through DeepSeek because it's mainland-
    # accessible, Chinese-strong, and ~50× cheaper than GPT-4o for the
    # short prompts this feature produces. Users can override via
    # user_settings (LLM_PROVIDER + LLM_API_KEY) using their own
    # OpenAI/Anthropic/Qwen key — BYOK keys are stored encrypted via
    # the existing TokenEncryption infra (same path as Tesla tokens).
    # Empty DEEPSEEK_API_KEY disables the server-default; users who
    # haven't set a BYOK key will get a clear "未配置 LLM 服务" error.
    LLM_DEFAULT_PROVIDER: str = "deepseek"
    DEEPSEEK_API_KEY: str = ""
    DEEPSEEK_BASE_URL: str = "https://api.deepseek.com"
    DEEPSEEK_MODEL: str = "deepseek-chat"

    # CORS
    CORS_ORIGINS: List[str] = ["*"]

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        # Pydantic v2 default rejects unknown env vars. Production
        # `.env` carries infra-only keys (OPENCLAW_HOOK_URL /
        # OPENCLAW_HOOK_TOKEN for the alert webhook) that the
        # backend code doesn't reference — silently ignore them so
        # an env-only addition doesn't crash startup.
        extra = "ignore"


settings = Settings()
