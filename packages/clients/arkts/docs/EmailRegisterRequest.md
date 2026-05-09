
# EmailRegisterRequest

Email registration request.

## Properties

Name | Type
------------ | -------------
`email` | string
`nickname` | string
`password` | string

## Example

```typescript
import type { EmailRegisterRequest } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "email": null,
  "nickname": null,
  "password": null,
} satisfies EmailRegisterRequest

console.log(example)

// Convert the instance to a JSON string
const exampleJSON: string = JSON.stringify(example)
console.log(exampleJSON)

// Parse the JSON string back to an object
const exampleParsed = JSON.parse(exampleJSON) as EmailRegisterRequest
console.log(exampleParsed)
```

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


