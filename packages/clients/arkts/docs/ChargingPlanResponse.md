
# ChargingPlanResponse

Output: just the charging-related fields. The iOS client merges this with the previously-fetched route data to produce its RoutePlanResponse-shape view model.

## Properties

Name | Type
------------ | -------------
`charging_stops` | [Array&lt;ChargingStopResponse&gt;](ChargingStopResponse.md)
`num_charging_stops` | number
`charging_duration_minutes` | number
`arrival_soc` | number
`warnings` | Array&lt;string&gt;

## Example

```typescript
import type { ChargingPlanResponse } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "charging_stops": null,
  "num_charging_stops": null,
  "charging_duration_minutes": null,
  "arrival_soc": null,
  "warnings": null,
} satisfies ChargingPlanResponse

console.log(example)

// Convert the instance to a JSON string
const exampleJSON: string = JSON.stringify(example)
console.log(exampleJSON)

// Parse the JSON string back to an object
const exampleParsed = JSON.parse(exampleJSON) as ChargingPlanResponse
console.log(exampleParsed)
```

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


