#!/usr/bin/env python3
"""Set TestFlight "What to Test" release notes on a freshly-uploaded
build via App Store Connect API.

`xcrun altool --upload-app` ships the IPA but can't attach release
notes — that's a different API (`betaBuildLocalizations`). This
script polls until the build appears in ASC (Apple processes the
upload in 5-30 min) and posts the notes for the requested locale.

Env / args:
  - ASC_API_KEY_ID       (from `make upload-testflight`'s .env)
  - ASC_API_KEY_ISSUER
  - ASC_PRIVATE_KEY_PATH default ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8
  - ASC_APP_ID           the numeric App ID (one-time setup in .env)
  - --build 38           the CFBundleVersion we just uploaded
  - --notes path/to/build_38.md
  - --locale zh-Hans     default; "What to Test" stored per locale

Idempotent: if a localization already exists for this build+locale
it's PATCHed; else POSTed.
"""
import argparse
import json
import os
import sys
import time
import urllib.request
import urllib.error
from pathlib import Path
from typing import Optional

try:
    import jwt   # PyJWT
except ImportError:
    sys.stderr.write(
        "PyJWT missing. Install: /opt/homebrew/opt/openjdk@21/bin/.. (use brew python)\n"
        "  pip3 install pyjwt cryptography\n"
    )
    sys.exit(2)


API = "https://api.appstoreconnect.apple.com"


def mint_token(key_id: str, issuer: str, key_path: Path) -> str:
    """ES256-signed JWT — 20 minute TTL, audience = appstoreconnect-v1."""
    with key_path.open("rb") as f:
        private_key = f.read()
    now = int(time.time())
    return jwt.encode(
        {
            "iss": issuer,
            "iat": now,
            "exp": now + 20 * 60,
            "aud": "appstoreconnect-v1",
        },
        private_key,
        algorithm="ES256",
        headers={"kid": key_id, "typ": "JWT"},
    )


def api_call(method: str, path: str, token: str, body: Optional[dict] = None) -> dict:
    """Thin urllib wrapper that raises on >=400 with the error JSON."""
    url = API + path
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, method=method, data=data)
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        raise SystemExit(f"ASC API {method} {path} → {e.code}: {body}")


def find_build(app_id: str, build_version: str, token: str) -> Optional[str]:
    """Look up the build's resource id by CFBundleVersion + app id.
    Returns None if not visible yet (Apple still processing)."""
    qs = (
        f"?filter[app]={app_id}"
        f"&filter[version]={build_version}"
        f"&sort=-uploadedDate"
        f"&limit=10"
    )
    resp = api_call("GET", f"/v1/builds{qs}", token)
    rows = resp.get("data", [])
    # Pick the most recently uploaded build matching the version.
    if not rows:
        return None
    return rows[0]["id"]


def find_localization(build_id: str, locale: str, token: str) -> Optional[str]:
    """Return the localization id for this build+locale if it
    already exists, else None."""
    resp = api_call(
        "GET",
        f"/v1/builds/{build_id}/betaBuildLocalizations",
        token,
    )
    for row in resp.get("data", []):
        if row.get("attributes", {}).get("locale") == locale:
            return row["id"]
    return None


def set_notes(build_id: str, locale: str, notes: str, token: str) -> None:
    existing = find_localization(build_id, locale, token)
    if existing:
        body = {
            "data": {
                "type": "betaBuildLocalizations",
                "id": existing,
                "attributes": {"whatsNew": notes},
            }
        }
        api_call("PATCH", f"/v1/betaBuildLocalizations/{existing}", token, body)
        print(f"updated localization {existing} for locale={locale}")
    else:
        body = {
            "data": {
                "type": "betaBuildLocalizations",
                "attributes": {"locale": locale, "whatsNew": notes},
                "relationships": {
                    "build": {"data": {"type": "builds", "id": build_id}},
                },
            }
        }
        resp = api_call("POST", "/v1/betaBuildLocalizations", token, body)
        new_id = resp.get("data", {}).get("id", "?")
        print(f"created localization {new_id} for locale={locale}")


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--build", required=True, help="CFBundleVersion, e.g. 38")
    p.add_argument("--notes", required=True, type=Path, help="path to markdown notes")
    p.add_argument("--locale", default="zh-Hans")
    p.add_argument(
        "--wait-minutes", type=int, default=30,
        help="how long to poll for the build to appear in ASC",
    )
    p.add_argument("--app-id", default=os.environ.get("ASC_APP_ID"))
    args = p.parse_args()

    key_id = os.environ.get("ASC_API_KEY_ID")
    issuer = os.environ.get("ASC_API_KEY_ISSUER")
    if not key_id or not issuer:
        sys.exit("ASC_API_KEY_ID / ASC_API_KEY_ISSUER required (.env)")
    if not args.app_id:
        sys.exit("ASC_APP_ID required (env or --app-id)")
    key_path = Path(os.environ.get(
        "ASC_PRIVATE_KEY_PATH",
        f"{Path.home()}/.appstoreconnect/private_keys/AuthKey_{key_id}.p8",
    ))
    if not key_path.exists():
        sys.exit(f"private key not found at {key_path}")

    notes = args.notes.read_text(encoding="utf-8").rstrip()
    if not notes:
        sys.exit(f"notes file is empty: {args.notes}")
    if len(notes) > 4000:
        sys.exit(f"notes too long: {len(notes)} > 4000 (ASC limit)")

    token = mint_token(key_id, issuer, key_path)

    deadline = time.time() + args.wait_minutes * 60
    build_id = None
    poll_seconds = 30
    while time.time() < deadline:
        build_id = find_build(args.app_id, args.build, token)
        if build_id:
            print(f"build {args.build} → {build_id}")
            break
        remaining = int(deadline - time.time())
        print(f"build {args.build} not yet visible in ASC, retry in {poll_seconds}s "
              f"(remaining {remaining // 60}m)")
        time.sleep(poll_seconds)
        # Refresh token in case we exceed 20-min TTL.
        token = mint_token(key_id, issuer, key_path)
    if not build_id:
        sys.exit(
            f"build {args.build} did not appear in ASC within "
            f"{args.wait_minutes}m. Try `--wait-minutes 60` or "
            f"set notes manually at https://appstoreconnect.apple.com")

    set_notes(build_id, args.locale, notes, token)
    print("✓ release notes attached")
    return 0


if __name__ == "__main__":
    sys.exit(main())
