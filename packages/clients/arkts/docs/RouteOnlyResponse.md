
# RouteOnlyResponse

Lightweight response — polyline + raw distance/duration only.

## Properties

Name | Type
------------ | -------------
`origin` | object
`destination` | object
`total_distance_km` | number
`driving_duration_minutes` | number
`polyline` | Array&lt;object&gt;

## Example

```typescript
import type { RouteOnlyResponse } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "origin": null,
  "destination": null,
  "total_distance_km": null,
  "driving_duration_minutes": null,
  "polyline": null,
} satisfies RouteOnlyResponse

console.log(example)

// Convert the instance to a JSON string
const exampleJSON: string = JSON.stringify(example)
console.log(exampleJSON)

// Parse the JSON string back to an object
const exampleParsed = JSON.parse(exampleJSON) as RouteOnlyResponse
console.log(exampleParsed)
```

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


