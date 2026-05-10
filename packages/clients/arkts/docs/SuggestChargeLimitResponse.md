
# SuggestChargeLimitResponse


## Properties

Name | Type
------------ | -------------
`recommended_percent` | number
`current_percent` | number
`reason` | string
`hours_away` | number
`already_matches` | boolean

## Example

```typescript
import type { SuggestChargeLimitResponse } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "recommended_percent": null,
  "current_percent": null,
  "reason": null,
  "hours_away": null,
  "already_matches": null,
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


