# /api/v1/shares — cross-platform share-code contract.
# All endpoints require auth; we test the unauth-401 shape only here.
# Functional behavior (round-trip, expiry, revoke, version gate)
# lives in backend/tests/test_shares.py.

# 1. POST /shares without auth → 401
POST {{base_url}}/api/v1/shares
Content-Type: application/json
{
  "share_type": "action",
  "payload": {"name": "x", "icon": "lock", "tint": "blue", "steps": []}
}
HTTP 401
[Asserts]
jsonpath "$.detail" exists


# 2. GET /shares/{code} without auth → 401
GET {{base_url}}/api/v1/shares/ABCDEF
HTTP 401


# 3. DELETE /shares/{code} without auth → 401
DELETE {{base_url}}/api/v1/shares/ABCDEF
HTTP 401


# 4. GET /shares/mine without auth → 401
GET {{base_url}}/api/v1/shares/mine
HTTP 401
