
# ScheduledDepartureRequest


## Properties

Name | Type
------------ | -------------
`departure_at_utc` | Date
`enabled` | boolean
`label` | string
`lead_minutes` | number
`target_charge_soc` | number
`vehicle_id` | string

## Example

```typescript
import type { ScheduledDepartureRequest } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "departure_at_utc": null,
  "enabled": null,
  "label": null,
  "lead_minutes": null,
  "target_charge_soc": null,
  "vehicle_id": null,
} satisfies ScheduledDepartureRequest

console.log(example)

// Convert the instance to a JSON string
const exampleJSON: string = JSON.stringify(example)
console.log(exampleJSON)

// Parse the JSON string back to an object
const exampleParsed = JSON.parse(exampleJSON) as ScheduledDepartureRequest
console.log(exampleParsed)
```

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


