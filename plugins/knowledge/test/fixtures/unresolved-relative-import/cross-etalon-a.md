# Cross-etalon relative import fixture (negative, strict same-etalon resolution)

STRICT reading of authoring-knowledge-skills SKILL.md §7: a relative import (`./x`,
`../x`) means "inside the etalon's OWN module" — the etalon MUST ship that file itself.
This etalon relatively imports `./modal`, a file it does NOT ship; some other etalon in
the plugin might ship `{plugins}/modal.ts`, but that does not matter — a relative
specifier resolves ONLY against this etalon's own `**File:**` markers. Reaching a file
owned by another etalon must use a TOKEN import (`{plugins}/modal`), never a relative
one. `unresolved-relative-import` must fire here.

## Files

- `{plugins}/index.ts`

**File:** `{plugins}/index.ts`

```ts
export { createModal } from './modal'
```
