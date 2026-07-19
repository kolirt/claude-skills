---
name: sitemaps
description: Use when creating or maintaining an XML sitemap — structure, lastmod, sitemap index, image/video/news, submission.
---

# Sitemaps — XML sitemap structure and submission

An XML sitemap tells search engines which URLs exist on a site and provides
optional metadata (last-modified date, alternate-language versions, media).
This skill covers file structure, per-URL rules, sitemap extensions, index
files, and submission channels.

## Rules

### Structure and URL inclusion

- [invariant · desired] Use **absolute URLs** in every `<loc>` element
  (e.g. `https://example.com/page`). Relative paths are invalid per the
  Sitemap Protocol. ✅ do: always include the scheme and host.
- [invariant · desired] Include **only canonical, indexable URLs** — no
  URLs that return a redirect, carry a `noindex` directive, or point to a
  non-canonical version. ❌ don't: add paginated duplicates, session-ID
  variants, or any URL you would not want indexed.
- [preference · desired] Omit `<priority>` and `<changefreq>` — Google
  ignores both fields. Including them adds noise without benefit.
  ✅ do: omit or strip these tags to keep the file lean.
- [preference · desired] Include `<lastmod>` **only when the value is
  accurate and verifiable** (e.g. a real database `updated_at` timestamp,
  formatted as `YYYY-MM-DD` or full ISO 8601). ❌ don't: set `<lastmod>`
  to the current date on every crawl or generation run — search engines
  learn to distrust inflated signals.
- [anti-pattern · desired] Never list URLs that respond with 3xx, 4xx, or
  5xx status codes. A sitemap polluted with broken or redirected URLs wastes
  crawl budget and undermines trust.

### File limits and sitemap index

- [invariant · desired] A single sitemap file must not exceed **50,000 URLs
  or 50 MB uncompressed**. Beyond either limit, split into multiple sitemap
  files and reference them from a **sitemap index** (`<sitemapindex>`).
  ✅ do: shard by section (e.g. `/products/`, `/blog/`) for clarity.
- [invariant · desired] The sitemap index file also uses absolute URLs in
  each `<loc>` and may include `<lastmod>` per child sitemap (same accuracy
  rule applies).

```xml
<!-- sitemap index example -->
<?xml version="1.0" encoding="UTF-8"?>
<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <sitemap>
    <loc>https://example.com/sitemaps/pages.xml</loc>
    <lastmod>2024-03-15</lastmod>
  </sitemap>
  <sitemap>
    <loc>https://example.com/sitemaps/products.xml</loc>
  </sitemap>
</sitemapindex>
```

### Extensions

- [preference · desired] Use **image sitemaps** (`xmlns:image`) to help
  Google discover images that may not be found through regular crawling.
  Each `<url>` can contain up to 1,000 `<image:image>` child elements.
- [preference · desired] Use **video sitemaps** (`xmlns:video`) to provide
  structured metadata (title, description, thumbnail, duration) for hosted
  video content.
- [preference · desired] Use **news sitemaps** (`xmlns:news`) for article
  publishers; include only articles published within the last 48 hours and
  supply `<news:publication_date>` in W3C date format.
- [preference · desired] Declare **hreflang alternates via sitemap** using
  the `xmlns:xhtml` extension when you need to signal language/region
  variants without modifying page HTML or HTTP headers. Each URL must list
  all its alternates (including a self-referencing entry) as
  `<xhtml:link rel="alternate" hreflang="..." href="..."/>` siblings.
  ❌ don't: mix hreflang sitemap declarations with HTML `<link rel="alternate">`
  on the same pages — pick one method per site. Full hreflang strategy is
  covered by the `international` skill.

```xml
<!-- hreflang via sitemap (abbreviated) -->
<url>
  <loc>https://example.com/en/page</loc>
  <xhtml:link rel="alternate" hreflang="en" href="https://example.com/en/page"/>
  <xhtml:link rel="alternate" hreflang="fr" href="https://example.com/fr/page"/>
  <xhtml:link rel="alternate" hreflang="x-default" href="https://example.com/en/page"/>
</url>
```

### robots.txt integration

- [invariant · desired] Reference the sitemap (or sitemap index) from
  `robots.txt` using the `Sitemap:` directive with the absolute URL.
  This lets all crawlers discover it without relying on Search Console alone.
  Full `robots.txt` authoring is covered by the `robots` skill from knowledge-seo.

```
Sitemap: https://example.com/sitemap-index.xml
```

### Submission

- [preference · desired] Submit the sitemap via **Google Search Console**
  (Sitemaps report) to trigger reprocessing and get indexing feedback
  (errors, warnings, discovered URL count).
- [preference · desired] For Bing, use the **Bing URL Submission API** to
  submit sitemaps or individual URLs. Note: the Bing URL Submission API is
  a distinct product from **IndexNow** — they use different endpoints and
  authentication. IndexNow is covered by the `indexnow` skill.
- [anti-pattern · desired] Do not rely solely on passive discovery (linked
  URLs, `robots.txt`). Submit proactively after significant content
  additions or restructuring to reduce discovery lag.

## Related skills (by name)

- `robots` from knowledge-seo — authoring `robots.txt`, including the `Sitemap:` directive
- `international` — full hreflang strategy across HTML, HTTP headers, and sitemaps
- `indexnow` — real-time URL push notifications (IndexNow protocol)
- `canonicalization-and-redirects` — canonical URL selection and redirect rules
