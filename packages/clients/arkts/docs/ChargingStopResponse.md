
# ChargingStopResponse

Charging stop in route.

## Properties

Name | Type
------------ | -------------
`address` | string
`arrival_soc` | number
`charging_duration_minutes` | number
`departure_soc` | number
`distance_from_start_km` | number
`latitude` | number
`longitude` | number
`name` | string
`operator` | string
`station_id` | string

## Example

```typescript
import type { ChargingStopResponse } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "address": null,
  "arrival_soc": null,
  "charging_duration_minutes": null,
  "departure_soc": null,
  "distance_from_start_km": null,
  "latitude": null,
  "longitude": null,
  "name": null,
  "operator": null,
  "station_id": null,
} satisfies ChargingStopResponse

console.log(example)

// Convert the instance to a JSON string
const exampleJSON: string = JSON.stringify(example)
console.log(exampleJSON)

// Parse the JSON string back to an object
const exampleParsed = JSON.parse(exampleJSON) as ChargingStopResponse
console.log(exampleParsed)
```

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


