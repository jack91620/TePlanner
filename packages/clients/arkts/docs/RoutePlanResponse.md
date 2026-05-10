
# RoutePlanResponse

Route planning response.

## Properties

Name | Type
------------ | -------------
`route_id` | number
`origin` | object
`destination` | object
`total_distance_km` | number
`total_duration_minutes` | number
`driving_duration_minutes` | number
`charging_duration_minutes` | number
`charging_stops` | [Array&lt;ChargingStopResponse&gt;](ChargingStopResponse.md)
`num_charging_stops` | number
`initial_soc` | number
`arrival_soc` | number
`polyline` | Array&lt;object&gt;
`warnings` | Array&lt;string&gt;

## Example

```typescript
import type { RoutePlanResponse } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "route_id": null,
  "origin": null,
  "destination": null,
  "total_distance_km": null,
  "total_duration_minutes": null,
  "driving_duration_minutes": null,
  "charging_duration_minutes": null,
  "charging_stops": null,
  "num_charging_stops": null,
  "initial_soc": null,
  "arrival_soc": null,
  "polyline": null,
  "warnings": null,
} satisfies RoutePlanResponse

console.log(example)

// Convert the instance to a JSON string
const exampleJSON: string = JSON.stringify(example)
console.log(exampleJSON)

// Parse the JSON string back to an object
const exampleParsed = JSON.parse(exampleJSON) as RoutePlanResponse
console.log(exampleParsed)
```

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


