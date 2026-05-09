
# ChargeLimitRequest

Set the charge limit SOC percent (50..100).

## Properties

Name | Type
------------ | -------------
`percent` | number

## Example

```typescript
import type { ChargeLimitRequest } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "percent": null,
} satisfies ChargeLimitRequest

console.log(example)

// Convert the instance to a JSON string
const exampleJSON: string = JSON.stringify(example)
console.log(exampleJSON)

// Parse the JSON string back to an object
const exampleParsed = JSON.parse(exampleJSON) as ChargeLimitRequest
console.log(exampleParsed)
```

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


