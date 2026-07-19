# Uppercase token in an import specifier (negative)

The shipped file itself is fine (`{app}/main.ts`), but its import specifier
reaches for `{APP}/x` — the right shape but the wrong case. `collect_token_imports`
used to gate on `TOKEN_START` (lowercase-only) before collecting a specifier at
all, so an uppercase brace import like this one was never even fed into the
token grammar check — it fell through as if it were an ordinary external
package import. Must be flagged as `invalid-token-import`, exactly like the
same uppercase shape already is for a `**File:**` marker.

## Files

- `{app}/main.ts`

**File:** `{app}/main.ts`

```ts
import x from '{APP}/x'
```
