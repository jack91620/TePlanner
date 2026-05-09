
# SnoozeRequest


## Properties

Name | Type
------------ | -------------
`hours` | number
`reason` | string
`until` | Date

## Example

```typescript
import type { SnoozeRequest } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "hours": null,
  "reason": null,
  "until": null,
} satisfies SnoozeRequest

console.log(example)

// Convert the instance to a JSON string
const exampleJSON: string = JSON.stringify(example)
console.log(exampleJSON)

// Parse the JSON string back to an object
const exampleParsed = JSON.parse(exampleJSON) as SnoozeRequest
console.log(exampleParsed)
```

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


