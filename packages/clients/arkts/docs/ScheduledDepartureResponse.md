
# ScheduledDepartureResponse


## Properties

Name | Type
------------ | -------------
`id` | number
`departure_at_utc` | Date
`lead_minutes` | number
`label` | string
`vehicle_id` | string
`target_charge_soc` | number
`enabled` | boolean
`fire_at_utc` | Date
`created_at` | Date
`updated_at` | Date

## Example

```typescript
import type { ScheduledDepartureResponse } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "id": null,
  "departure_at_utc": null,
  "lead_minutes": null,
  "label": null,
  "vehicle_id": null,
  "target_charge_soc": null,
  "enabled": null,
  "fire_at_utc": null,
  "created_at": null,
  "updated_at": null,
} satisfies ScheduledDepartureResponse

console.log(example)

// Convert the instance to a JSON string
const exampleJSON: string = JSON.stringify(example)
console.log(exampleJSON)

// Parse the JSON string back to an object
const exampleParsed = JSON.parse(exampleJSON) as ScheduledDepartureResponse
console.log(exampleParsed)
```

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


