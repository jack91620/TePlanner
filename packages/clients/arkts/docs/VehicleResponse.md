
# VehicleResponse

Vehicle response model.

## Properties

Name | Type
------------ | -------------
`display_name` | string
`id` | string
`is_primary` | boolean
`model` | string
`state` | string
`vin` | string

## Example

```typescript
import type { VehicleResponse } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "display_name": null,
  "id": null,
  "is_primary": null,
  "model": null,
  "state": null,
  "vin": null,
} satisfies VehicleResponse

console.log(example)

// Convert the instance to a JSON string
const exampleJSON: string = JSON.stringify(example)
console.log(exampleJSON)

// Parse the JSON string back to an object
const exampleParsed = JSON.parse(exampleJSON) as VehicleResponse
console.log(exampleParsed)
```

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


