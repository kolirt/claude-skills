Variant: projectType=ssr

Full-file etalon for the Vue SSR bootstrap: the per-request `createApp`
factory, the two entry files, the HTML template with its SSR placeholder
comments, and the server bootstrap (Express host + template-fill handler).
`createApp.ts` and `{plugins}/head.ts` are owned here, not by
`plugin-registration` — both are project-type specific: async, take `{ ssr }`,
and use `createSSRApp`/a dynamic `unhead` import, vs the sync, no-options,
static-import CSR versions in `bootstrap-csr.md`. `createRouter` and
`createVueQuery` are ONE shared factory each, defaulted to `{ ssr: false }`;
SSR passes `{ ssr: true }` explicitly — there is no separate
`CreateAppOptions` type. Query-state hand-off (`dehydrate`/`hydrate`,
`window.__INITIAL_STATE__`) is owned by the query plugin, not this etalon.

## Files
- `{project-root}/index.html`
- `{plugins}/head.ts`
- `{initial-plugins}/createApp.ts`
- `{assets}/styles/main.css`
- `{app}/entryClient.ts`
- `{app}/entryServer.ts`
- `{project-root}/server/render.ts`
- `{project-root}/server/index.ts`
- `{project-root}/server/tsconfig.json`

**File:** `{project-root}/index.html`
```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <link href="/favicon.svg" rel="icon" type="image/svg+xml" />
    <meta content="width=device-width, initial-scale=1.0" name="viewport" />
    <!--ssr-head-->
  </head>
  <body>
    <!--ssr-body-open-->
    <div id="app"><!--ssr-outlet--></div>
    <script>window.__INITIAL_STATE__ = <!--ssr-state-->;</script>
    <script src="/{app}/entryClient.ts" type="module"></script>
    <!--ssr-body-->
  </body>
</html>
```

**File:** `{plugins}/head.ts`
```ts
import type { VueHeadClient } from '@unhead/vue'

// Async: dynamically imports the server or client `unhead` build.
export async function createHead({ ssr }: { ssr: boolean }): Promise<VueHeadClient> {
  const { createHead: createUnheadInstance } = ssr
    ? await import('@unhead/vue/server')
    : await import('@unhead/vue/client')

  return createUnheadInstance() as VueHeadClient
}
```

**File:** `{initial-plugins}/createApp.ts`
```ts
import { createSSRApp } from 'vue'

import '{assets}/styles/main.css'

import App from '{app}/App.vue'
import { createHead, createModal, createRouter, createValidation, createVueQuery } from '{plugins}'

async function createApp({ ssr }: { ssr: boolean }) {
  const app = createSSRApp(App)

  const router = createRouter({ ssr })
  const vueQuery = createVueQuery({ ssr })
  const head = await createHead({ ssr })

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

**File:** `{app}/entryClient.ts`
```ts
import { createApp, initHttpRequest } from '{initial-plugins}'

async function bootstrap() {
  const { app, router, queryClient } = await createApp({ ssr: false })
  initHttpRequest(queryClient)

  await router.isReady()
  app.mount('#app')
}

bootstrap()
```

**File:** `{app}/entryServer.ts`
```ts
import { dehydrate } from '{shared-lib}/query'
import type { SSRHeadPayload } from 'unhead/server'
import { renderToString } from 'vue/server-renderer'

import { HttpAbortError } from '{shared-lib}/http-request'

import { createApp } from '{initial-plugins}'

interface NotFoundResult {
  type: 'notFound'
}

interface ShellResult {
  type: 'shell'
}

interface SsrResult {
  type: 'ssr'
  html: string
  state: unknown
  headPayload: SSRHeadPayload
}

type RenderResult = NotFoundResult | ShellResult | SsrResult

async function render(url: string): Promise<RenderResult> {
  const { app, router, queryClient, head } = await createApp({ ssr: true })

  // ErrorBoundary can swallow SSR Suspense errors, so try/catch never sees the
  // abort — capture it into a per-request flag here instead.
  let abortStatus: 404 | null = null
  app.config.errorHandler = (err) => {
    if (err instanceof HttpAbortError && err.status === 404) {
      abortStatus = 404
      return
    }
    throw err
  }

  try {
    await router.push(url)
    await router.isReady()

    // Two shapes: no catch-all route → nothing matches; with one → it matches and
    // carries the flag, so `matched.length` alone would answer 200.
    const route = router.currentRoute.value
    if (route.matched.length === 0) return { type: 'notFound' }
    if (route.meta.layout?.isError404) return { type: 'notFound' }
    // Merged meta, not `matched.some(...)`: a child's explicit `ssr: false` must win
    // over an ancestor's `ssr: true`.
    if (route.meta.ssr !== true) return { type: 'shell' }

    const html = await renderToString(app)
    if (abortStatus === 404) return { type: 'notFound' }

    const state = dehydrate(queryClient)
    // `head.render()` since unhead v3 — replaces the deprecated `renderSSRHead(head)`.
    const headPayload = head.render() as SSRHeadPayload

    return { type: 'ssr', html, state, headPayload }
  } catch (e) {
    // A captured abort can cascade into other errors — once the flag is set,
    // any surface error means 404.
    if (e instanceof HttpAbortError && e.status === 404) {
      abortStatus = 404
    }
    if (abortStatus === 404) return { type: 'notFound' }
    throw e
  }
}

export { render, type RenderResult }
```

**File:** `{project-root}/server/render.ts`
```ts
import type { Request, Response } from 'express'

