# /auth/tesla/unbind — clears TeslaToken + Vehicle rows for a user.
# Added 2026-05-11 after audit found iOS was calling 404 (handler
# was missing).
#
# Idempotent: returns 200 even when there's no binding to clear.
# Uses a fictional user_id so we don't disturb production data.

POST {{base_url}}/api/v1/auth/tesla/unbind?user_id=999999
HTTP 200
[Asserts]
jsonpath "$.success" == true
