
# ScheduledDepartureRequest


## Properties

Name | Type
------------ | -------------
`departure_at_utc` | Date
`lead_minutes` | number
`label` | string
`vehicle_id` | string
`target_charge_soc` | number
`enabled` | boolean

## Example

```typescript
import type { ScheduledDepartureRequest } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "departure_at_utc": null,
  "lead_minutes": null,
  "label": null,
  "vehicle_id": null,
  "target_charge_soc": null,
  "enabled": null,
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


