# Bad etalon fixture

Violates the contract three ways: one inventory entry is never written, one written file
is missing from the inventory, and one fenced block carries no language tag.

## Files

- `{shared-lib}/thing/index.ts`
- `{shared-lib}/thing/useThing.ts`

**File:** `{shared-lib}/thing/index.ts`

```
export { useThing } from './useThing'
```

**File:** `{shared-lib}/thing/extra.ts`

```ts
export const extra = true
```
