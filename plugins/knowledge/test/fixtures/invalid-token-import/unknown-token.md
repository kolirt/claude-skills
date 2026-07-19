# Unknown token in an import specifier (negative)

The shipped file itself is fine (`{app}/main.ts`, a real token), but its import
specifier reaches for `{not-a-token}/x` — the exact SHAPE of a placement token
but not a row in placement.md's token table. The old token-import scan only
fed this into the near-miss check and never validated the token itself, so it
passed silently. Must be flagged as `invalid-token-import`.

## Files

- `{app}/main.ts`

**File:** `{app}/main.ts`

```ts
import x from '{not-a-token}/x'
```
