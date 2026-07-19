# Duplicate-file-owner fixture, invalid variant declaration (negative, standalone)

Variant: nonsense=1

Declares a `Variant:` line whose key is not one of the recognised project-model
constants (`projectType`, `architecture`, `runtime`). A typo'd key must not silently
grant the variant exemption — the declaration itself is invalid and must be flagged.

## Files

- `{shared-lib}/whatever.ts`

**File:** `{shared-lib}/whatever.ts`

```ts
export const whatever = true
```
