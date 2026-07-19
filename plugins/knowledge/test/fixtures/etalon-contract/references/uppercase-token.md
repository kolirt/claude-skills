# Uppercase token fixture (negative)

The inventory entry and its matching `**File:**` marker use `{APP}/main.ts`. Placement
tokens are lowercase-kebab and must match placement.md's vocabulary EXACTLY —
`{APP}` has the right shape but the wrong case, and case is not normalised anywhere in
the token grammar. Must be rejected exactly like an unknown token.

## Files

- `{APP}/main.ts`

**File:** `{APP}/main.ts`

```ts
export const bootstrapped = true
```
