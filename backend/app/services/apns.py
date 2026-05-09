"""Phase E re-home shim — `apns_client` moved to
`app.services.push.apns`. Existing imports keep working through this
file; a future cleanup pass replaces them with the new path.
"""

from app.services.push.apns import APNsClient, apns_client  # noqa: F401
