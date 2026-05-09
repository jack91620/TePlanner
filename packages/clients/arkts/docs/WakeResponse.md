
# WakeResponse

Wake response model.

## Properties

Name | Type
------------ | -------------
`message` | string
`state` | string
`vehicle_id` | string

## Example

```typescript
import type { WakeResponse } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "message": null,
  "state": null,
  "vehicle_id": null,
} satisfies WakeResponse

console.log(example)

// Convert the instance to a JSON string
const exampleJSON: string = JSON.stringify(example)
console.log(exampleJSON)

// Parse the JSON string back to an object
const exampleParsed = JSON.parse(exampleJSON) as WakeResponse
console.log(exampleParsed)
```

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


