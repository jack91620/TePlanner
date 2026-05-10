
# TelemetryStateEntry

One ``tel:<entity>:since`` + value pair from automation_state.

## Properties

Name | Type
------------ | -------------
`entity` | string
`value` | [](.md)
`since` | Date

## Example

```typescript
import type { TelemetryStateEntry } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "entity": null,
  "value": null,
  "since": null,
} satisfies TelemetryStateEntry

console.log(example)

// Convert the instance to a JSON string
const exampleJSON: string = JSON.stringify(example)
console.log(exampleJSON)

// Parse the JSON string back to an object
const exampleParsed = JSON.parse(exampleJSON) as TelemetryStateEntry
console.log(exampleParsed)
```

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


