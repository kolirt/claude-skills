# Etalon — route declarations (pages skill)

Full-file reference for how routes are declared: per-domain route files, the
route builders (`page()`, `group()`, `redirect()`, `getDefaultMeta()` — always
author routes through them, never by hand), the routing types, the
`RouteNames` enum, and one representative page component. Reproduce verbatim
when creating a new domain/route/page — only domain-specific names change.
`{pages-config}/layouts.ts` (and `Layouts`) is owned by the `layouts` skill's
`layouts.md` etalon; the shared `{pages-config}/index.ts` barrel is owned by
`page-middlewares`'s `middleware.md` etalon — neither is reproduced here.

Page components themselves belong to the consuming project, not this etalon — the routes
below lazily import several (`home/HomePage.vue`, `auth/AuthCallbackPage.vue`,
`blog/BlogPage.vue`, `blog/BlogCategoryPage.vue`, `products/ProductsPage.vue`) that are
never shipped here; only `blog/BlogArticlePage.vue` is included, as a shape example.

## Files
- `{shared-config}/routeNames.ts`
- `{shared-config}/index.ts`
- `{pages-types}`
- `{pages-utils}/page.ts`
- `{pages-utils}/group.ts`
- `{pages-utils}/redirect.ts`
- `{pages-utils}/meta.ts`
- `{pages-utils}/index.ts`
- `{routes}/default.ts`
- `{routes}/auth.ts`
- `{routes}/blog.ts`
- `{routes}/products.ts`
- `{routes}/index.ts`
- `{pages-ui}/blog/BlogArticlePage.vue`

**File:** `{shared-config}/routeNames.ts`
```ts
export enum RouteNames {
  Home = 'home',
  Product = 'product',
  Blog = 'blog',
  BlogCategory = 'blog.category',
  BlogArticle = 'blog.article',
  AuthCallback = 'auth.callback'
}
```

**File:** `{shared-config}/index.ts`
```ts
export { RouteNames } from './routeNames'
```

**File:** `{pages-types}`
```ts
import type { Component } from 'vue'
import type { RouteLocationNormalized, RouteMeta } from 'vue-router'

type Middleware = (to: RouteLocationNormalized, from: RouteLocationNormalized) => false | void | object

// Every route ships a lazy loader (`() => import(...)`), not a plain `Component` —
// this is vue-router's async-component shape, so the type must accept both.
type RouteComponent = Component | (() => Promise<Component>)

type Route = {
  path: string
  name?: string
  component: RouteComponent
  meta: RouteMeta
  children?: Route[]
}

export type { Middleware, Route }
```

**File:** `{pages-utils}/page.ts`
```ts
import type { RouteMeta } from 'vue-router'

import { Layouts } from '{pages-config}'
import type { Route } from '{pages-types}'
import { getDefaultMeta } from './meta'

export function page(
  path: Route['path'],
  name: Route['name'],
  component: Route['component'],
  metaOverrides: Partial<RouteMeta> = {}
): Route {
  const meta = getDefaultMeta()
  meta.layout.type = Layouts.Default
  meta.layout.isError404 = false
  Object.assign(meta, metaOverrides)

  return {
    path: `/${path}`,
    name,
    component,
    meta
  }
}
```

**File:** `{pages-utils}/group.ts`
```ts
import type { RouteMeta } from 'vue-router'

import type { Route } from '{pages-types}'

export function group(
  meta: {
    prefix?: string
    layout: RouteMeta['layout']['type']
    middleware?: RouteMeta['middleware']
    ssr?: boolean
  },
  routes: Route[]
) {
  return routes.map((route) => {
    if (meta.prefix) {
      route.path = `/${meta.prefix}${route.path}`
    }

    route.meta.layout.type = meta.layout

    if (meta.middleware) {
      route.meta.middleware.push(...meta.middleware)
    }

    if (meta.ssr !== undefined && route.meta.ssr === undefined) {
      route.meta.ssr = meta.ssr
    }

    return route
  })
}
```