// Inlined to keep server/ tsconfig isolated from the src/ graph.
// Keep in sync with RenderResult in entryServer.ts.
interface HeadPayload {
  headTags: string
  bodyTags: string
  bodyTagsOpen: string
  htmlAttrs: string
  bodyAttrs: string
}

type RenderResult =
  | { type: 'notFound' }
  | { type: 'shell' }
  | { type: 'ssr'; html: string; state: unknown; headPayload: HeadPayload }

interface RenderFn {
  (url: string): Promise<RenderResult>
}

const EMPTY_HEAD: HeadPayload = { headTags: '', bodyTags: '', bodyTagsOpen: '', htmlAttrs: '', bodyAttrs: '' }

async function handle(render: RenderFn, template: string, req: Request, res: Response): Promise<void> {
  let result: RenderResult
  try {
    result = await render(req.originalUrl)
  } catch (e) {
    console.error('[ssr] render error', e)
    res.status(500).type('html').send('Internal Server Error')
    return
  }

  switch (result.type) {
    case 'notFound':
      sendShell(res, template, 404)
      return

    case 'shell':
      sendShell(res, template, 200)
      return

    case 'ssr':
      res
        .status(200)
        .type('html')
        .send(
          fillTemplate(template, {
            html: result.html,
            state: JSON.stringify(result.state).replace(/</g, '\\u003c'),
            head: result.headPayload
          })
        )
      return
  }
}

function sendShell(res: Response, template: string, status: 200 | 404): void {
  res
    .status(status)
    .type('html')
    .send(fillTemplate(template, { html: '', state: 'null', head: EMPTY_HEAD }))
}

interface TemplateParts {
  html: string
  state: string
  head: HeadPayload
}

function fillTemplate(template: string, parts: TemplateParts): string {
  // htmlAttrs/bodyAttrs arrive as " key=value" strings appended after the tag name;
  // splicing the opening tokens keeps index.html valid HTML.
  return template
    .replace('<html', `<html${parts.head.htmlAttrs}`)
    .replace('<body', `<body${parts.head.bodyAttrs}`)
    .replaceAll('<!--ssr-head-->', parts.head.headTags)
    .replaceAll('<!--ssr-body-open-->', parts.head.bodyTagsOpen)
    .replaceAll('<!--ssr-outlet-->', parts.html)
    .replaceAll('<!--ssr-state-->', parts.state)
    .replaceAll('<!--ssr-body-->', parts.head.bodyTags)
}

export { handle }
```

**File:** `{project-root}/server/index.ts`
```ts
import express from 'express'
import { readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

import { handle } from './render.js'

// dev: runs as `server/index.ts` via tsx (`..` = app root).
// prod: runs from `dist/server-bootstrap/index.js` (`../..` = app root).
const HERE = dirname(fileURLToPath(import.meta.url))
const ROOT = process.env.NODE_ENV === 'production' ? resolve(HERE, '..', '..') : resolve(HERE, '..')
const PORT = Number(process.env.PORT) || 5177
const isProd = process.env.NODE_ENV === 'production'

async function start() {
  const app = express()

  app.get('/_health', (_req, res) => {
    res.status(200).type('text/plain').send('ok')
  })

  if (!isProd) {
    const { createServer } = await import('vite')
    const vite = await createServer({
      root: ROOT,
      server: { middlewareMode: true, host: '0.0.0.0', port: PORT, allowedHosts: ['<your-local-domain>.test'] },
      appType: 'custom'
    })

    app.use(vite.middlewares)

    const templatePath = resolve(ROOT, 'index.html')
    let rawTemplate = readFileSync(templatePath, 'utf-8')
    vite.watcher.on('change', (file) => {
      if (file === templatePath) rawTemplate = readFileSync(templatePath, 'utf-8')
    })

    app.use(async (req, res, next) => {
      try {
        const template = await vite.transformIndexHtml(req.originalUrl, rawTemplate)
        const mod = await vite.ssrLoadModule('/{app}/entryServer.ts')
        await handle(mod.render, template, req, res)
      } catch (e) {
        vite.ssrFixStacktrace(e as Error)
        next(e)
      }
    })
  } else {
    app.use('/assets', express.static(resolve(ROOT, 'dist/client/assets'), { immutable: true, maxAge: '1y' }))
    app.use(express.static(resolve(ROOT, 'dist/client'), { index: false }))

    const template = readFileSync(resolve(ROOT, 'dist/client/index.html'), 'utf-8')
    const mod = await import(resolve(ROOT, 'dist/server/entryServer.js'))

    app.use((req, res, next) => {
      handle(mod.render, template, req, res).catch(next)
    })
  }

  app.listen(PORT, '0.0.0.0', () => {
    console.log(`[ssr] server listening on http://0.0.0.0:${PORT}`)
  })
}

start().catch((e) => {
  console.error('[ssr] failed to start', e)
  process.exit(1)
})
```

**File:** `{project-root}/server/tsconfig.json`
```json
{
  "compilerOptions": {
    "module": "esnext",
    "moduleResolution": "bundler",
    "target": "es2022",
    "lib": ["es2022"],
    "types": ["node"],
    "outDir": "../dist/server-bootstrap",
    "rootDir": ".",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "verbatimModuleSyntax": false,
    "noEmit": false,
    "incremental": true,
    "tsBuildInfoFile": "../node_modules/.tmp/server-bootstrap.tsbuildinfo"
  },
  "include": ["**/*.ts"]
}
```
