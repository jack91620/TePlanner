# /api/v1/routes/charging-plan contract — Phase 8.2's 3rd step
# (greedy stop selection over the iOS-supplied candidate POIs).
#
# Public-by-design: iOS calls this after /routes/route returns
# the polyline, BEFORE login. Doesn't touch user data; only does
# geometric math.
#
# Happy-path: small polyline + 1 candidate POI on it. Should
# return a plan with at most 1 stop and a valid arrival SOC.

POST {{base_url}}/api/v1/routes/charging-plan
Content-Type: application/json
{
  "polyline": [
    [40.0668, 116.5896],
    [39.5000, 117.5000],
    [39.0000, 118.5000],
    [38.5000, 119.5000],
    [38.0000, 120.0000],
    [37.5000, 120.5000],
    [37.0000, 121.0000]
  ],
  "candidate_pois": [
    {"id": "test-1", "name": "途中超充", "latitude": 38.5, "longitude": 119.5, "address": "test address"}
  ],
  "initial_soc": 80,
  "vehicle_range_km": 500,
  "total_distance_km": 700,
  "min_arrival_soc": 20
}
HTTP 200
[Asserts]
# Shape: response should always have these fields, even when no
# stops are needed.
jsonpath "$.charging_stops" exists
jsonpath "$.num_charging_stops" >= 0
jsonpath "$.arrival_soc" exists
jsonpath "$.charging_duration_minutes" >= 0
jsonpath "$.warnings" exists


# Empty-polyline edge case: backend accepts and returns an empty
# plan rather than rejecting (defensible — "no route, no stops").
# Pin this so a future "tighten validation" change doesn't break
# the iOS fail-fast flow without us noticing.
POST {{base_url}}/api/v1/routes/charging-plan
Content-Type: application/json
{
  "polyline": [],
  "candidate_pois": [],
  "initial_soc": 80,
  "vehicle_range_km": 500,
  "total_distance_km": 700,
  "min_arrival_soc": 20
}
HTTP 200
[Asserts]
jsonpath "$.num_charging_stops" == 0
