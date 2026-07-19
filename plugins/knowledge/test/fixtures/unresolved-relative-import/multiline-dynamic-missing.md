# Multiline dynamic import fixture (negative)

The etalon's only file dynamically imports a sibling module, but the specifier
is split across lines — `import(` opens on one line and the quoted path
closes on the next. A per-line regex scan never sees the complete
`import( '...' )` shape on any single line and silently misses it. The etalon
ships no `missing.ts` (nor `.vue`/`.js`/`index.ts`), so
`unresolved-relative-import` must still fire.

## Files

- `{shared-lib}/thing/index.ts`

**File:** `{shared-lib}/thing/index.ts`

```ts
export async function loadThing() {
  const mod = await import(
    './missing'
  )
  return mod
}
```
