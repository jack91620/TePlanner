"""DeepSeek adapter — server-side default LLM provider.

Reasoning: mainland-accessible without a proxy, native Chinese
training data so capability names + Chinese descriptions in the
prompt actually parse, and ~0.001 RMB / request for the short
prompts this feature emits. Compatible with the OpenAI SDK
(same `/chat/completions` shape), so we use that for the wire
without dragging in an extra dependency.
"""

from __future__ import annotations

import json
import logging
from typing import Any, Dict, Optional

import httpx

from app.config import settings
from app.services.llm.base import LLMClient, LLMError

logger = logging.getLogger(__name__)


class DeepSeekClient(LLMClient):
    provider = "deepseek"

    def __init__(
        self,
        api_key: Optional[str] = None,
        base_url: Optional[str] = None,
        model: Optional[str] = None,
        timeout_s: float = 30.0,
    ):
        self._api_key = api_key or settings.DEEPSEEK_API_KEY
        self._base_url = base_url or settings.DEEPSEEK_BASE_URL
        self._model = model or settings.DEEPSEEK_MODEL
        self._timeout = timeout_s
        if not self._api_key:
            # Defer the error until call time — construction can happen
            # at import (factory cache) but the call site is the one
            # that knows whether the user has a BYOK key to fall back to.
            logger.debug("DeepSeekClient: no api_key set (server default unconfigured)")

    async def complete_json(
        self,
        *,
        system: str,
        user: str,
        response_schema: Dict[str, Any],
        max_tokens: int = 1024,
    ) -> Dict[str, Any]:
        if not self._api_key:
            raise LLMError(
                "DeepSeek API key not configured — set DEEPSEEK_API_KEY "
                "in the server .env, or configure your own provider in "
                "iOS Settings → LLM."
            )

        # DeepSeek supports OpenAI-style response_format = json_object
        # but NOT yet json_schema. So we attach the schema to the
        # system prompt as a hard constraint AND set response_format
        # to json_object so the model has to emit valid JSON.
        full_system = (
            f"{system}\n\n"
            "You MUST respond with a single valid JSON object. No "
            "markdown, no commentary, no code fence. The object MUST "
            "match this JSON Schema exactly:\n"
            f"```json\n{json.dumps(response_schema, ensure_ascii=False)}\n```"
        )
        body = {
            "model": self._model,
            "messages": [
                {"role": "system", "content": full_system},
                {"role": "user", "content": user},
            ],
            "response_format": {"type": "json_object"},
            "max_tokens": max_tokens,
            "temperature": 0.2,  # low — we want deterministic structured output
        }
        headers = {
            "Authorization": f"Bearer {self._api_key}",
            "Content-Type": "application/json",
        }

        async with httpx.AsyncClient(timeout=self._timeout) as http:
            try:
                resp = await http.post(
                    f"{self._base_url}/chat/completions",
                    json=body, headers=headers,
                )
            except httpx.HTTPError as exc:
                raise LLMError(f"DeepSeek request failed: {exc}") from exc

        if resp.status_code != 200:
            preview = resp.text[:300]
            raise LLMError(
                f"DeepSeek returned {resp.status_code}: {preview}"
            )

        data = resp.json()
        try:
            content = data["choices"][0]["message"]["content"]
        except (KeyError, IndexError) as exc:
            raise LLMError(f"DeepSeek response shape unexpected: {data}") from exc

        try:
            return json.loads(content)
        except json.JSONDecodeError as exc:
            # Even with response_format=json_object the model sometimes
            # wraps in ```json ... ```. Try the heuristic strip.
            stripped = content.strip()
            if stripped.startswith("```"):
                # Remove leading ```json or ``` and trailing ```.
                lines = [l for l in stripped.splitlines()
                         if not l.strip().startswith("```")]
                stripped = "\n".join(lines)
            try:
                return json.loads(stripped)
            except json.JSONDecodeError:
                raise LLMError(
                    f"DeepSeek returned non-JSON content: {content[:200]}"
                ) from exc
