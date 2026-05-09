
# SuggestChargeLimitResponse


## Properties

Name | Type
------------ | -------------
`already_matches` | boolean
`current_percent` | number
`hours_away` | number
`reason` | string
`recommended_percent` | number

## Example

```typescript
import type { SuggestChargeLimitResponse } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "already_matches": null,
  "current_percent": null,
  "hours_away": null,
  "reason": null,
  "recommended_percent": null,
} satisfies SuggestChargeLimitResponse

console.log(example)

// Convert the instance to a JSON string
const exampleJSON: string = JSON.stringify(example)
console.log(exampleJSON)

// Parse the JSON string back to an object
const exampleParsed = JSON.parse(exampleJSON) as SuggestChargeLimitResponse
console.log(exampleParsed)
```

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


