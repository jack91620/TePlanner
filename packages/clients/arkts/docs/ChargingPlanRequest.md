
# ChargingPlanRequest

Phase 8.2: greedy charging-stop selection over client-provided POIs. The iOS client gathers POIs via AMap SDK along-route search (proper road corridor) and posts them here.

## Properties

Name | Type
------------ | -------------
`candidate_pois` | [Array&lt;POIInput&gt;](POIInput.md)
`car_type` | string
`initial_soc` | number
`min_arrival_soc` | number
`polyline` | Array&lt;Array&lt;number&gt;&gt;
`total_distance_km` | number
`vehicle_range_km` | number

## Example

```typescript
import type { ChargingPlanRequest } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "candidate_pois": null,
  "car_type": null,
  "initial_soc": null,
  "min_arrival_soc": null,
  "polyline": null,
  "total_distance_km": null,
  "vehicle_range_km": null,
} satisfies ChargingPlanRequest

console.log(example)

// Convert the instance to a JSON string
const exampleJSON: string = JSON.stringify(example)
console.log(exampleJSON)

// Parse the JSON string back to an object
const exampleParsed = JSON.parse(exampleJSON) as ChargingPlanRequest
console.log(exampleParsed)
```

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


