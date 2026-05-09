
# EmailAuthResponse

Email auth response.

## Properties

Name | Type
------------ | -------------
`access_token` | string
`email` | string
`expires_in` | number
`has_tesla_linked` | boolean
`nickname` | string
`token_type` | string
`user_id` | number

## Example

```typescript
import type { EmailAuthResponse } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "access_token": null,
  "email": null,
  "expires_in": null,
  "has_tesla_linked": null,
  "nickname": null,
  "token_type": null,
  "user_id": null,
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


