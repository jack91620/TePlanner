# Pin the duration-unit fix: a Beijing → Suzhou route is ~1100 km
# and ~12 hours. Before the fix /routes/route returned 12 minutes
# because both `route_planner.py` and the map client divided the
# API's already-in-minutes `duration` by 60. The regression test
# below fails the moment the bug returns.
#
# Phase 8.2: testing /routes/route only — POI search moved to iOS
# AMap SDK, so the legacy /routes/plan one-shot endpoint was
# deleted. The greedy stop-selection over a synthetic POI list
# stays covered by Swift unit tests (RoutePreviewViewModelTests).

POST {{base_url}}/api/v1/routes/route
Content-Type: application/json
{
  "origin":      {"latitude": 40.0668, "longitude": 116.5896, "address": "Beijing"},
  "destination": {"latitude": 31.4428, "longitude": 120.5387, "address": "Suzhou"}
}
HTTP 200
[Asserts]
jsonpath "$.total_distance_km" > 1000
jsonpath "$.total_distance_km" < 1500
# Realistic highway driving for 1100km is 600+ minutes. The bug
# produced 12 (1100/60). Floor the assertion conservatively.
jsonpath "$.driving_duration_minutes" > 600
# Polyline must come back populated — the iOS app needs it for the
# AMap overlay AND for the SDK along-route POI search.
jsonpath "$.polyline" count > 10
# Destination + origin must come back with {lat, lng} keys — the iOS
# LocationDetail decoder reads `lat` / `lng`, not `latitude` /
# `longitude`. Build 43 shipped with the wrong keys, decoded
# silently to nil, and the multi-stop send-to-vehicle button fell
# back to "目的地缺少坐标" — pin the contract here.
jsonpath "$.destination.lat" exists
jsonpath "$.destination.lng" exists
jsonpath "$.origin.lat" exists
jsonpath "$.origin.lng" exists
