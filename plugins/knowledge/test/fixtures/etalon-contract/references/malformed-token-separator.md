# Malformed token separator fixture

The inventory entry and the matching `**File:**` marker use `{app}evil/x.ts` — the
recognised bucket token `{app}` immediately followed by more letters with no `/`
separator. Checking only that the path STARTS WITH a recognised token prefix let this
through; a bucket token must be followed by `/` and a non-empty path, so `{app}evil/x.ts`
names no real bucket at all.

## Files

- `{app}evil/x.ts`

**File:** `{app}evil/x.ts`

```ts
export const x = true
```
