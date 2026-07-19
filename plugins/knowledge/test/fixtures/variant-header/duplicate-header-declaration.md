# Duplicate header Variant declaration fixture (negative, standalone)

Variant: projectType=csr
Variant: projectType=ssr

Two `Variant:` lines in the header region (both before `## Files`), declaring
conflicting values for the same key. The old parser silently took the FIRST match
and ignored the second — a contradiction of this shape must be an error, not
resolved in silence.

## Files

- `{shared-lib}/whatever.ts`

**File:** `{shared-lib}/whatever.ts`

```ts
export const whatever = true
```
