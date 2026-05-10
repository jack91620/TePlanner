
# ChargingSessionResponse


## Properties

Name | Type
------------ | -------------
`id` | number
`vehicle_id` | string
`client_session_id` | string
`started_at` | Date
`ended_at` | Date
`start_soc` | number
`end_soc` | number
`start_range_km` | number
`end_range_km` | number
`energy_added_kwh` | number
`location_name` | string
`lat` | number
`lng` | number
`ended_as_complete` | boolean
`source` | string
`duration_minutes` | number
`range_added_km` | number
`soc_delta` | number

## Example

```typescript
import type { ChargingSessionResponse } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "id": null,
  "vehicle_id": null,
  "client_session_id": null,
  "started_at": null,
  "ended_at": null,
  "start_soc": null,
  "end_soc": null,
  "start_range_km": null,
  "end_range_km": null,
  "energy_added_kwh": null,
  "location_name": null,
  "lat": null,
  "lng": null,
  "ended_as_complete": null,
  "source": null,
  "duration_minutes": null,
  "range_added_km": null,
  "soc_delta": null,
} satisfies ChargingSessionResponse

console.log(example)

// Convert the instance to a JSON string
const exampleJSON: string = JSON.stringify(example)
console.log(exampleJSON)

// Parse the JSON string back to an object
const exampleParsed = JSON.parse(exampleJSON) as ChargingSessionResponse
console.log(exampleParsed)
```

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


