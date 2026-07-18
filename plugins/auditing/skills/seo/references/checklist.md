# SEO baseline checklist

The baseline this plugin's `seo` audit checks. Each item names the **remediating skill** to defer to
for a fix — always fully qualified (`knowledge-seo:<skill>`), because bare names collide across
plugins (`knowledge-vue:robots` and `knowledge-vue:seo` both exist). Invoke the named skill by name;
never reference it by file path.

---

## Project-level (checked once per project)

| Item | Detail | Remediating skill |
|------|--------|-------------------|
| robots.txt present | File exists at site root | knowledge-seo:robots |
| robots.txt: production not closed | `Disallow: /` must not appear on a live production site | knowledge-seo:robots |
| robots.txt: Sitemap directive | `Sitemap:` line points to sitemap.xml | knowledge-seo:robots |
| AI-crawler decision documented | An explicit stance on AI training crawlers (allow / disallow) is stated in robots.txt | knowledge-seo:robots |
| sitemap.xml present | XML sitemap exists and is referenced from robots.txt | knowledge-seo:sitemaps |
| Organization + WebSite schema on home page | Structured data for the organization and site identity is present on the home page | knowledge-seo:structured-data |
| Favicon | `<link rel="icon">` present; file resolves | knowledge-seo:meta-tags |
| Site-name title template | A layout-level title suffix/prefix provides the site name on every page | knowledge-seo:meta-tags |
| HTTPS + HSTS | Site is served over HTTPS; HSTS header is set | knowledge-seo:page-experience |
| Security headers | At minimum: `X-Frame-Options`, `X-Content-Type-Options`, `Referrer-Policy` | knowledge-seo:page-experience |
| hreflang scaffold (multilingual projects only) | If the site targets more than one language/region, hreflang is scaffolded | knowledge-seo:international |

---

## Page-level (checked for every public page)

| Item | Detail | Remediating skill |
|------|--------|-------------------|
| `<title>` present and unique | Non-empty, unique across all pages | knowledge-seo:meta-tags |
| `<meta name="description">` present and unique | Non-empty, unique per page | knowledge-seo:meta-tags |
| `<link rel="canonical">` present | Self-referencing, absolute URL, correct scheme and host | knowledge-seo:meta-tags |
| `<meta name="robots">` intent | Non-default values (noindex, nofollow) are intentional; private pages carry noindex | knowledge-seo:meta-tags |
| `og:title`, `og:description`, `og:url` present | Open Graph basics complete | knowledge-seo:social-preview |
| `og:image` present and meets spec | Absolute URL, recommended 1200×630 px minimum | knowledge-seo:social-preview |
| `og:image:alt` present | Non-empty alt text for the OG image | knowledge-seo:social-preview |
| `twitter:card` present | At minimum `summary` or `summary_large_image` | knowledge-seo:social-preview |
| `<meta name="viewport">` present | Required for mobile rendering | knowledge-seo:page-experience |
| Server-rendered for indexable routes | Indexable routes deliver meaningful HTML in the initial HTTP response (in a Vue app this is `meta.ssr`; in Next.js this is SSR/SSG; stack-dependent) | knowledge-seo:javascript-seo |
| BreadcrumbList schema on non-home pages | Pages more than one level deep carry BreadcrumbList structured data | knowledge-seo:structured-data |
| Private pages carry noindex | Any page not intended for the index has `<meta name="robots" content="noindex">` | knowledge-seo:meta-tags |

---

## Content-level (checked per content type found on a page)

For content→schema recognition, **reuse the recognition table owned by the `knowledge-seo:structured-data`
skill** — do NOT redefine the mapping here. Invoke that skill to obtain it. Apply it as follows:

1. Identify which content types are present on the page using the recognition table.
2. For each recognized content type, verify the matching schema is present, valid (passes Rich Results Test or equivalent), and mirrors visible on-page content.
3. Flag any recognized content type that lacks its expected schema.

| Item | Detail | Remediating skill |
|------|--------|-------------------|
| Schema matches recognized content types | Per the recognition table owned by `knowledge-seo:structured-data` | knowledge-seo:structured-data |
| Schema is valid | No missing required fields; no contradictions with visible content | knowledge-seo:structured-data |
| Image alt attributes present | Every content image has a descriptive `alt` attribute | knowledge-seo:media-seo |
| Image filenames are descriptive | Filenames are human-readable, not hashed or auto-generated codes | knowledge-seo:media-seo |
| Images included in sitemap (if applicable) | Key images are listed in the sitemap or an image sitemap extension | knowledge-seo:media-seo |

---

## Technical (checked at build/deploy level)

| Item | Detail | Remediating skill |
|------|--------|-------------------|
| Real HTTP status codes | No soft-404s (pages returning 200 with "not found" content) | knowledge-seo:canonicalization-and-redirects |
| No redirect chains | A→B→C chains are collapsed to A→C | knowledge-seo:canonicalization-and-redirects |
| History API routing / crawlable `<a href>` | Navigation uses History API (not hash-based); all internal links use `<a href>` so crawlers can follow them | knowledge-seo:javascript-seo · knowledge-seo:url-structure |
| Faceted / pagination crawl safety | Faceted parameters and paginated series are handled to avoid crawl budget waste and duplicate content | knowledge-seo:url-structure |
| Core Web Vitals thresholds | LCP ≤ 2.5 s, INP ≤ 200 ms, CLS ≤ 0.1 (measure with CrUX / PSI; static check only flags obvious anti-patterns such as unoptimized render-blocking resources) | knowledge-seo:page-experience |
| Hashed / cache-busted static assets | JS and CSS assets include a content hash for long-term caching | knowledge-seo:javascript-seo |
| Security headers (technical layer) | Verify headers are set at the HTTP response level, not only via meta tags | knowledge-seo:page-experience |
| Agent-friendly markup | Pages render meaningful HTML without JavaScript execution required for core content (verify by disabling JS or inspecting raw HTML response) | knowledge-seo:javascript-seo |
