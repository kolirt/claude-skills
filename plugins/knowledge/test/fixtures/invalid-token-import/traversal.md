# Traversal in an import specifier (negative)

The shipped file itself is fine (`{app}/main.ts`), but its import specifier
walks out of the `{app}` bucket via a `..` segment — exactly the escape
`_is_known_token_path` already rejects for a `**File:**` marker, but which the
old token-import scan never checked at all. Must be flagged as
`invalid-token-import`.

## Files

- `{app}/main.ts`

**File:** `{app}/main.ts`

```ts
import evil from '{app}/../evil'
```
