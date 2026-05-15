# Phase A.3 + (future A.5) — /api/v1/user/* contract.
# All endpoints require auth; we test the unauth-401 shape only.

# 1. GET /user/scheduled-departure without auth → 401
GET {{base_url}}/api/v1/user/scheduled-departure
HTTP 401
[Asserts]
jsonpath "$.detail" exists


# 2. PUT /user/scheduled-departure without auth → 401
PUT {{base_url}}/api/v1/user/scheduled-departure
Content-Type: application/json
{
  "departure_at_utc": "2030-01-01T08:00:00",
  "lead_minutes": 15
}
HTTP 401


# 3. DELETE /user/scheduled-departure without auth → 401
DELETE {{base_url}}/api/v1/user/scheduled-departure
HTTP 401


# 4. Phase A.5 — GET /user/settings without auth → 401
GET {{base_url}}/api/v1/user/settings
HTTP 401


# 5. PUT /user/settings without auth → 401
PUT {{base_url}}/api/v1/user/settings
Content-Type: application/json
{
  "settings": {"any_key": 1}
}
HTTP 401


# 6. DELETE /user/me without auth → 401. Apple's 5.1.1(v) account-
# deletion endpoint; this contract pins the URL exists and is auth-
# gated, so the iOS Settings entry can never accidentally hit an
# unprotected route.
DELETE {{base_url}}/api/v1/user/me
HTTP 401
[Asserts]
jsonpath "$.detail" exists
