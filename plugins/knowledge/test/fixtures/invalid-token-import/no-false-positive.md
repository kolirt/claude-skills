# Ordinary package import + legitimate token import (positive)

Broadening `collect_token_imports` to gate on brace SHAPE instead of
lowercase-only `TOKEN_START` must not start flagging things that were always
fine: an ordinary external package import (`import { ref } from 'vue'`) never
had brace shape to begin with, and a legitimate lowercase token import
(`{shared-lib}/toast`) has always been a valid external reference. Neither
must be flagged as `invalid-token-import`.

## Files

- `{app}/main.ts`

**File:** `{app}/main.ts`

```ts
import { ref } from 'vue'
import { useToast } from '{shared-lib}/toast'

export const state = ref(0)
```
