# Extra fenced block fixture

Violates the contract one way only: a second fenced block follows the same
`**File:**` marker before the next one (or EOF) is reached.

## Files

- `{shared-lib}/thing/a.ts`

**File:** `{shared-lib}/thing/a.ts`

```ts
export const a = 1
```

```ts
export const b = 2
```
