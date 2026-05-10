
# QueuedCommandResponse


## Properties

Name | Type
------------ | -------------
`id` | number
`capability` | string
`params` | object
`dispatch_policy` | string
`queued_at` | Date
`sent_at` | Date
`dropped_at` | Date
`ttl_seconds` | number
`error` | string
`status` | string

## Example

```typescript
import type { QueuedCommandResponse } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "id": null,
  "capability": null,
  "params": null,
  "dispatch_policy": null,
  "queued_at": null,
  "sent_at": null,
  "dropped_at": null,
  "ttl_seconds": null,
  "error": null,
  "status": null,
} satisfies QueuedCommandResponse

console.log(example)

// Convert the instance to a JSON string
const exampleJSON: string = JSON.stringify(example)
console.log(exampleJSON)

// Parse the JSON string back to an object
const exampleParsed = JSON.parse(exampleJSON) as QueuedCommandResponse
console.log(exampleParsed)
```

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


