"""Phase E — push notification multiplex.

The dispatcher fans alerts across per-platform clients so the
automation engine doesn't need to know whether a user is on iOS,
Android, or HarmonyOS. Each per-platform client is the same minimal
contract: `async send(provider_token, title, body, **kwargs) -> bool`.
"""

from app.services.push.dispatcher import (  # noqa: F401
    PushDispatcher,
    push_dispatcher,
)
