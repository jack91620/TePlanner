# Pin the duration-unit fix: a Beijing → Suzhou route is ~1100 km
# and ~12 hours. Before the fix /routes/plan returned 12 minutes
# because both `route_planner.py` and `tencent_map/client.py`
# divided the API's already-in-minutes `duration` by 60. The
# regression test below fails the moment the bug returns.

POST {{base_url}}/api/v1/routes/plan
Content-Type: application/json
{
  "origin":      {"latitude": 40.0668, "longitude": 116.5896, "address": "Beijing"},
  "destination": {"latitude": 31.4428, "longitude": 120.5387, "address": "Suzhou"},
  "current_soc": 80
}
HTTP 200
[Asserts]
jsonpath "$.total_distance_km" > 1000
jsonpath "$.total_distance_km" < 1500
# Realistic highway driving for 1100km is 600+ minutes. The bug
# produced 12 (1100/60). Floor the assertion conservatively.
jsonpath "$.total_duration_minutes" > 600
jsonpath "$.driving_duration_minutes" > 600
jsonpath "$.initial_soc" == 80
# Polyline must come back populated — the iOS app needs it for the
# AMap overlay.
jsonpath "$.polyline" count > 10
