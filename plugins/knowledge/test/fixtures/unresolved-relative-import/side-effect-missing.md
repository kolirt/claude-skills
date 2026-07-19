# Side-effect import fixture (negative)

The etalon's only file bare-imports a stylesheet via a RELATIVE side-effect
specifier (`import './missing.css'` — no bindings, no `from`) but ships no
`missing.css`. Side-effect imports must be checked exactly like named/dynamic
imports — a bare `import './x'` used to be invisible to
`unresolved-relative-import` because IMPORT_SPEC only recognised `from '...'`
and `import('...')` forms; this fixture proves the bare form is now covered.

## Files

- `{shared-lib}/thing/index.ts`

**File:** `{shared-lib}/thing/index.ts`

```ts
import './missing.css'

export const thing = 1
```
