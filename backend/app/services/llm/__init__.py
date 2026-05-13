"""LLM-driven automation / quick-action config (Phase 12).

User says "下班后预热，到家提醒充到 80%" → we ask an LLM to translate
that into a typed rule spec or quick-action recipe → server-side
validator rejects anything that doesn't round-trip through the
real capability registry → iOS shows a preview → user confirms.

Architecture decisions:
- *Direct SDK*, not MCP — we own both client and server; MCP would
  add a serialization layer with zero benefit. The LLM call is an
  internal implementation detail.
- *Provider abstraction*: DeepSeek as the server-side default
  (mainland-accessible, Chinese-strong, cheap). Users can BYOK
  for OpenAI / Anthropic / Qwen. Same `LLMClient` interface across
  adapters so the endpoint doesn't care which one.
- *Structured output*: we always ask the LLM for JSON matching a
  fixed schema. response_format with json_schema in DeepSeek/OpenAI;
  prompt-engineered fallback for adapters without native support.
- *Validation is non-negotiable*: an LLM hallucination that produces
  an invalid capability id or out-of-range params would silently
  refuse to fire at runtime. We reject before returning to the
  client so the user sees a friendly error.
"""

from app.services.llm.base import LLMClient, LLMConfigureResult, LLMError
from app.services.llm.deepseek import DeepSeekClient
from app.services.llm.factory import get_client_for_user

__all__ = [
    "LLMClient",
    "LLMConfigureResult",
    "LLMError",
    "DeepSeekClient",
    "get_client_for_user",
]
