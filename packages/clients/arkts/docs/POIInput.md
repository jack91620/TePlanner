
# POIInput

Candidate POI for the charging-plan endpoint. Shape mirrors AMapRoutePOI (iOS SDK) — only id / name / lat / lng required.

## Properties

Name | Type
------------ | -------------
`id` | string
`name` | string
`latitude` | number
`longitude` | number
`address` | string

## Example

```typescript
import type { POIInput } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "id": null,
  "name": null,
  "latitude": null,
  "longitude": null,
  "address": null,
} satisfies POIInput

console.log(example)

// Convert the instance to a JSON string
const exampleJSON: string = JSON.stringify(example)
console.log(exampleJSON)

// Parse the JSON string back to an object
const exampleParsed = JSON.parse(exampleJSON) as POIInput
console.log(exampleParsed)
```

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


