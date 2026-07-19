# NodeNext `.js`-specifier-resolves-to-`.ts`-source fixture (positive)

Under NodeNext/ESM module resolution, TypeScript source legitimately imports a sibling
with a `.js` specifier even though the source file on disk is `.ts` — the compiler
resolves `./foo.js` against `foo.ts`, and the emitted JS really does import `foo.js`.
This etalon ships `{plugins}/foo.ts` and imports it as `./foo.js`; that must NOT be
flagged as unresolved.

## Files

- `{plugins}/foo.ts`
- `{plugins}/index.ts`

**File:** `{plugins}/foo.ts`

```ts
export const foo = 1
```

**File:** `{plugins}/index.ts`

```ts
import { foo } from './foo.js'

export { foo }
```
