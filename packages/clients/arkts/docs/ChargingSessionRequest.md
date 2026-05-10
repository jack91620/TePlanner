
# ChargingSessionRequest


## Properties

Name | Type
------------ | -------------
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

## Example

```typescript
import type { ChargingSessionRequest } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
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
} satisfies ChargingSessionRequest

console.log(example)

// Convert the instance to a JSON string
const exampleJSON: string = JSON.stringify(example)
console.log(exampleJSON)

// Parse the JSON string back to an object
const exampleParsed = JSON.parse(exampleJSON) as ChargingSessionRequest
console.log(exampleParsed)
```

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


