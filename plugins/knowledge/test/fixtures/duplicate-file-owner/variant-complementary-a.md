# Duplicate-file-owner fixture, complementary variant A (positive, paired with variant-complementary-b.md)

Variant: projectType=csr

Ships `{shared-lib}/api-client.ts` for CSR projects. `variant-complementary-b.md` (same
fixture directory) ships the SAME token path but declares `Variant: projectType=ssr` —
same key, different value. Per authoring-knowledge-skills SKILL.md §7 "The one
exception — VARIANTS", these are mutually exclusive alternatives chosen by the
`projectType` project-model constant, so a reader reproduces exactly one of them.
`duplicate-file-owner` must NOT flag this pair.

## Files

- `{shared-lib}/api-client.ts`

**File:** `{shared-lib}/api-client.ts`

```ts
export function createApiClient() {
  return fetch
}
```
