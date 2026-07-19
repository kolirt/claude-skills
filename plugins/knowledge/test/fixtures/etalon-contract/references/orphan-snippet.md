# Orphan snippet fixture

Violates the contract one way only: a fenced block appears before any
`**File:**` marker, as a loose intro example instead of a complete file.

## Files

- `{shared-lib}/thing/a.ts`

Here is a quick illustration before the real file:

```ts
console.log('example')
```

**File:** `{shared-lib}/thing/a.ts`

```ts
export const a = 1
```
