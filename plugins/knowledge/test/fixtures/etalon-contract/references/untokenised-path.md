# Untokenised path fixture

Violates the contract one way only: the inventory entry and the matching `**File:**`
marker use a literal path (`app/foo.ts`) and an alias-prefixed literal
(`@/shared/x.ts`) instead of starting with a placement token.

## Files

- `app/foo.ts`
- `@/shared/x.ts`

**File:** `app/foo.ts`

```ts
export const foo = true
```

**File:** `@/shared/x.ts`

```ts
export const x = true
```
