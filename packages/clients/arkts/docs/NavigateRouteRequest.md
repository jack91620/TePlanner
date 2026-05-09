
# NavigateRouteRequest

Request to send route to vehicle.

## Properties

Name | Type
------------ | -------------
`vehicle_id` | string
`waypoints` | [Array&lt;LocationInput&gt;](LocationInput.md)

## Example

```typescript
import type { NavigateRouteRequest } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "vehicle_id": null,
  "waypoints": null,
} satisfies NavigateRouteRequest

console.log(example)

// Convert the instance to a JSON string
const exampleJSON: string = JSON.stringify(example)
console.log(exampleJSON)

// Parse the JSON string back to an object
const exampleParsed = JSON.parse(exampleJSON) as NavigateRouteRequest
console.log(exampleParsed)
```

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


