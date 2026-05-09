
# ChargingStation

Charging station model.

## Properties

Name | Type
------------ | -------------
`address` | string
`available_ports` | number
`category` | string
`distance_km` | number
`id` | string
`latitude` | number
`longitude` | number
`name` | string
`open_hours` | string
`operator` | string
`power_kw` | number
`price_per_kwh` | number
`tel` | string
`total_ports` | number
`type` | string

## Example

```typescript
import type { ChargingStation } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "address": null,
  "available_ports": null,
  "category": null,
  "distance_km": null,
  "id": null,
  "latitude": null,
  "longitude": null,
  "name": null,
  "open_hours": null,
  "operator": null,
  "power_kw": null,
  "price_per_kwh": null,
  "tel": null,
  "total_ports": null,
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


