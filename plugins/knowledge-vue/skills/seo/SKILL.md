---
name: seo
description: Use when wiring SEO meta tags, Open Graph properties, or JSON-LD structured data into a Vue page via @unhead/vue. Covers the Vue delivery layer only — for SEO principles defer to the `meta-tags`, `structured-data`, `social-preview`, `canonicalization-and-redirects`, and `international` skills from the knowledge-seo plugin. For server-side head rendering defer to the active project-type doc (core/project-types/<t>.md).
---

# seo (Vue) — head/meta/JSON-LD delivery via @unhead

Read `../../core/placement.md` for the token vocabulary; paths resolve in the active architecture doc.

Read `references/seo.md` and reproduce it — it holds the complete files for the seo lib, the
schema builders and a consuming page.

## Rules

- [invariant · desired] Application code — pages, widgets, entities, and layouts — NEVER imports `@unhead/vue` directly; it imports `useSeoMeta` and `useJsonLd` from the seo-lib barrel (`{shared-lib}/seo`). The one sanctioned exception is the head plugin factory (`{plugins}/head.ts`), owned by the active project-type bootstrap etalon, which legitimately imports `@unhead/vue` to construct the head instance itself.
- [invariant · desired] SEO meta is set at the page level (`{pages-ui}/<domain>/<Name>Page.vue`), once, at the top of `<script setup>`. JSON-LD is placed where its source data lives, typically the same page. Never call `useSeoMeta` from a widget — meta would be applied twice on the same route.
- [invariant · desired] All options are passed reactively: via a `computed` getter or a value accepted by `MaybeRefOrGetter`. A plain bare object is not reactive and will not update on navigation.
- [invariant · desired] The site name is applied once via a root `titleTemplate` in `{app}`. Pages set only the clean page title string — no per-page suffix.
- [invariant · desired] JSON-LD content is XSS-escaped before injection: `.replace(/</g, '\\u003c')` converts every `<` to its six-character Unicode escape, preventing `</script>` injection. The double backslash is load-bearing — a single backslash (`'<'`) is a JS Unicode-escape literal that the engine collapses back into a literal `<` at parse time, so the `.replace()` silently becomes a no-op with zero XSS protection.
- [invariant · desired] `buildCanonical(route)` enforces the canonical query-allowlist via vue-router and returns the canonical path. `og:url` is set to the same canonical value. Absolute URLs are produced by `buildAbsoluteUrl`, which reads the origin from an env variable and emits a warning in production when the variable is empty.
- [invariant · desired] A schema factory accepts a neutral input type (`*SchemaInput`), never a domain entity. The page maps `entity → input` before calling the factory.

## seo-lib shape

`{shared-lib}/seo/useSeoMeta.ts` accepts a `MaybeRefOrGetter` options object (title,
description, an optional `ogImage`, an optional `canonical` override) and calls `useHead`
inside a getter. It truncates the title and description before use — long values overflow
search-result and social-card snippets — and builds `og:title`/`og:description`/Twitter meta
plus the `canonical` link from `buildCanonical(route)` when no explicit override is given.

`{shared-lib}/seo/buildCanonical.ts` and `buildAbsoluteUrl.ts` implement the canonical-URL
rule above: `buildCanonical` keeps only an allow-listed set of query params, sorts them for a
stable string, and delegates to `buildAbsoluteUrl`, which prepends the origin read from an env
variable and warns in production when that variable is empty.

`{shared-lib}/seo/useJsonLd.ts` calls `useHead` with a `script` entry of type
`application/ld+json`, whose `innerHTML` is the schema JSON with every `<` escaped per the rule
above before injection.

A consuming page (see `references/seo.md`'s `HomePage.vue`) imports `useSeoMeta` and
`useJsonLd` from the seo-lib barrel, calls `useSeoMeta` once at the top of `<script setup>`,
and calls `useJsonLd` with a schema built by a factory from `{shared-lib}/seo/schemas`.

## titleTemplate (once, in {app})

The head **instance** is created by the `createHead()` plugin factory in `{plugins}/head.ts` and
registered via `app.use(head)` in the app factory — see the `plugin-registration` skill and the
active project-type doc (`core/project-types/<t>.md`). The factory's shape depends on the
project type: SSR's `createHead({ ssr })` is async and dynamically imports the server or client
`unhead` build at runtime per request (`core/project-types/ssr.md`,
`core/references/bootstrap-ssr.md`); CSR's `createHead()` is sync, takes no arguments, and
statically imports the client `unhead` build (`core/references/bootstrap-csr.md`). Do NOT create
an ad-hoc `createHead({...})` here. The site-name
`titleTemplate` is configured **once**, isomorphically, in the root component's `<script
setup>`, by calling `useTitleTemplate(siteName)` — a small composable exported from the seo-lib
barrel (`{shared-lib}/seo`) that owns the `useHead({ titleTemplate: ... })` call. The root
component imports `useTitleTemplate` from `{shared-lib}/seo` and never imports `@unhead/vue`
itself — see the `layouts` skill's `references/layouts.md` (SSR) / `layouts.csr.md` (CSR) for
the exact call site.

## Placement (tokens)

- [invariant · desired] `useSeoMeta`, `useJsonLd`, schema factories, `buildCanonical`, `buildAbsoluteUrl` → `{shared-lib}/seo`.
- [invariant · desired] `titleTemplate` root config → `{app}`.
- [invariant · desired] Per-page `useSeoMeta` / `useJsonLd` calls → `{pages-ui}/<domain>/<Name>Page.vue`.

## ✅ / ❌

| ✅ Do | ❌ Do not |
|---|---|
| Import `useSeoMeta` / `useJsonLd` from `{shared-lib}/seo` | Import `useHead` or `@unhead/vue` outside `{shared-lib}/seo` |
| Call `useSeoMeta` once, at the top of the page component | Call `useSeoMeta` from a widget or entity component |
| Pass a `computed` getter so meta updates reactively | Pass a plain object literal (not reactive) |
| Escape JSON-LD with `.replace(/</g, '\\u003c')` | Inject raw JSON-LD without escaping `<` |
| Set `og:url` to the value returned by `buildCanonical(route)` | Set `og:url` to `window.location.href` or a hardcoded string |
| Declare `titleTemplate` once in `{app}` via `useTitleTemplate` from `{shared-lib}/seo` | Append the site name inside the per-page title string, or call `useHead({ titleTemplate })` directly in `{app}` |
| Map entity → `*SchemaInput` in the page before calling the factory | Pass a raw domain entity to a schema factory |

## Related skills (by name)

- `meta-tags` — SEO meta tag principles (knowledge-seo)
- `structured-data` — JSON-LD and schema.org principles (knowledge-seo)
- `social-preview` — Open Graph and Twitter Card principles (knowledge-seo)
- `canonicalization-and-redirects` — canonical URL strategy (knowledge-seo)
- `international` — hreflang and locale principles (knowledge-seo)
- `core/project-types/<t>.md` — server-side head rendering for the active project type
- `plugin-registration` — wiring a Vue plugin into the app (knowledge-vue)
