
# LocationInput

Location input model.

## Properties

Name | Type
------------ | -------------
`latitude` | number
`longitude` | number
`address` | string

## Example

```typescript
import type { LocationInput } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "latitude": null,
  "longitude": null,
  "address": null,
} satisfies LocationInput

console.log(example)

// Convert the instance to a JSON string
const exampleJSON: string = JSON.stringify(example)
console.log(exampleJSON)

// Parse the JSON string back to an object
const exampleParsed = JSON.parse(exampleJSON) as LocationInput
console.log(exampleParsed)
```

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


