# Underscore token fixture (negative)

The inventory entry and its matching `**File:**` marker use `{app_name}/main.ts`.
`app_name` is not a row in placement.md's token table — the real token is `{app}` —
and an underscore is not part of the lowercase-kebab token grammar at all. Must be
rejected exactly like any other unknown token.

## Files

- `{app_name}/main.ts`

**File:** `{app_name}/main.ts`

```ts
export const bootstrapped = true
```
