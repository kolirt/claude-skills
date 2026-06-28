---
name: seo
description: Use when wiring SEO meta tags, Open Graph properties, or JSON-LD structured data into a Vue page via @unhead/vue. Covers the Vue delivery layer only — for SEO principles defer to the `meta-tags`, `structured-data`, `social-preview`, `canonicalization-and-redirects`, and `international` skills from the knowledge-seo plugin. For server-side head rendering defer to the `ssr` skill.
---

# seo (Vue) — head/meta/JSON-LD delivery via @unhead

Read `../../core/placement.md`

## Rules

- [invariant · desired] `useHead` and every direct `@unhead/vue` import live ONLY inside `{shared-lib}/seo`. Pages, widgets, and entities NEVER import `@unhead` directly — they import `useSeoMeta` and `useJsonLd` from the seo-lib barrel.
- [invariant · desired] SEO meta is set at the page level (`{pages-ui}/<Name>Page.vue`), once, at the top of `<script setup>`. JSON-LD is placed where its source data lives, typically the same page. Never call `useSeoMeta` from a widget — meta would be applied twice on the same route.
- [invariant · desired] All options are passed reactively: via a `computed` getter or a value accepted by `MaybeRefOrGetter`. A plain bare object is not reactive and will not update on navigation.
- [invariant · desired] The site name is applied once via a root `titleTemplate` in `{app}`. Pages set only the clean page title string — no per-page suffix.
- [invariant · desired] JSON-LD content is XSS-escaped before injection: `.replace(/</g, '\u003c')` converts every `<` to its six-character Unicode escape, preventing `</script>` injection.
- [invariant · desired] `buildCanonical(route)` enforces the canonical query-allowlist via vue-router and returns the canonical path. `og:url` is set to the same canonical value. Absolute URLs are produced by `buildAbsoluteUrl`, which reads the origin from an env variable and emits a warning in production when the variable is empty.
- [invariant · desired] A schema factory accepts a neutral input type (`*SchemaInput`), never a domain entity. The page maps `entity → input` before calling the factory.

## seo-lib — useSeoMeta

```ts
// {shared-lib}/seo/useSeoMeta.ts
import { useHead } from '@unhead/vue'
import { toValue, type MaybeRefOrGetter } from 'vue'
import { useRoute } from 'vue-router'
import { buildCanonical, buildAbsoluteUrl } from './canonical'

export interface SeoMetaInput {
  title: string
  description: string
  siteName: string
  image?: string
  locale?: string
  robots?: string
}

export function useSeoMeta(input: MaybeRefOrGetter<SeoMetaInput>) {
  const route = useRoute()

  useHead(() => {
    const v = toValue(input)
    const title = v.title.slice(0, 70)
    const description = v.description.slice(0, 160)
    const canonical = buildAbsoluteUrl(buildCanonical(route))

    return {
      title,
      meta: [
        { name: 'description', content: description },
        { property: 'og:title', content: title },
        { property: 'og:description', content: description },
        { property: 'og:url', content: canonical },
        { property: 'og:site_name', content: v.siteName },
        { property: 'og:locale', content: v.locale ?? 'en_US' },
        ...(v.image
          ? [
              { property: 'og:image', content: v.image },
              { name: 'twitter:card', content: 'summary_large_image' },
            ]
          : []),
        { name: 'robots', content: v.robots ?? 'index, follow' },
      ],
      link: [{ rel: 'canonical', href: canonical }],
    }
  })
}
```

## seo-lib — canonical

```ts
// {shared-lib}/seo/canonical.ts
import type { RouteLocationNormalizedLoaded } from 'vue-router'

/** Query params that define content identity. All others (UTM, tracking, etc.) are dropped. */
const ALLOWED_QUERY_PARAMS = new Set(['page', 'sort', 'category', 'filter', 'q'])

/**
 * Prepend the site origin (from env) to a path.
 * Warns in production when VITE_APP_ORIGIN is not set — the resulting URL
 * will be relative and canonical tags may be ignored by crawlers.
 */
export function buildAbsoluteUrl(path: string): string {
  const origin = import.meta.env.VITE_APP_ORIGIN ?? ''
  if (!origin && import.meta.env.PROD) {
    console.warn('[seo] VITE_APP_ORIGIN is not set — canonical URL will be relative.')
  }
  return `${origin}${path}`
}

/**
 * Build a canonical URL for the given route.
 * Keeps only ALLOWED_QUERY_PARAMS, sorts them for a stable string,
 * drops tracking / UTM params, and returns an absolute URL.
 *
 * Example: /products?page=2&utm_source=email&sort=price
 *          → https://example.com/products?page=2&sort=price
 */
export function buildCanonical(route: RouteLocationNormalizedLoaded): string {
  const kept = Object.entries(route.query)
    .filter(([key]) => ALLOWED_QUERY_PARAMS.has(key))
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([key, value]) => `${encodeURIComponent(key)}=${encodeURIComponent(String(value ?? ''))}`)
    .join('&')

  const path = route.path + (kept ? `?${kept}` : '')
  return buildAbsoluteUrl(path)
}
```

