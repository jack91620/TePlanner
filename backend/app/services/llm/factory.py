"""Pick the right LLM client for a request.

Resolution order:
1. User has stored BYOK provider + key in user_settings → use that
2. Otherwise → server default (DeepSeek with DEEPSEEK_API_KEY)
3. If neither is configured → raise LLMError, surfaced as 503

BYOK keys are encrypted at rest via the existing TokenEncryption
infra (same path Tesla tokens use). The factory decrypts on read.
"""

from __future__ import annotations

import json
import logging
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.core.security import TokenEncryption
from app.db.models import UserSetting
from app.services.llm.base import LLMClient, LLMError
from app.services.llm.deepseek import DeepSeekClient

logger = logging.getLogger(__name__)


_LLM_PROVIDER_KEY = "llm.provider"
_LLM_API_KEY_KEY = "llm.api_key_encrypted"
_LLM_BASE_URL_KEY = "llm.base_url"


async def get_client_for_user(
    db: AsyncSession,
    user_id: int,
) -> LLMClient:
    """Resolve which LLM client to use for this user. May fall back
    to server default. Raises LLMError when nothing is configured."""

    user_bag = await _load_llm_settings(db, user_id)
    user_provider = user_bag.get(_LLM_PROVIDER_KEY)
    user_key_enc = user_bag.get(_LLM_API_KEY_KEY)
    user_base = user_bag.get(_LLM_BASE_URL_KEY)

    if user_provider and user_key_enc:
        try:
            key = TokenEncryption().decrypt(user_key_enc)
        except Exception as exc:  # noqa: BLE001
            logger.warning(
                "user=%s llm.api_key_encrypted decrypt failed: %s — "
                "falling back to server default",
                user_id, exc,
            )
        else:
            client = _build_byok_client(user_provider, key, user_base)
            if client is not None:
                return client

    # Server default
    if not settings.DEEPSEEK_API_KEY:
        raise LLMError(
            "未配置 LLM 服务。请在 设置 → 智能配置 里填一个 API key，"
            "或联系运营开启默认 LLM。"
        )
    return DeepSeekClient()


async def _load_llm_settings(
    db: AsyncSession, user_id: int,
) -> dict[str, str]:
    """Pull the three llm.* keys out of user_settings in one query."""
    rows = (await db.execute(
        select(UserSetting).where(
            UserSetting.user_id == user_id,
            UserSetting.key.in_([
                _LLM_PROVIDER_KEY, _LLM_API_KEY_KEY, _LLM_BASE_URL_KEY,
            ]),
        )
    )).scalars().all()
    out: dict[str, str] = {}
    for row in rows:
        try:
            out[row.key] = json.loads(row.value_json)
        except (json.JSONDecodeError, TypeError):
            # user_setting.value_json may have been stored unwrapped
            # (older bug); fall back to the raw string.
            out[row.key] = row.value_json
    return out


def _build_byok_client(
    provider: str, api_key: str, base_url: Optional[str],
) -> Optional[LLMClient]:
    """Construct a client for a user-supplied provider. Returns None
    on unknown provider (caller falls back to server default with a
    log line)."""
    provider = provider.lower().strip()
    if provider == "deepseek":
        return DeepSeekClient(api_key=api_key, base_url=base_url)
    # OpenAI / Anthropic / Qwen adapters can plug in here as we ship
    # them. Until then, fall back to the server default with a log.
    logger.info("BYOK provider %r not yet supported — falling back", provider)
    return None
