
# VehicleStateResponse

Vehicle state response.

## Properties

Name | Type
------------ | -------------
`battery_level` | number
`battery_range_km` | number
`cabin_overheat_protection_on` | boolean
`charge_limit_soc` | number
`charging_state` | string
`climate_keeper_mode` | number
`display_name` | string
`heading` | number
`inside_temp` | number
`is_climate_on` | boolean
`latitude` | number
`longitude` | number
`odometer_km` | number
`outside_temp` | number
`sentry_mode_on` | boolean
`speed` | number
`state` | string
`usable_battery_level` | number
`vehicle_id` | string

## Example

```typescript
import type { VehicleStateResponse } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "battery_level": null,
  "battery_range_km": null,
  "cabin_overheat_protection_on": null,
  "charge_limit_soc": null,
  "charging_state": null,
  "climate_keeper_mode": null,
  "display_name": null,
  "heading": null,
  "inside_temp": null,
  "is_climate_on": null,
  "latitude": null,
  "longitude": null,
  "odometer_km": null,
  "outside_temp": null,
  "sentry_mode_on": null,
  "speed": null,
  "state": null,
  "usable_battery_level": null,
  "vehicle_id": null,
} satisfies VehicleStateResponse

console.log(example)

// Convert the instance to a JSON string
const exampleJSON: string = JSON.stringify(example)
console.log(exampleJSON)

// Parse the JSON string back to an object
const exampleParsed = JSON.parse(exampleJSON) as VehicleStateResponse
console.log(exampleParsed)
```

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


