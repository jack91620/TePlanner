"""AMap Web Service API integration.

Replaces the older `tencent_map` integration so we have a single map
vendor across iOS SDK + backend Web Service. The client mirrors the
Tencent client's method names and return shapes (Tencent-style dicts
with `title` / `_distance` / `location: {lat, lng}` etc.) so callers
don't have to change.
"""

from app.integrations.amap.web_client import AmapWebClient

__all__ = ["AmapWebClient"]
