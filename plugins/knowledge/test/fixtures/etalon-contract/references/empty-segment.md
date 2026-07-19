# Empty path segment fixture (negative)

The inventory entry and its matching `**File:**` marker use `{app}//x.ts` — a doubled
slash right after the token, producing an EMPTY path segment. A token must be followed
by `/` and one or more NON-EMPTY segments; an empty segment names no real path
component and must be rejected exactly like a `.`/`..` escape.

## Files

- `{app}//x.ts`

**File:** `{app}//x.ts`

```ts
export const x = true
```
