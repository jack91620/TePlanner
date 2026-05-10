
# VehicleStateResponse

Vehicle state response.

## Properties

Name | Type
------------ | -------------
`vehicle_id` | string
`display_name` | string
`state` | string
`battery_level` | number
`battery_range_km` | number
`usable_battery_level` | number
`charging_state` | string
`latitude` | number
`longitude` | number
`heading` | number
`speed` | number
`odometer_km` | number
`inside_temp` | number
`outside_temp` | number
`climate_keeper_mode` | number
`is_climate_on` | boolean
`sentry_mode_on` | boolean
`cabin_overheat_protection_on` | boolean
`charge_limit_soc` | number

## Example

```typescript
import type { VehicleStateResponse } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "vehicle_id": null,
  "display_name": null,
  "state": null,
  "battery_level": null,
  "battery_range_km": null,
  "usable_battery_level": null,
  "charging_state": null,
  "latitude": null,
  "longitude": null,
  "heading": null,
  "speed": null,
  "odometer_km": null,
  "inside_temp": null,
  "outside_temp": null,
  "climate_keeper_mode": null,
  "is_climate_on": null,
  "sentry_mode_on": null,
  "cabin_overheat_protection_on": null,
  "charge_limit_soc": null,
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


