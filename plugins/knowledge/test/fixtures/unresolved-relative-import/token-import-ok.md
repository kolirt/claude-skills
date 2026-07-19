# Token import guard fixture (positive)

The etalon's only file imports another bucket by TOKEN (`{shared-lib}/toast`) and ships
nothing for it — that is correct: a token import is an external reference the etalon
must NOT duplicate. `unresolved-relative-import` must NOT flag this file; flagging it
would regress the detector back into the wrong "every unshipped import is a defect"
standard.

## Files

- `{shared-lib}/thing/index.ts`

**File:** `{shared-lib}/thing/index.ts`

```ts
import { useToast } from '{shared-lib}/toast'

export const thing = useToast
```