**File:** `{pages-utils}/redirect.ts`
```ts
import type { RouteRecordRedirect } from 'vue-router'

import { Layouts } from '{pages-config}'
import type { RouteNames } from '{shared-config}'
import { getDefaultMeta } from './meta'

export function redirect(path: string, to: RouteNames, forwardParams = false): RouteRecordRedirect {
  const meta = getDefaultMeta()
  meta.layout.type = Layouts.Default
  meta.layout.isError404 = false

  return {
    path: `/${path}`,
    redirect: forwardParams ? (route) => ({ name: to, params: route.params }) : { name: to },
    meta
  }
}
```

**File:** `{pages-utils}/meta.ts`
```ts
import type { RouteMeta } from 'vue-router'

import { Layouts } from '{pages-config}'

export function getDefaultMeta(): RouteMeta {
  return {
    layout: {
      type: Layouts.Error,
      component: null,
      isError404: true
    },
    middleware: []
  }
}
```

**File:** `{pages-utils}/index.ts`
```ts
export { group } from './group'
export { getDefaultMeta } from './meta'
export { page } from './page'
export { redirect } from './redirect'
```

**File:** `{routes}/default.ts`
```ts
import { RouteNames } from '{shared-config}'

import { Layouts } from '{pages-config}'
import { group, page } from '{pages-utils}'

export default [
  ...group(
    {
      layout: Layouts.Default,
      ssr: true
    },
    [page('', RouteNames.Home, () => import('{pages-ui}/home/HomePage.vue'))]
  )
]
```

**File:** `{routes}/auth.ts`
```ts
import { RouteNames } from '{shared-config}'

import { Layouts } from '{pages-config}'
import { group, page } from '{pages-utils}'

export default [
  ...group({ layout: Layouts.Default }, [
    page('auth/callback', RouteNames.AuthCallback, () => import('{pages-ui}/auth/AuthCallbackPage.vue'))
  ])
]
```

**File:** `{routes}/blog.ts`
```ts
import { Layouts } from '{pages-config}'

import { RouteNames } from '{shared-config}'

import { group, page, redirect } from '{pages-utils}'

export default [
  ...group({ layout: Layouts.Default, ssr: true }, [
    page('blog', RouteNames.Blog, () => import('{pages-ui}/blog/BlogPage.vue')),
    page('blog/:categorySlug', RouteNames.BlogCategory, () => import('{pages-ui}/blog/BlogCategoryPage.vue')),
    page(
      'blog/:categorySlug/:articleSlug',
      RouteNames.BlogArticle,
      () => import('{pages-ui}/blog/BlogArticlePage.vue')
    )
  ]),
  redirect('old-blog/:categorySlug/:articleSlug', RouteNames.BlogArticle, true)
]
```

**File:** `{routes}/products.ts`
```ts
import { Layouts } from '{pages-config}'

import { RouteNames } from '{shared-config}'

import { group, page } from '{pages-utils}'

export default [
  ...group({ layout: Layouts.Default }, [
    page('products', RouteNames.Product, () => import('{pages-ui}/products/ProductsPage.vue'))
  ])
]
```

**File:** `{routes}/index.ts`
```ts
import authRoutes from './auth'
import blogRoutes from './blog'
import defaultRoutes from './default'
import productRoutes from './products'

const routes = [...defaultRoutes, ...blogRoutes, ...productRoutes, ...authRoutes]

export { routes }
```

**File:** `{pages-ui}/blog/BlogArticlePage.vue`
```vue
<script lang="ts" setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'

import { ArticleDetails } from '{widget}/blog/article-details'
import { BlogArticleBreadcrumbs } from '{widget}/blog/blog-article-breadcrumbs'

import { PageContainer, PageWrapper } from '{shared-ui}/containers'

const route = useRoute()

const categorySlug = computed(() => route.params.categorySlug as string)
const articleSlug = computed(() => route.params.articleSlug as string)
</script>

<template>
  <PageWrapper>
    <PageContainer variant="reading" class="grid gap-2.5 py-5 lg:gap-5 lg:pt-7.5 lg:pb-10">
      <BlogArticleBreadcrumbs :article-slug="articleSlug" :category-slug="categorySlug" />

      <ArticleDetails :article-slug="articleSlug" :category-slug="categorySlug" />
    </PageContainer>
  </PageWrapper>
</template>
```
