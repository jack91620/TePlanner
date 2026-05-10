
# VehicleResponse

Vehicle response model.

## Properties

Name | Type
------------ | -------------
`id` | string
`vin` | string
`display_name` | string
`model` | string
`state` | string
`is_primary` | boolean

## Example

```typescript
import type { VehicleResponse } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "id": null,
  "vin": null,
  "display_name": null,
  "model": null,
  "state": null,
  "is_primary": null,
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


