
# GeocodeResponse

Geocode response.

## Properties

Name | Type
------------ | -------------
`latitude` | number
`longitude` | number
`address` | string
`formatted_address` | string

## Example

```typescript
import type { GeocodeResponse } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "latitude": null,
  "longitude": null,
  "address": null,
  "formatted_address": null,
} satisfies GeocodeResponse

console.log(example)

// Convert the instance to a JSON string
const exampleJSON: string = JSON.stringify(example)
console.log(exampleJSON)

// Parse the JSON string back to an object
const exampleParsed = JSON.parse(exampleJSON) as GeocodeResponse
console.log(exampleParsed)
```

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


