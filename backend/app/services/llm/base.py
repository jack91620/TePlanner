"""LLM provider abstraction.

Two scenarios produce a config:
- automation rule (trigger + action) — used by AutomationRule.spec_json
- quick action (capability + params) — used by HubAction in user_settings

Both share a single ``LLMConfigureResult`` envelope so the endpoint
doesn't branch.

Adapters (deepseek.py, openai.py, anthropic.py) implement `complete`
to make a synchronous JSON-producing call. Multi-turn / streaming
out of scope for v1 — we go single-turn with a forced-preview UX.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Any, Dict, Optional


class LLMError(Exception):
    """Adapter-agnostic failure surface. Endpoint maps to HTTP 502."""


@dataclass
class LLMConfigureResult:
    """What we return to iOS after running a configure call.

    Exactly one of ``automation_spec`` / ``quick_action`` is populated
    on success; if the LLM needs more info it emits an
    ``ask_clarification`` intent with the question text in
    ``clarification``.
    """

    intent: str  # "create_automation" | "create_quick_action" | "ask_clarification"
    automation_spec: Optional[Dict[str, Any]] = None
    quick_action: Optional[Dict[str, Any]] = None
    name: Optional[str] = None   # suggested rule / action name
    clarification: Optional[str] = None
    raw_response: Optional[str] = None  # debug aid; not surfaced to users
    summary: Optional[str] = None       # 1-line user-facing description


class LLMClient(ABC):
    """Provider-agnostic interface. Adapters wrap the underlying
    HTTP SDK + auth + model name + response_format quirks.
    """

    provider: str

    @abstractmethod
    async def complete_json(
        self,
        *,
        system: str,
        user: str,
        response_schema: Dict[str, Any],
        max_tokens: int = 1024,
    ) -> Dict[str, Any]:
        """One-shot JSON completion. ``response_schema`` is a JSON Schema
        the adapter passes via response_format=json_schema when the
        provider supports it; for adapters without native support the
        schema is also injected into the system prompt as a fallback
        constraint.

        Raises LLMError on network failure, schema-violation that the
        adapter retried 0 times to fix, or auth failure.
        """
        ...
