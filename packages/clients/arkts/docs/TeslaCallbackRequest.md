
# TeslaCallbackRequest

Tesla OAuth callback request.

## Properties

Name | Type
------------ | -------------
`code` | string
`state` | string

## Example

```typescript
import type { TeslaCallbackRequest } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "code": null,
  "state": null,
} satisfies TeslaCallbackRequest

console.log(example)

// Convert the instance to a JSON string
const exampleJSON: string = JSON.stringify(example)
console.log(exampleJSON)

// Parse the JSON string back to an object
const exampleParsed = JSON.parse(exampleJSON) as TeslaCallbackRequest
console.log(exampleParsed)
```

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


