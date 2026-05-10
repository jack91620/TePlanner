
# EmailAuthResponse

Email auth response.

## Properties

Name | Type
------------ | -------------
`access_token` | string
`token_type` | string
`expires_in` | number
`user_id` | number
`email` | string
`nickname` | string
`has_tesla_linked` | boolean

## Example

```typescript
import type { EmailAuthResponse } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "access_token": null,
  "token_type": null,
  "expires_in": null,
  "user_id": null,
  "email": null,
  "nickname": null,
  "has_tesla_linked": null,
} satisfies EmailAuthResponse

console.log(example)

// Convert the instance to a JSON string
const exampleJSON: string = JSON.stringify(example)
console.log(exampleJSON)

// Parse the JSON string back to an object
const exampleParsed = JSON.parse(exampleJSON) as EmailAuthResponse
console.log(exampleParsed)
```

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


