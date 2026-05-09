
# ScheduledDepartureResponse


## Properties

Name | Type
------------ | -------------
`created_at` | Date
`departure_at_utc` | Date
`enabled` | boolean
`fire_at_utc` | Date
`id` | number
`label` | string
`lead_minutes` | number
`target_charge_soc` | number
`updated_at` | Date
`vehicle_id` | string

## Example

```typescript
import type { ScheduledDepartureResponse } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "created_at": null,
  "departure_at_utc": null,
  "enabled": null,
  "fire_at_utc": null,
  "id": null,
  "label": null,
  "lead_minutes": null,
  "target_charge_soc": null,
  "updated_at": null,
  "vehicle_id": null,
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


