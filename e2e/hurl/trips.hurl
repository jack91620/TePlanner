# Active-trip endpoints — contract test (auth-shape only).
#
# Why this file exists: a 2026-05-14 production audit found 0 rows in
# the `active_trip` table despite five phases of cron / SOC / off-route
# infrastructure being deployed. Root cause was iOS, not backend, but
# the contract was completely uncovered at this layer — letting the
# whole multi-stop trip endpoint disappear silently. These checks
# don't drive happy paths (would need real Tesla OAuth) but they
# permanently fence the URL shape, request payload, and auth gate.


# --- POST /trips/start — unauth requires token ---
POST {{base_url}}/api/v1/trips/start
Content-Type: application/json
{
  "vehicle_id": "anyvin",
  "stops": [
    {"latitude": 31.23, "longitude": 121.47, "kind": "charging", "name": "充电站"},
    {"latitude": 31.30, "longitude": 121.50, "kind": "final", "name": "终点"}
  ]
}
HTTP 401
[Asserts]
jsonpath "$.detail" exists


# --- POST /trips/start — empty body still hits auth before validation ---
POST {{base_url}}/api/v1/trips/start
HTTP 401
[Asserts]
jsonpath "$.detail" exists


# --- GET /trips/active — list current trip ---
GET {{base_url}}/api/v1/trips/active
HTTP 401
[Asserts]
jsonpath "$.detail" exists


# --- POST /trips/{id}/advance — push next stop ---
POST {{base_url}}/api/v1/trips/1/advance
HTTP 401
[Asserts]
jsonpath "$.detail" exists


# --- POST /trips/{id}/replan — server-side new stop list ---
POST {{base_url}}/api/v1/trips/1/replan
Content-Type: application/json
{
  "new_stops": [
    {"latitude": 31.30, "longitude": 121.50, "kind": "final"}
  ],
  "reason": "test"
}
HTTP 401
[Asserts]
jsonpath "$.detail" exists


# --- POST /trips/{id}/cancel ---
POST {{base_url}}/api/v1/trips/1/cancel
HTTP 401
[Asserts]
jsonpath "$.detail" exists
