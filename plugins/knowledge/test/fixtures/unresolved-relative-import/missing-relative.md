# Missing relative import fixture (negative)

The etalon's only file imports a sibling module via a RELATIVE specifier, but ships no
`missing.ts` (nor `missing.vue`/`missing.js`/`missing/index.ts`). Per the "Where an
etalon ends" rule, a relative import must resolve inside the etalon's own shipped
files — this one does not, so `unresolved-relative-import` must fire.

## Files

- `{shared-lib}/thing/index.ts`

**File:** `{shared-lib}/thing/index.ts`

```ts
import { x } from './missing'

export const thing = x
```
