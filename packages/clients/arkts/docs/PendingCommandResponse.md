
# PendingCommandResponse


## Properties

Name | Type
------------ | -------------
`id` | number
`capability` | string
`expected_state` | object
`dispatched_at` | Date
`confirmed_at` | Date
`timed_out_at` | Date
`status` | string

## Example

```typescript
import type { PendingCommandResponse } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "id": null,
  "capability": null,
  "expected_state": null,
  "dispatched_at": null,
  "confirmed_at": null,
  "timed_out_at": null,
  "status": null,
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


