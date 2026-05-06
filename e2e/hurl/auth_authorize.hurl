# /auth/tesla/authorize is the iOS app's entry point. It must
# return a Tesla auth URL with the configured client_id (not empty)
# and a fresh state token.

GET {{base_url}}/api/v1/auth/tesla/authorize
HTTP 200
[Asserts]
jsonpath "$.url" matches "^https://auth\\.tesla\\.cn/oauth2/v3/authorize"
jsonpath "$.url" contains "client_id="
# Reject the failure mode where the deployed backend has an empty
# client_id (which still 200s but every login attempt fails server-side).
jsonpath "$.url" not contains "client_id=&"
jsonpath "$.state" exists
jsonpath "$.user_id" exists