## seo-lib — useJsonLd

```ts
// {shared-lib}/seo/useJsonLd.ts
import { useHead } from '@unhead/vue'
import { toValue, type MaybeRefOrGetter } from 'vue'

export function useJsonLd(schema: MaybeRefOrGetter<object>) {
  useHead(() => {
    const escaped = JSON.stringify(toValue(schema)).replace(/</g, '\u003c')
    return {
      script: [{ type: 'application/ld+json', innerHTML: escaped }],
    }
  })
}
```

## Page usage

```vue
<!-- {pages-ui}/product/ProductPage.vue -->
<script setup lang="ts">
import { computed } from 'vue'
import { useSeoMeta, useJsonLd } from '@/shared/lib/seo'
import { productSchema } from '@/shared/lib/seo/schemas/product'
import { useProductStore } from '@/entities/product'

const store = useProductStore()
const item = computed(() => store.current)

useSeoMeta(computed(() => ({
  title: item.value?.name ?? 'Product',
  description: item.value?.summary ?? '',
  image: item.value?.imageUrl,
  siteName: 'My Shop',
  locale: 'en_US',
})))

useJsonLd(computed(() => productSchema({
  name: item.value?.name ?? '',
  description: item.value?.summary ?? '',
  image: item.value?.imageUrl,
  price: item.value?.price,
  currency: item.value?.currency ?? 'USD',
})))
</script>
```

## titleTemplate (once, in {app})

```ts
// {app}/plugins/head.ts
import { createHead } from '@unhead/vue'

export const head = createHead({
  titleTemplate: (title) => (title ? `${title} — My Shop` : 'My Shop'),
})
```

Register `head` as a Vue plugin in `{app}` alongside other plugin registrations (see `plugin-registration`).

## Placement (tokens — resolve via `../../core/placement.md`)

- [invariant · desired] `useSeoMeta`, `useJsonLd`, schema factories, `buildCanonical`, `buildAbsoluteUrl` → `{shared-lib}/seo`.
- [invariant · desired] `titleTemplate` root config → `{app}`.
- [invariant · desired] Per-page `useSeoMeta` / `useJsonLd` calls → `{pages-ui}/<Name>Page.vue`.

## ✅ / ❌

| ✅ Do | ❌ Do not |
|---|---|
| Import `useSeoMeta` / `useJsonLd` from `{shared-lib}/seo` | Import `useHead` or `@unhead/vue` outside `{shared-lib}/seo` |
| Call `useSeoMeta` once, at the top of the page component | Call `useSeoMeta` from a widget or entity component |
| Pass a `computed` getter so meta updates reactively | Pass a plain object literal (not reactive) |
| Escape JSON-LD with `.replace(/</g, '\u003c')` | Inject raw JSON-LD without escaping `<` |
| Set `og:url` to the value returned by `buildCanonical(route)` | Set `og:url` to `window.location.href` or a hardcoded string |
| Declare `titleTemplate` once in `{app}` | Append the site name inside the per-page title string |
| Map entity → `*SchemaInput` in the page before calling the factory | Pass a raw domain entity to a schema factory |

## Related skills (by name)

- `meta-tags` — SEO meta tag principles (knowledge-seo)
- `structured-data` — JSON-LD and schema.org principles (knowledge-seo)
- `social-preview` — Open Graph and Twitter Card principles (knowledge-seo)
- `canonicalization-and-redirects` — canonical URL strategy (knowledge-seo)
- `international` — hreflang and locale principles (knowledge-seo)
- `ssr` — server-side head rendering (knowledge-vue)
- `plugin-registration` — wiring a Vue plugin into the app (knowledge-vue)
