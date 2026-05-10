"""Logging handler that forwards ERROR/CRITICAL records to OpenClaw.

The handler POSTs to OpenClaw's `/hooks/wake` endpoint, which enqueues a
system event for the main agent session. The agent then forwards the
alert to Jack over WeChat. Designed to be fire-and-forget so backend
request handling is never blocked by alert delivery.
"""

from __future__ import annotations

import json
import logging
import threading
import time
import urllib.request
from typing import Optional

DEFAULT_DEDUP_WINDOW_SECONDS = 3600
DEFAULT_TIMEOUT_SECONDS = 3.0
MAX_RECENT_SIGNATURES = 256
SIGNATURE_BODY_LEN = 120


class OpenClawAlertHandler(logging.Handler):
    """Forward ERROR+ logs to OpenClaw via HTTP webhook.

    Dedup window prevents log storms from flooding the chat: the same
    (logger, funcName, message-prefix) signature is sent at most once
    per `dedup_window_seconds` (default 1h).
    """

    def __init__(
        self,
        url: str,
        token: str,
        dedup_window_seconds: int = DEFAULT_DEDUP_WINDOW_SECONDS,
        timeout_seconds: float = DEFAULT_TIMEOUT_SECONDS,
        source: str = "teplanner-backend",
    ) -> None:
        super().__init__(level=logging.ERROR)
        self._url = url.rstrip("/") + "/agent"
        self._token = token
        self._dedup_window = dedup_window_seconds
        self._timeout = timeout_seconds
        self._source = source
        self._channel = "openclaw-weixin"
        self._to = "o9cq8048r-As7icF_Ty1Q2INOYe0@im.wechat"
        self._recent: dict[str, float] = {}
        self._lock = threading.Lock()

    def emit(self, record: logging.LogRecord) -> None:
        try:
            signature = self._signature(record)
            now = time.monotonic()
            with self._lock:
                last = self._recent.get(signature, 0.0)
                if now - last < self._dedup_window:
                    return
                self._recent[signature] = now
                if len(self._recent) > MAX_RECENT_SIGNATURES:
                    cutoff = now - self._dedup_window
                    self._recent = {
                        sig: ts for sig, ts in self._recent.items() if ts >= cutoff
                    }

            text = self._format_text(record)
            threading.Thread(
                target=self._post,
                args=(text,),
                name="openclaw-alert",
                daemon=True,
            ).start()
        except Exception:
            self.handleError(record)

    @staticmethod
    def _signature(record: logging.LogRecord) -> str:
        body = str(record.msg)[:SIGNATURE_BODY_LEN]
        return f"{record.name}|{record.funcName}|{record.levelname}|{body}"

    def _format_text(self, record: logging.LogRecord) -> str:
        message = record.getMessage()
        if len(message) > 800:
            message = message[:800] + "…"
        return (
            f"[{self._source}] {record.levelname} {record.name}\n"
            f"{message}"
        )

    def _post(self, text: str) -> None:
        payload = json.dumps({
            "message": text,
            "name": "teplanner-alert",
            "deliver": True,
            "channel": self._channel,
            "to": self._to,
        }).encode("utf-8")
        request = urllib.request.Request(
            self._url,
            data=payload,
            headers={
                "Authorization": f"Bearer {self._token}",
                "Content-Type": "application/json",
            },
            method="POST",
        )
        try:
            urllib.request.urlopen(request, timeout=self._timeout).close()
        except Exception:
            pass


def install(
    url: Optional[str],
    token: Optional[str],
    *,
    source: str = "teplanner-backend",
) -> Optional[OpenClawAlertHandler]:
    """Attach an OpenClawAlertHandler to the root logger if configured.

    Returns the installed handler, or None if URL/token are missing.
    Safe to call multiple times — re-installs replace any previous
    handler with the same source tag.
    """
    if not url or not token:
        return None
    root = logging.getLogger()
    for existing in list(root.handlers):
        if isinstance(existing, OpenClawAlertHandler) and existing._source == source:
            root.removeHandler(existing)
    handler = OpenClawAlertHandler(url=url, token=token, source=source)
    root.addHandler(handler)
    return handler
