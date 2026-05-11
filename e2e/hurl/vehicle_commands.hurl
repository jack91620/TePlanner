# Vehicle command endpoints — contract test (auth-shape only).
#
# All these write CommandPending rows + signed VCP commands; we
# can't drive them happy-path without a real Tesla OAuth token,
# but the 401-vs-404-vs-422 split tells us the route exists and
# auth guards are wired. If any of these starts returning 404,
# someone deleted the route — the iOS chip / AlertPill flows
# will silently break.
#
# Convention: anyvin is a literal placeholder string the routes
# accept (Pydantic validates the path param as str).


# --- tesla.security.door_lock ---
POST {{base_url}}/api/v1/vehicles/anyvin/lock
HTTP 401
[Asserts]
jsonpath "$.detail" exists


# --- tesla.security.door_unlock ---
POST {{base_url}}/api/v1/vehicles/anyvin/unlock
HTTP 401
[Asserts]
jsonpath "$.detail" exists


# --- tesla.security.set_sentry — needs `on` boolean ---
POST {{base_url}}/api/v1/vehicles/anyvin/sentry-mode
Content-Type: application/json
{ "on": true }
HTTP 401
[Asserts]
jsonpath "$.detail" exists


# --- tesla.climate.set_keeper_mode — needs `mode` 0/1/2/3 ---
POST {{base_url}}/api/v1/vehicles/anyvin/climate-keeper-mode
Content-Type: application/json
{ "mode": 0 }
HTTP 401
[Asserts]
jsonpath "$.detail" exists


# # --- tesla.climate.preheat — no body ---
POST {{base_url}}/api/v1/vehicles/anyvin/preheat
HTTP 401
[Asserts]
jsonpath "$.detail" exists


# --- tesla.charging.set_limit — needs `percent` 50..100 ---
POST {{base_url}}/api/v1/vehicles/anyvin/charge-limit
Content-Type: application/json
{ "percent": 80 }
HTTP 401
[Asserts]
jsonpath "$.detail" exists


# --- tesla.navigation.send (lat/lng GPS nav) ---
POST {{base_url}}/api/v1/vehicles/anyvin/navigate
Content-Type: application/json
{ "latitude": 39.9087, "longitude": 116.3974, "name": "测试目的地" }
HTTP 401
[Asserts]
jsonpath "$.detail" exists


# # Body validation guards run AFTER auth on these routes (FastAPI
# resolves dependencies before parsing the body), so an
# unauthenticated bad-body request returns 401 not 422. That's
# fine — the 401 already proves the route is registered and
# behind auth, which is what we need to pin here.
# Wire up integration tests with a real JWT when we have one to
# test the post-auth validators.
