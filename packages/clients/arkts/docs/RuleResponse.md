
# RuleResponse


## Properties

Name | Type
------------ | -------------
`id` | string
`preset_id` | string
`name` | string
`enabled` | boolean
`spec` | object
`version` | number
`updated_at` | Date
`last_fired_at` | Date
`display_order` | number
`is_firing` | boolean
`firing_since` | Date

## Example

```typescript
import type { RuleResponse } from '@teplanner/sdk'

// TODO: Update the object below with actual values
const example = {
  "id": null,
  "preset_id": null,
  "name": null,
  "enabled": null,
  "spec": null,
  "version": null,
  "updated_at": null,
  "last_fired_at": null,
  "display_order": null,
  "is_firing": null,
  "firing_since": null,
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


