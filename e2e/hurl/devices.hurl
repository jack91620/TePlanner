# Phase 10.0 / 10.1 — /api/v1/devices CRUD contract.
# Same approach as automations.hurl: validate auth gating + request
# shape; the happy path needs a real JWT and Tesla-bound user, which
# is covered by manual E2E once a device token actually exists.

# 1. /devices/register requires auth.
POST {{base_url}}/api/v1/devices/register
Content-Type: application/json
{
  "token": "AAAA1111BBBB2222CCCC3333",
  "bundle_id": "com.teplanner.ios"
}
HTTP 401
[Asserts]
jsonpath "$.detail" exists


# 2. /devices/test-push requires auth.
POST {{base_url}}/api/v1/devices/test-push
Content-Type: application/json
{
  "title": "Hurl smoke test",
  "body": "Should never fire because we have no auth"
}
HTTP 401


# 3. /devices/run-automation-tick requires auth.
POST {{base_url}}/api/v1/devices/run-automation-tick
HTTP 401


# 4. Phase E — /devices/register accepts platform=jpush + provider_token.
# Still 401 (no auth), but Pydantic must accept the new fields without 422.
POST {{base_url}}/api/v1/devices/register
Content-Type: application/json
{
  "token": "AAAA1111BBBB2222CCCC3333",
  "platform": "jpush",
  "provider_token": "rid-12345abcdef",
  "bundle_id": "com.teplanner.android"
}
HTTP 401


# 5. Phase E — /devices/register accepts platform=harmony.
POST {{base_url}}/api/v1/devices/register
Content-Type: application/json
{
  "token": "hms-token-xyz-12345",
  "platform": "harmony",
  "provider_token": "hms-rid-xyz789"
}
HTTP 401


# 6. Phase E — unknown platform (without auth) still 401, NOT 400 —
# Pydantic accepts the field shape; the 400 path is gated behind auth.
POST {{base_url}}/api/v1/devices/register
Content-Type: application/json
{
  "token": "AAAA1111BBBB2222CCCC3333",
  "platform": "fcm"
}
HTTP 401
