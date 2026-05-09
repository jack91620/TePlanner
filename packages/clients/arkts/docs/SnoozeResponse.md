
# SnoozeResponse


## Properties

Name | Type
------------ | -------------
`created_at` | Date
`reason` | string
`rule_id` | string
`snoozed_until_utc` | Date

## Example

```typescript
import type { SnoozeResponse } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "created_at": null,
  "reason": null,
  "rule_id": null,
  "snoozed_until_utc": null,
} satisfies SnoozeResponse

console.log(example)

// Convert the instance to a JSON string
const exampleJSON: string = JSON.stringify(example)
console.log(exampleJSON)

// Parse the JSON string back to an object
const exampleParsed = JSON.parse(exampleJSON) as SnoozeResponse
console.log(exampleParsed)
```

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


