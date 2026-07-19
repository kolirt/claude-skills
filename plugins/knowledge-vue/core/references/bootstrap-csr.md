Variant: projectType=csr

Full-file etalon for the Vue CSR bootstrap. The reference project this
knowledge base is drawn from is SSR-only, so this etalon is the
`bootstrap-ssr.md` etalon **mechanically reduced to its client half** — the
server entry, the template-fill handler, and every SSR placeholder/hydration
concern removed; nothing new invented. Double-check against a real CSR
project if one becomes available. `{initial-plugins}/createApp.ts` and
`{plugins}/head.ts` are owned here, not by `plugin-registration` — both are
project-type specific: sync, no options, static `unhead` import, vs the
async, `{ ssr }`-driven, dynamic-import SSR versions in `bootstrap-ssr.md`.
`createRouter` and `createVueQuery` are ONE shared factory each, defaulted to
`{ ssr: false }` — CSR calls them bare, SSR passes `{ ssr: true }`. There is
no separate `CreateAppOptions` type.

## Files
- `{project-root}/index.html`
- `{plugins}/head.ts`
- `{initial-plugins}/createApp.ts`
- `{assets}/styles/main.css`
- `{app}/main.ts`

**File:** `{project-root}/index.html`
```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <link href="/favicon.svg" rel="icon" type="image/svg+xml" />
    <meta content="width=device-width, initial-scale=1.0" name="viewport" />
  </head>
  <body>
    <div id="app"></div>
    <script src="/{app}/main.ts" type="module"></script>
  </body>
</html>
```

**File:** `{plugins}/head.ts`
```ts
import { createHead as createHeadClient } from '@unhead/vue/client'
import type { VueHeadClient } from '@unhead/vue'

// Sync, no options — CSR never needs the async `{ ssr }`-branching shape
// SSR's per-request factory uses (see `bootstrap-ssr.md`).
export function createHead(): VueHeadClient {
  return createHeadClient() as VueHeadClient
}
```

**File:** `{initial-plugins}/createApp.ts`
```ts
import { createApp as _createApp } from 'vue'

import '{assets}/styles/main.css'

import App from '{app}/App.vue'
import { createHead, createModal, createRouter, createValidation, createVueQuery } from '{plugins}'

function createApp() {
  const app = _createApp(App)

  const router = createRouter()
  const vueQuery = createVueQuery()
  const head = createHead()

  app.use(router)
  app.use(vueQuery)
  app.use(head)
  app.use(createValidation())
  app.use(createModal())

  return { app, router, queryClient: vueQuery.queryClient, head }
}

export { createApp }
```

**File:** `{assets}/styles/main.css`
```css
@import 'tailwindcss';
```

**File:** `{app}/main.ts`
```ts
import { createApp, initHttpRequest } from '{initial-plugins}'

async function bootstrap() {
  const { app, router, queryClient } = createApp()
  initHttpRequest(queryClient)

  await router.isReady()
  app.mount('#app')
}

bootstrap()
```
