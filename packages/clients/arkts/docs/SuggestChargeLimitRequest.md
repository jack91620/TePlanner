
# SuggestChargeLimitRequest


## Properties

Name | Type
------------ | -------------
`current_limit` | number
`daily_limit_soc` | number
`trip_limit_soc` | number
`trip_window_hours` | number

## Example

```typescript
import type { SuggestChargeLimitRequest } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "current_limit": null,
  "daily_limit_soc": null,
  "trip_limit_soc": null,
  "trip_window_hours": null,
} satisfies SuggestChargeLimitRequest

console.log(example)

// Convert the instance to a JSON string
const exampleJSON: string = JSON.stringify(example)
console.log(exampleJSON)

// Parse the JSON string back to an object
const exampleParsed = JSON.parse(exampleJSON) as SuggestChargeLimitRequest
console.log(exampleParsed)
```

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


