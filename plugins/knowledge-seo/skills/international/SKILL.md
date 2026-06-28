---
name: international
description: Use for multilingual/multiregional sites — hreflang annotations, x-default, locale URL architecture, geotargeting.
---

# Internationalization & hreflang

This skill covers hreflang annotations, `x-default`, locale URL architecture, and
geotargeting signals for multilingual and multi-regional sites. It is stack-independent:
rules apply regardless of CMS, framework, or server technology.

## hreflang annotations

There are three equivalent delivery methods — choose exactly one per site; mixing methods
on the same page is unnecessary and can confuse validators.

**Method 1 — HTML `<link>` in `<head>`**

```html
<link rel="alternate" hreflang="en"    href="https://example.com/en/" />
<link rel="alternate" hreflang="en-US" href="https://example.com/en-us/" />
<link rel="alternate" hreflang="fr"    href="https://example.com/fr/" />
<link rel="alternate" hreflang="x-default" href="https://example.com/" />
```

**Method 2 — `Link:` HTTP response header** (useful for non-HTML resources such as PDFs)

```
Link: <https://example.com/en/>; rel="alternate"; hreflang="en",
      <https://example.com/fr/>; rel="alternate"; hreflang="fr",
      <https://example.com/>; rel="alternate"; hreflang="x-default"
```

**Method 3 — XML sitemap `<xhtml:link>` entries**

```xml
<url>
  <loc>https://example.com/en/</loc>
  <xhtml:link rel="alternate" hreflang="en"        href="https://example.com/en/" />
  <xhtml:link rel="alternate" hreflang="fr"        href="https://example.com/fr/" />
  <xhtml:link rel="alternate" hreflang="x-default" href="https://example.com/" />
</url>
```

### Reciprocal and self-referential requirement

Every page in the hreflang set must link **to all other variants** and **to itself**. A
page that receives an incoming hreflang pointer but does not return the pointer is called
a non-reciprocal pair; Google ignores that specific pair. However, the remaining
**valid reciprocal subsets are still processed** — a few missing return tags do not
invalidate the entire annotation set.

### `x-default`

`x-default` designates the fallback page served when no other variant matches the user's
language or region (e.g. a language-selector landing page, or the generic English version).

- [preference · desired] Add `x-default` to every hreflang set.
  **why**: without it, Google has no safe fallback, and users whose language is not covered
  may land on a random variant.

> **Nuance**: `x-default` is recommended, not required. Omitting it is valid; it merely
> means Google picks the most suitable variant on its own.

### Language codes

| Format | Example | When to use |
|--------|---------|-------------|
| Language only | `en`, `fr`, `de` | Content is the same for all regions that speak that language |
| Language + region | `en-US`, `en-GB`, `fr-CA` | Content, pricing, or legal text differs per region |

Use ISO 639-1 language codes and ISO 3166-1 Alpha-2 region codes. Never invent codes;
Google ignores unrecognised values.

## Rules

- [invariant · desired] Every variant in the hreflang set must include a **self-referential**
  `hreflang` tag pointing to its own URL.
  **why**: without the self-reference, Google cannot confirm that the page is a canonical
  member of the set.

- [invariant · desired] Use **reciprocal** hreflang — if page A declares an `hreflang`
  pointing to page B, then page B must declare a matching `hreflang` pointing back to A.
  ✅ do: every variant links to all others + itself.
  ❌ don't: add hreflang only on the "main" locale and leave the other locales annotation-free.
  **why**: non-reciprocal pairs are silently ignored; only complete pairs are processed.

- [preference · desired] Deliver hreflang via the method that best fits your infrastructure
  (HTML `<link>` for server-rendered HTML, HTTP header for PDFs/non-HTML, sitemap for
  large sites where per-page edits are impractical).
  ✅ do: pick one method consistently site-wide.
  ❌ don't: mix HTML `<link>` and sitemap entries for the same page.
  **why**: mixing methods adds maintenance overhead without benefit.

- [invariant · desired] Each localized URL must return HTTP 200 and be indexable (not
  blocked by `robots.txt`, not `noindex`).
  ✅ do: verify all variant URLs are crawlable before launching hreflang.
  ❌ don't: point hreflang at redirected or blocked URLs.
  **why**: Googlebot must be able to crawl and confirm both ends of a reciprocal pair.

- [anti-pattern · desired] Do **not** use IP-based auto-redirect to force users to a
  locale variant.
  ✅ do: detect language preference via `Accept-Language` and suggest the right variant
  with a banner, or use JavaScript-driven redirects alongside a persistent opt-out.
  ❌ don't: 302-redirect crawlers to a locale they cannot opt out of.
  **why**: Googlebot typically crawls from US IPs — auto-redirect hides all non-US
  variants from the crawler, making them unindexable.

## Multi-regional URL architecture

Three common patterns:

| Pattern | Example | Notes |
|---------|---------|-------|
| **ccTLD** | `example.fr`, `example.de` | Strongest geotargeting signal; requires separate domain registrations and server infrastructure |
| **Subdomain** | `fr.example.com` | Moderate; Search Console lets you set a country target per subdomain |
| **Subdirectory** | `example.com/fr/` | Weakest geotargeting signal alone; relies on Search Console setting and hreflang; easiest to manage |

- [preference · desired] Use ccTLDs when country-level brand separation and the strongest
  geotargeting signal are priorities and budget allows.
  **why**: Google treats ccTLDs as the clearest country indicator.

- [preference · desired] Use subdirectories for most multilingual sites — they share
  domain authority and are operationally simpler.
  **why**: a single Search Console property covers all locales; CDN and cache rules are
  centralised.

- [invariant · desired] Set a **geographic target** in Google Search Console for
  subdomains and subdirectories that serve a single country.
  ✅ do: assign a country target at the property or prefix level in Search Console.
  ❌ don't: rely on hreflang alone to communicate country targeting to Google.
  **why**: hreflang signals language+locale preference; the Search Console geo-target
  provides the explicit country signal.

- [anti-pattern · desired] Do **not** serve different locale content at the same URL
  based on IP without any URL distinction.
  ✅ do: each locale has its own distinct, crawlable URL.
  ❌ don't: return `/` with French content to French IPs and English content to US IPs.
  **why**: Google indexes one version of a URL — the locale-based content variation
  becomes invisible.

## What hreflang is NOT

- [invariant · desired] Google does **not** use hreflang (or the HTML `lang` attribute)
  to detect the language of a page — it detects language from the page content itself.
  hreflang only instructs Google **which variant to serve** to which audience.
  ✅ do: ensure on-page content, `<html lang>`, and hreflang codes are all consistent.
  ❌ don't: assume adding `hreflang="fr"` compensates for a page whose body is in English.
  **why**: inconsistency between hreflang declaration and actual page content leads to
  incorrect variant serving.

## Related skills (by name)

- `sitemaps` — delivering hreflang via XML sitemap; submitting locale sitemaps to Search Console.
- `canonicalization-and-redirects` — canonical tag behaviour across locale variants; redirect chains.
- `url-structure` — choosing URL patterns (subdirectory, subdomain, ccTLD) and slug conventions.
