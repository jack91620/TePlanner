"""LLM-driven automation / quick-action config (Phase 12).

POST /llm/configure  — translate a user-typed sentence into a
                       previewable rule or quick action.

The endpoint deliberately does NOT save anything — it returns a
spec for iOS to render in a preview sheet. The user then confirms
via the existing /automations POST or /user/settings PUT (hub.actions).
This keeps the LLM-driven path on the same validation/save path as
manual config, so a hallucination that slips past our cheap check
still gets rejected at the real create site.
"""

from __future__ import annotations

import logging
from typing import Any, Dict, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user, get_db
from app.db.models import User
from app.services.llm import LLMError, get_client_for_user
from app.services.llm.prompt import build_response_schema, build_system_prompt
from app.services.llm.validator import (
    validate_automation_spec,
    validate_quick_action,
)

router = APIRouter()
logger = logging.getLogger(__name__)


class ConfigureRequest(BaseModel):
    """One user turn. We're single-turn for v1 — multi-turn would
    add history[] here, but for now each call is independent."""

    message: str = Field(..., min_length=1, max_length=500)
    target: str = Field(
        "auto",
        pattern="^(auto|automation|quick_action)$",
        description="auto = let the LLM pick. Use explicit value to constrain.",
    )


class ConfigureResponse(BaseModel):
    intent: str  # "create_automation" | "create_quick_action" | "ask_clarification"
    summary: str
    name: Optional[str] = None
    clarification: Optional[str] = None
    automation_spec: Optional[Dict[str, Any]] = None
    quick_action: Optional[Dict[str, Any]] = None
    # Validation errors from our registry-check pass. When present,
    # iOS should NOT offer "确认创建" — show the errors and let the
    # user rephrase. None / empty = ready to save.
    validation_errors: Optional[list[str]] = None


@router.post("/configure", response_model=ConfigureResponse)
async def configure(
    request: ConfigureRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Translate a Chinese sentence into a rule / quick-action spec.

    Strict: anything that doesn't round-trip through our capability
    registry comes back with `validation_errors` populated and no
    "this is ready" green light. iOS uses that flag to gate the
    "确认创建" button.
    """

    try:
        client = await get_client_for_user(db, user.id)
    except LLMError as exc:
        # Likely "no API key configured" — surface as 503 so iOS can
        # route to the BYOK config screen.
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        )

    system_prompt = build_system_prompt()
    user_prompt = _user_prompt_with_target(request.message, request.target)
    schema = build_response_schema()

    try:
        raw = await client.complete_json(
            system=system_prompt,
            user=user_prompt,
            response_schema=schema,
        )
    except LLMError as exc:
        logger.warning("llm.configure failed for user=%s: %s", user.id, exc)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"LLM 调用失败：{exc}",
        )

    intent = raw.get("intent")
    summary = raw.get("summary") or ""
    name = raw.get("name")
    clarification = raw.get("clarification")
    automation_spec = raw.get("automation_spec") if isinstance(raw.get("automation_spec"), dict) else None
    quick_action = raw.get("quick_action") if isinstance(raw.get("quick_action"), dict) else None

    if intent not in {"create_automation", "create_quick_action", "ask_clarification"}:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"LLM 返回未知 intent: {intent!r}",
        )

    errors: list[str] = []
    if intent == "create_automation":
        if not automation_spec:
            errors.append("LLM 没有返回 automation_spec")
        else:
            errors.extend(validate_automation_spec(automation_spec))
    elif intent == "create_quick_action":
        if not quick_action:
            errors.append("LLM 没有返回 quick_action")
        else:
            errors.extend(validate_quick_action(quick_action))

    return ConfigureResponse(
        intent=intent,
        summary=summary,
        name=name,
        clarification=clarification,
        automation_spec=automation_spec,
        quick_action=quick_action,
        validation_errors=errors or None,
    )


def _user_prompt_with_target(message: str, target: str) -> str:
    """The user-role message. We prepend a tiny instruction when the
    UI restricted the target so the LLM doesn't pick the wrong intent."""
    if target == "automation":
        return f"用户希望配置一条自动化规则。原话：\n\n{message}"
    if target == "quick_action":
        return f"用户希望配置一个快捷操作按钮。原话：\n\n{message}"
    return f"用户原话：\n\n{message}"
