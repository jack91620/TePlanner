# Phase 10.3.A — /api/v1/automations CRUD contract.
# Hits the deployed backend (api.teplanner.cloud); requires a JWT
# in $token. Most flows here run unauthenticated and expect 401 —
# we test the *shape* of the contract rather than the happy path,
# because Tesla-OAuth-bound auth is hard to script.
#
# Happy-path GET / POST / PUT / DELETE behavior is covered by the
# pytest suite in backend/tests/test_automation_rules.py and the
# iOS unit tests against the rule store.

# 1. Capabilities introspection — intentionally PUBLIC: the iOS
# visual builder calls this before the user has completed login,
# and the registry only leaks the static action vocabulary (no PII).
# Freeze the contract: shape + presence of the 5 known capabilities.
GET {{base_url}}/api/v1/automations/capabilities
HTTP 200
[Asserts]
jsonpath "$.capabilities" count >= 5
jsonpath "$.capabilities[?(@.id=='tesla.climate.set_keeper_mode')].safety_class" == "writable"
jsonpath "$.capabilities[?(@.id=='tesla.security.set_sentry')].safety_class" == "security"


# 2. Listing rules without auth → 401 (matches list_rules guard).
GET {{base_url}}/api/v1/automations/
HTTP 401
[Asserts]
jsonpath "$.detail" exists


# 3. Create rule without auth → 401 — and importantly, no rule
# is created (no spec_json appears in the response).
POST {{base_url}}/api/v1/automations/
Content-Type: application/json
{
  "name": "should-be-rejected",
  "enabled": true,
  "spec": {
    "kind": "campMode",
    "trigger": {
      "type": "state_duration",
      "entity": "vehicle.climate.keeper_mode",
      "equals": 3,
      "for_minutes": 1,
      "state_key": "test:start"
    },
    "actions_above": []
  }
}
HTTP 401
[Asserts]
jsonpath "$.spec_json" not exists


# 4. Update rule without auth → 401.
PUT {{base_url}}/api/v1/automations/some-id
Content-Type: application/json
{
  "enabled": false
}
HTTP 401


# 5. Delete rule without auth → 401.
DELETE {{base_url}}/api/v1/automations/some-id
HTTP 401


# 6. GET /state without auth → 401 (Phase 5 telemetry-since endpoint).
GET {{base_url}}/api/v1/automations/state
HTTP 401
[Asserts]
jsonpath "$.detail" exists


# 7. GET /vehicles/commands/pending without auth → 401
# (Phase 9 closed-loop confirmation endpoint).
GET {{base_url}}/api/v1/vehicles/commands/pending
HTTP 401
[Asserts]
jsonpath "$.detail" exists


# 8. GET /vehicles/commands/queued without auth → 401
# (Phase 10 sleep-aware command queue listing).
GET {{base_url}}/api/v1/vehicles/commands/queued
HTTP 401
[Asserts]
jsonpath "$.detail" exists


# 9. DELETE /vehicles/commands/queued/{id} without auth → 401.
DELETE {{base_url}}/api/v1/vehicles/commands/queued/1
HTTP 401
