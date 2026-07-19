# Near-miss token import fixture — importer (negative)

Imports `{pages-ui}/HomePage.vue` — same token, same filename as the file the
sibling `shipper.md` fixture ships, but at a different directory
(`{pages-ui}/home/HomePage.vue`). This is a corpus-internal inconsistency:
the import path and the shipped path disagree about where the file lives.
Must be flagged as `near-miss-token-import`. A true external reference (no
matching filename anywhere in the corpus) must stay silent — see
`unresolved-relative-import/token-import-ok.md`.

## Files

- `{app}/index.ts`

**File:** `{app}/index.ts`

```ts
import HomePage from '{pages-ui}/HomePage.vue'
```
