
# ChargingStation

Charging station model.

## Properties

Name | Type
------------ | -------------
`id` | string
`name` | string
`address` | string
`latitude` | number
`longitude` | number
`distance_km` | number
`operator` | string
`tel` | string
`power_kw` | number
`available_ports` | number
`total_ports` | number
`price_per_kwh` | number
`open_hours` | string
`category` | string
`type` | string

## Example

```typescript
import type { ChargingStation } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "id": null,
  "name": null,
  "address": null,
  "latitude": null,
  "longitude": null,
  "distance_km": null,
  "operator": null,
  "tel": null,
  "power_kw": null,
  "available_ports": null,
  "total_ports": null,
  "price_per_kwh": null,
  "open_hours": null,
  "category": null,
  "type": null,
} satisfies ChargingStation

console.log(example)

// Convert the instance to a JSON string
const exampleJSON: string = JSON.stringify(example)
console.log(exampleJSON)

// Parse the JSON string back to an object
const exampleParsed = JSON.parse(exampleJSON) as ChargingStation
console.log(exampleParsed)
```

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


