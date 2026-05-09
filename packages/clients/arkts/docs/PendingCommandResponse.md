
# PendingCommandResponse


## Properties

Name | Type
------------ | -------------
`capability` | string
`confirmed_at` | Date
`dispatched_at` | Date
`expected_state` | object
`id` | number
`status` | string
`timed_out_at` | Date

## Example

```typescript
import type { PendingCommandResponse } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "capability": null,
  "confirmed_at": null,
  "dispatched_at": null,
  "expected_state": null,
  "id": null,
  "status": null,
  "timed_out_at": null,
} satisfies PendingCommandResponse

console.log(example)

// Convert the instance to a JSON string
const exampleJSON: string = JSON.stringify(example)
console.log(exampleJSON)

// Parse the JSON string back to an object
const exampleParsed = JSON.parse(exampleJSON) as PendingCommandResponse
console.log(exampleParsed)
```

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


