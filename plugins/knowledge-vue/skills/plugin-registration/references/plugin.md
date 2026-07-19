Full-file etalon for Vue plugin registration: one factory per package under `{plugins}`, plus the imperative initialiser under `{initial-plugins}`. `validationKit.ts` is shown as the representative factory shape.

Not reproduced here (each owned by its own etalon; barrels below still re-export by token import): `modal.ts` (`modals` skill), `router.ts` (`vue-router` skill's `router.md`), `vueQuery.ts` (`tanstack-query` skill), `httpRequest.ts` (`http-request` skill's `http-request-module.md`), `head.ts` (project-type specific — `core/references/bootstrap-csr.md` / `bootstrap-ssr.md`). The per-request `createApp` composition and bootstrap root/entry files are likewise owned by the active project type's bootstrap etalon.

On a flat `src/` (non-FSD), these paths resolve unchanged.

## Files
- `{plugins}/validationKit.ts`
- `{plugins}/index.ts`
- `{initial-plugins}/index.ts`

**File:** `{plugins}/validationKit.ts`
```ts
import { createValidation as createValidationMaster } from '@kolirt/vue-validation-kit'
import { en } from '@kolirt/vue-validation-kit/localization'

export function createValidation() {
  return createValidationMaster({
    locale: 'en',
    messages: { en },
    clearErrorOnInput: true,
    silentRevalidation: true
  })
}
```

**File:** `{plugins}/index.ts`
```ts
export { createHead } from '{plugins}/head'
export { createModal } from '{plugins}/modal'
export { createRouter } from '{plugins}/router'
export { createValidation } from './validationKit'
export { createVueQuery } from '{plugins}/vueQuery'
```

**File:** `{initial-plugins}/index.ts`
```ts
export { createApp } from '{initial-plugins}/createApp'
export { initHttpRequest } from '{initial-plugins}/httpRequest'
```
