# Duplicate marker fixture

Violates the contract one way only: the same path gets two `**File:**` markers.

## Files

- `{shared-lib}/thing/a.ts`

**File:** `{shared-lib}/thing/a.ts`

```ts
export const a = 1
```

**File:** `{shared-lib}/thing/a.ts`

```ts
export const a = 2
```
