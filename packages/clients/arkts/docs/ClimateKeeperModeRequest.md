
# ClimateKeeperModeRequest

Set climate keeper mode (0=off, 1=keep, 2=dog, 3=camp).

## Properties

Name | Type
------------ | -------------
`mode` | number

## Example

```typescript
import type { ClimateKeeperModeRequest } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "mode": null,
} satisfies ClimateKeeperModeRequest

console.log(example)

// Convert the instance to a JSON string
const exampleJSON: string = JSON.stringify(example)
console.log(exampleJSON)

// Parse the JSON string back to an object
const exampleParsed = JSON.parse(exampleJSON) as ClimateKeeperModeRequest
console.log(exampleParsed)
```

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


