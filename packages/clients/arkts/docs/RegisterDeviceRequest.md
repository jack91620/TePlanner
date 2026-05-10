
# RegisterDeviceRequest


## Properties

Name | Type
------------ | -------------
`token` | string
`bundle_id` | string
`platform` | string
`provider_token` | string

## Example

```typescript
import type { RegisterDeviceRequest } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "token": null,
  "bundle_id": null,
  "platform": null,
  "provider_token": null,
} satisfies RegisterDeviceRequest

console.log(example)

// Convert the instance to a JSON string
const exampleJSON: string = JSON.stringify(example)
console.log(exampleJSON)

// Parse the JSON string back to an object
const exampleParsed = JSON.parse(exampleJSON) as RegisterDeviceRequest
console.log(exampleParsed)
```

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


