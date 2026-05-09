
# RuleResponse


## Properties

Name | Type
------------ | -------------
`display_order` | number
`enabled` | boolean
`id` | string
`last_fired_at` | Date
`name` | string
`preset_id` | string
`spec` | object
`updated_at` | Date
`version` | number

## Example

```typescript
import type { RuleResponse } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "display_order": null,
  "enabled": null,
  "id": null,
  "last_fired_at": null,
  "name": null,
  "preset_id": null,
  "spec": null,
  "updated_at": null,
  "version": null,
} satisfies RuleResponse

console.log(example)

// Convert the instance to a JSON string
const exampleJSON: string = JSON.stringify(example)
console.log(exampleJSON)

// Parse the JSON string back to an object
const exampleParsed = JSON.parse(exampleJSON) as RuleResponse
console.log(exampleParsed)
```

[[Back to top]](#) [[Back to API list]](../README.md#api-endpoints) [[Back to Model list]](../README.md#models) [[Back to README]](../README.md)


