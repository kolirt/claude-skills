# Duplicate-file-owner fixture, same-variant B (negative, paired with variant-same-a.md)

Variant: projectType=csr

Ships `{shared-lib}/session-store.ts` too, with different content than
`variant-same-a.md`, and the SAME `projectType=csr` variant value — same key AND
same value is not an exemption. See variant-same-a.md for the full explanation.

## Files

- `{shared-lib}/session-store.ts`

**File:** `{shared-lib}/session-store.ts`

```ts
export const session = { token: undefined }
```
