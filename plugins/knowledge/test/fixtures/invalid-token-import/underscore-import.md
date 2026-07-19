# Underscore token in an import specifier (negative)

The shipped file itself is fine (`{app}/main.ts`), but its import specifier
reaches for `{app_name}/x` — an underscore is not part of the lowercase-kebab
token grammar, and `app_name` names no row in placement.md regardless. Same
collection gap as `uppercase-import.md`: the old lowercase-only gate in
`collect_token_imports` let this brace-shaped specifier fall through
uncollected and unchecked. Must be flagged as `invalid-token-import`.

## Files

- `{app}/main.ts`

**File:** `{app}/main.ts`

```ts
import x from '{app_name}/x'
```
