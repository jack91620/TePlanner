
# RecentFiresResponse


## Properties

Name | Type
------------ | -------------
`fires` | [Array&lt;RecentFireEntry&gt;](RecentFireEntry.md)

## Example

```typescript
import type { RecentFiresResponse } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "fires": null,
} satisfies RecentFiresResponse

console.log(example)

// Convert the instance to a JSON string
const exampleJSON: string = JSON.stringify(example)
console.log(exampleJSON)

// Parse the JSON string back to an object
const exampleParsed = JSON.parse(exampleJSON) as RecentFiresResponse
console.log(exampleParsed)
```

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


