# Backend liveness — fastest possible smoke test.
# Run: `hurl --test --variable base_url=https://api.teplanner.cloud e2e/hurl/health.hurl`

GET {{base_url}}/health
HTTP 200
[Asserts]
jsonpath "$.status" == "healthy"

GET {{base_url}}/
HTTP 200
[Asserts]
jsonpath "$.name" == "TePlanner"
jsonpath "$.status" == "running"
