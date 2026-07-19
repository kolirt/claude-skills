# Duplicate-file-owner fixture, same-variant A (negative, paired with variant-same-b.md)

Variant: projectType=csr

Ships `{shared-lib}/session-store.ts`. `variant-same-b.md` (same fixture directory)
ships the SAME token path and declares the SAME variant value (`projectType=csr`
too) — not an alternative, just two etalons claiming the same variant slot.
`duplicate-file-owner` must still flag this pair.

## Files

- `{shared-lib}/session-store.ts`

**File:** `{shared-lib}/session-store.ts`

```ts
export const session = { token: null }
```
