# Duplicate-file-owner fixture, invalid variant value (negative, standalone)

Variant: projectType=banana

Declares a `Variant:` line with a recognised KEY (`projectType`) but a value
that is not one of that key's recognised branches (`csr`, `ssr`). Validating
only the key let this through and `_variants_complementary` would then treat
it as a legitimate alternative to `projectType=csr` — a typo silently granted
a duplicate-ownership exemption. The value must be validated too.

## Files

- `{shared-lib}/whatever.ts`

**File:** `{shared-lib}/whatever.ts`

```ts
export const whatever = true
```
