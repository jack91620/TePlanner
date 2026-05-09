
# ChargingSessionResponse


## Properties

Name | Type
------------ | -------------
`client_session_id` | string
`duration_minutes` | number
`end_range_km` | number
`end_soc` | number
`ended_as_complete` | boolean
`ended_at` | Date
`energy_added_kwh` | number
`id` | number
`lat` | number
`lng` | number
`location_name` | string
`range_added_km` | number
`soc_delta` | number
`source` | string
`start_range_km` | number
`start_soc` | number
`started_at` | Date
`vehicle_id` | string

## Example

```typescript
import type { ChargingSessionResponse } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "client_session_id": null,
  "duration_minutes": null,
  "end_range_km": null,
  "end_soc": null,
  "ended_as_complete": null,
  "ended_at": null,
  "energy_added_kwh": null,
  "id": null,
  "lat": null,
  "lng": null,
  "location_name": null,
  "range_added_km": null,
  "soc_delta": null,
  "source": null,
  "start_range_km": null,
  "start_soc": null,
  "started_at": null,
  "vehicle_id": null,
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


