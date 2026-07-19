# Layouts — full-file etalon (CSR)

Variant: projectType=csr

Reference implementation of the default layout scaffold: `DefaultLayout` +
`ErrorLayout`, the `Layouts` enum, the layout-resolver global middleware, and
the app shell rendering the resolved layout around `<RouterView>`. Reproduce
as written, recomputing any `// @arch-relative` line.

One of two mutually exclusive variants, chosen by `projectType` (fixed by
`vue-work` step 0): this file for CSR, `layouts.md` for SSR — never both.
They differ only in `{app}/App.vue`, which wires `runHydrations` (SSR) or
omits it (CSR).

## Files
- `{layouts}/DefaultLayout.vue`
- `{layouts}/ErrorLayout.vue`
- `{pages-config}/layouts.ts`
- `{global-middlewares}/layout.middleware.ts`
- `{app}/App.vue`

**File:** `{layouts}/DefaultLayout.vue`
```vue
<script lang="ts" setup>
import { Footer } from '{widget}/footer'
import { Header } from '{widget}/header'
import { SummaryBar } from '{widget}/summary-bar'
import { SidebarTriggers } from '{widget}/sidebar'

import { useSessionStore } from '{entity}/session'

import { ScrollArea } from '{shared-ui}/scroll-area'

const { isAuthenticated } = useSessionStore()
</script>

<template>
  <Header>
    <template #triggers>
      <SidebarTriggers />
    </template>
  </Header>

  <ScrollArea>
    <div :style="{ 'padding-bottom': `var(--summary-bar-height)` }">
      <slot />
    </div>
  </ScrollArea>

  <Footer />

  <SummaryBar v-if="isAuthenticated" />
</template>
```

**File:** `{layouts}/ErrorLayout.vue`
```vue
<script lang="ts" setup>
import { computed } from 'vue'

import { RouteNames } from '{shared-config}'
import { useSeoMeta } from '{shared-lib}/seo'
import { LinkButton } from '{shared-ui}/buttons'

import DefaultLayout from './DefaultLayout.vue'

useSeoMeta(
  computed(() => ({
    title: 'Page not found',
    description: 'The page you are looking for does not exist or has been moved.'
  }))
)
</script>

<template>
  <DefaultLayout>
    <div class="flex w-full flex-col items-center justify-center gap-5 px-5 py-20 text-center">
      <h1 class="text-xlll text-foreground-accent font-bold">Page not found</h1>

      <p class="text-foreground-muted max-w-md text-base">
        The page you are looking for does not exist or has been moved.
      </p>

      <LinkButton :to="{ name: RouteNames.Home }">Back to home</LinkButton>
    </div>
  </DefaultLayout>
</template>
```

**File:** `{pages-config}/layouts.ts`
```ts
export enum Layouts {
  Default = 'DefaultLayout',
  Error = 'ErrorLayout'
}
```

The two `// @arch-relative` literals below are relative to this file's own
location (`{global-middlewares}` → `{layouts}`); recompute them for the active
architecture — Vite requires a static relative literal, so a placement token
can't be substituted at build time.

**File:** `{global-middlewares}/layout.middleware.ts`
```ts
import type { Component } from 'vue'

import type { Middleware } from '{pages-types}'

const imports = import.meta.glob('../layouts/*.vue', { import: 'default' }) // @arch-relative

const middleware: Middleware = async function (to) {
  // @ts-expect-error
  to.meta.layout.component = (await imports[`../layouts/${to.meta.layout.type}.vue`]()) as Component // @arch-relative
}

export { middleware }
```

CSR arm: no SSR, so no server-rendered state to reconcile — `<Suspense>` has no
`@resolve` handler and no `runHydrations` import. `useTitleTemplate('<your-app-name>')`
is a non-token placeholder (`core/placement.md`) — substitute the real app
name, never reproduce `<your-app-name>` literally.

**File:** `{app}/App.vue`
```vue
<script lang="ts" setup>
import { onUnmounted, useTemplateRef } from 'vue'
import { RouterView, useRoute, useRouter } from 'vue-router'

import ErrorLayout from '{layouts}/ErrorLayout.vue'

import { useTitleTemplate } from '{shared-lib}/seo'
import { ToastContainer } from '{shared-lib}/toast'
import { ClientOnly, ErrorBoundary } from '{shared-ui}/boundary'
import { MainModalTarget, PromptModalTarget } from '{shared-ui}/modals'

const route = useRoute()
const router = useRouter()
const boundaryRef = useTemplateRef<{ reset: () => void }>('boundaryRef')

useTitleTemplate('<your-app-name>')

const unregister = router.afterEach(() => {
  boundaryRef.value?.reset()
})

onUnmounted(unregister)
</script>

<template>
  <div id="portal" class="fixed top-0 left-0 flex h-screen w-screen flex-col">
    <ErrorBoundary ref="boundaryRef">
      <template #abort>
        <ErrorLayout />
      </template>

      <component :is="route.meta?.layout?.component ?? 'div'">
        <Suspense>
          <RouterView />
        </Suspense>
      </component>
    </ErrorBoundary>

    <ClientOnly>
      <MainModalTarget />
      <PromptModalTarget />

      <ToastContainer />
    </ClientOnly>
  </div>
</template>
```
