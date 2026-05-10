
# ChargingStopResponse

Charging stop in route.

## Properties

Name | Type
------------ | -------------
`station_id` | string
`name` | string
`latitude` | number
`longitude` | number
`address` | string
`operator` | string
`distance_from_start_km` | number
`arrival_soc` | number
`departure_soc` | number
`charging_duration_minutes` | number

## Example

```typescript
import type { ChargingStopResponse } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "station_id": null,
  "name": null,
  "latitude": null,
  "longitude": null,
  "address": null,
  "operator": null,
  "distance_from_start_km": null,
  "arrival_soc": null,
  "departure_soc": null,
  "charging_duration_minutes": null,
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


