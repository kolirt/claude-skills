# seo — full-file etalon

Source: the shared `seo` lib (`useSeoMeta`, `useJsonLd`, `buildCanonical`, `buildAbsoluteUrl`,
schema factories) plus one consuming page. The head plugin factory (`{plugins}/head.ts`) carries
no SEO logic and is omitted here — see `core/project-types/<t>.md`.

`useTitleTemplate` is a deliberate addition (desired shape per the `seo` skill's
`titleTemplate` invariant, not present in the source project) — its call site is already
wired into `{app}/App.vue` (`layouts` skill's etalon), not reproduced here.

## Files

- `{shared-lib}/seo/useSeoMeta.ts`
- `{shared-lib}/seo/useJsonLd.ts`
- `{shared-lib}/seo/useTitleTemplate.ts`
- `{shared-lib}/seo/buildCanonical.ts`
- `{shared-lib}/seo/buildAbsoluteUrl.ts`
- `{shared-lib}/seo/schemas/breadcrumbListSchema.ts`
- `{shared-lib}/seo/schemas/itemListSchema.ts`
- `{shared-lib}/seo/schemas/index.ts`
- `{shared-lib}/seo/index.ts`
- `{pages-ui}/home/HomePage.vue`

**File:** `{shared-lib}/seo/useSeoMeta.ts`

```ts
import { useHead } from '@unhead/vue'
import { type MaybeRefOrGetter, toValue } from 'vue'
import { useRoute } from 'vue-router'

import { buildCanonical } from './buildCanonical'

interface SeoMetaOptions {
  title: string
  description: string
  ogImage?: string
  canonical?: string
}

function useSeoMeta(options: MaybeRefOrGetter<SeoMetaOptions>): void {
  const route = useRoute()

  useHead(() => {
    const opts = toValue(options)
    const title = opts.title.slice(0, 70)
    const description = opts.description.slice(0, 160)
    const canonical = opts.canonical ?? buildCanonical(route)
    const meta = [
      { name: 'description', content: description },
      { property: 'og:title', content: title },
      { property: 'og:description', content: description },
      { property: 'og:type', content: 'website' },
      { property: 'og:url', content: canonical },
      { name: 'twitter:card', content: 'summary_large_image' },
      { name: 'twitter:title', content: title },
      { name: 'twitter:description', content: description }
    ]
    if (opts.ogImage) {
      meta.push({ property: 'og:image', content: opts.ogImage })
      meta.push({ name: 'twitter:image', content: opts.ogImage })
    }
    return {
      title,
      meta,
      link: [{ rel: 'canonical', href: canonical }]
    }
  })
}

export { useSeoMeta }
```

`og:url` is a desired-state addition (not in the source project): the `seo` skill's
canonical-URL invariant requires it set to the same `buildCanonical(route)` value.

`useJsonLd` below escapes `<` before injection — a deliberate hardening over the source's
bare `JSON.stringify` (unescaped JSON-LD is an XSS vector with user-supplied schema fields).

**File:** `{shared-lib}/seo/useJsonLd.ts`

```ts
import { useHead } from '@unhead/vue'
import { type MaybeRefOrGetter, toValue } from 'vue'

function useJsonLd(schema: MaybeRefOrGetter<object>): void {
  useHead(() => ({
    script: [
      {
        type: 'application/ld+json',
        // Double backslash is load-bearing: a single backslash is a JS unicode-escape
        // literal resolved to `<` at parse time, making .replace() a silent no-op.
        innerHTML: JSON.stringify(toValue(schema)).replace(/</g, '\\u003c')
      }
    ]
  }))
}

export { useJsonLd }
```

**File:** `{shared-lib}/seo/useTitleTemplate.ts`

```ts
import { useHead } from '@unhead/vue'
import { type MaybeRefOrGetter, toValue } from 'vue'

function useTitleTemplate(siteName: MaybeRefOrGetter<string>): void {
  useHead(() => {
    const name = toValue(siteName)
    return {
      titleTemplate: (title) => (title ? `${title} — ${name}` : name)
    }
  })
}

export { useTitleTemplate }
```

Only place besides `useSeoMeta`/`useJsonLd` calling `useHead` directly — the skill's invariant
keeps `@unhead/vue` from leaking outside `{shared-lib}/seo`.

**File:** `{shared-lib}/seo/buildCanonical.ts`

```ts
import type { RouteLocationNormalizedLoaded } from 'vue-router'

import { buildAbsoluteUrl } from './buildAbsoluteUrl'

const ALLOWED_QUERY_PARAMS = new Set([
  'page',
  'type',
  'category',
  'tag',
  'featured',
  'sort',
  'layout'
])

function buildCanonical(route: RouteLocationNormalizedLoaded): string {
  const query = Object.entries(route.query)
    .filter(([key, value]) => ALLOWED_QUERY_PARAMS.has(key) && value !== undefined && value !== null && value !== '')
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([key, value]) => `${encodeURIComponent(key)}=${encodeURIComponent(String(value))}`)
    .join('&')

  return buildAbsoluteUrl(`${route.path}${query ? `?${query}` : ''}`)
}

export { buildCanonical }
```

**File:** `{shared-lib}/seo/buildAbsoluteUrl.ts`

```ts
function buildAbsoluteUrl(path: string): string {
  const origin = import.meta.env.VITE_APP_ORIGIN ?? ''

  if (!origin && import.meta.env.PROD) {
    console.warn('[seo] VITE_APP_ORIGIN is empty in production — absolute URLs will be host-relative.')
  }

  return `${origin}${path}`
}

export { buildAbsoluteUrl }
```

The production warning is a desired-state addition — the source project's `buildAbsoluteUrl`
silently omits it; the `seo` skill's invariant requires it.

**File:** `{shared-lib}/seo/schemas/breadcrumbListSchema.ts`

```ts
interface BreadcrumbItem {
  name: string
  url: string
}

function breadcrumbListSchema(items: BreadcrumbItem[]): object {
  return {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: items.map((item, index) => ({
      '@type': 'ListItem',
      position: index + 1,
      name: item.name,
      item: item.url
    }))
  }
}

export { breadcrumbListSchema }
```

**File:** `{shared-lib}/seo/schemas/itemListSchema.ts`

```ts
interface ItemListSchemaInput {
  url: string
  total: number
  items: Array<{
    name: string
    url: string
  }>
}

function itemListSchema(input: ItemListSchemaInput): object {
  return {
    '@context': 'https://schema.org',
    '@type': 'ItemList',
    url: input.url,
    numberOfItems: input.total,
    itemListElement: input.items.map((item, index) => ({
      '@type': 'ListItem',
      position: index + 1,
      name: item.name,
      url: item.url
    }))
  }
}

export { itemListSchema }
```

**File:** `{shared-lib}/seo/schemas/index.ts`

```ts
export { breadcrumbListSchema } from './breadcrumbListSchema'
export { itemListSchema } from './itemListSchema'
```

**File:** `{shared-lib}/seo/index.ts`

```ts
export { buildAbsoluteUrl } from './buildAbsoluteUrl'
export { buildCanonical } from './buildCanonical'
export { breadcrumbListSchema, itemListSchema } from './schemas'
export { useJsonLd } from './useJsonLd'
export { useSeoMeta } from './useSeoMeta'
export { useTitleTemplate } from './useTitleTemplate'
```

`titleTemplate` is desired, not present in the source project. `{app}/App.vue` lives in the
`layouts` skill's etalon (its canonical source), already wired with
`useTitleTemplate('<your-app-name>')` — substitute the real site name when reproducing it.

**File:** `{pages-ui}/home/HomePage.vue`

```vue
<script lang="ts" setup>
import { computed } from 'vue'

import { useConfirmModal } from '{shared-lib}/confirm-modal'

import { PostList } from '{widget}/blog/post-list'

import { breadcrumbListSchema, buildAbsoluteUrl, useJsonLd, useSeoMeta } from '{shared-lib}/seo'
import { PageContainer, PageWrapper } from '{shared-ui}/containers'
import { PrimaryButton } from '{shared-ui}/buttons'
import { ProfileField } from '{shared-ui}/field'
import { PromoBanner } from '{shared-ui}/banner'

useSeoMeta(
  computed(() => ({
    title: 'Blog — latest posts',
    description: 'Read the latest posts on the blog. Browse categories, tags, and featured articles.'
  }))
)

useJsonLd(breadcrumbListSchema([{ name: 'Home', url: buildAbsoluteUrl('/') }]))

const { confirm } = useConfirmModal()

async function onDeletePost() {
  const confirmed = await confirm({
    title: 'Delete post',
    message: 'This post will be permanently deleted.',
    variant: 'danger'
  })
  if (confirmed) {
    // delete the post
  }
}
</script>

<template>
  <PageWrapper with-character>
    <div class="flex w-full items-center justify-start gap-2.5 overflow-hidden px-2.5 py-2.5 xl:gap-5 xl:px-5 xl:py-5">
      <PromoBanner v-for="i in 8" :key="i" />
    </div>

    <PrimaryButton @click="onDeletePost"> Delete post </PrimaryButton>

    <PageContainer class="pb-20">
      <ProfileField />
    </PageContainer>

    <PostList />
  </PageWrapper>
</template>
```
