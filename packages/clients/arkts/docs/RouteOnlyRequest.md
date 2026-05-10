
# RouteOnlyRequest

Phase 8.2: route metadata only (no charging plan).  Used by the iOS client to get the polyline first, then run AMap SDK along-route POI search locally, then post the candidate POIs back via /charging-plan to compute the greedy charging stops.

## Properties

Name | Type
------------ | -------------
`origin` | [LocationInput](LocationInput.md)
`destination` | [LocationInput](LocationInput.md)

## Example

```typescript
import type { RouteOnlyRequest } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "origin": null,
  "destination": null,
} satisfies RouteOnlyRequest

console.log(example)

// Convert the instance to a JSON string
const exampleJSON: string = JSON.stringify(example)
console.log(exampleJSON)

// Parse the JSON string back to an object
const exampleParsed = JSON.parse(exampleJSON) as RouteOnlyRequest
console.log(exampleParsed)
```

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


