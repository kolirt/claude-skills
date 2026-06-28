# seo-audit checklist

Each item names the **owning skill** to defer to for a fix.

---

## Project-level (checked once per project)

| Item | Detail | Owning skill |
|------|--------|--------------|
| robots.txt present | File exists at site root | robots |
| robots.txt: production not closed | `Disallow: /` must not appear on a live production site | robots |
| robots.txt: Sitemap directive | `Sitemap:` line points to sitemap.xml | robots |
| AI-crawler decision documented | An explicit stance on AI training crawlers (allow / disallow) is stated in robots.txt | robots |
| sitemap.xml present | XML sitemap exists and is referenced from robots.txt | sitemaps |
| Organization + WebSite schema on home page | Structured data for the organization and site identity is present on the home page | structured-data |
| Favicon | `<link rel="icon">` present; file resolves | meta-tags |
| Site-name title template | A layout-level title suffix/prefix provides the site name on every page | meta-tags |
| HTTPS + HSTS | Site is served over HTTPS; HSTS header is set | page-experience |
| Security headers | At minimum: `X-Frame-Options`, `X-Content-Type-Options`, `Referrer-Policy` | page-experience |
| hreflang scaffold (multilingual projects only) | If the site targets more than one language/region, hreflang is scaffolded | international |

---

## Page-level (checked for every public page)

| Item | Detail | Owning skill |
|------|--------|--------------|
| `<title>` present and unique | Non-empty, unique across all pages | meta-tags |
| `<meta name="description">` present and unique | Non-empty, unique per page | meta-tags |
| `<link rel="canonical">` present | Self-referencing, absolute URL, correct scheme and host | meta-tags |
| `<meta name="robots">` intent | Non-default values (noindex, nofollow) are intentional; private pages carry noindex | meta-tags |
| `og:title`, `og:description`, `og:url` present | Open Graph basics complete | social-preview |
| `og:image` present and meets spec | Absolute URL, recommended 1200×630 px minimum | social-preview |
| `og:image:alt` present | Non-empty alt text for the OG image | social-preview |
| `twitter:card` present | At minimum `summary` or `summary_large_image` | social-preview |
| `<meta name="viewport">` present | Required for mobile rendering | page-experience |
| Server-rendered for indexable routes | Indexable routes deliver meaningful HTML in the initial HTTP response (in a Vue app this is `meta.ssr`; in Next.js this is SSR/SSG; stack-dependent) | javascript-seo |
| BreadcrumbList schema on non-home pages | Pages more than one level deep carry BreadcrumbList structured data | structured-data |
| Private pages carry noindex | Any page not intended for the index has `<meta name="robots" content="noindex">` | meta-tags |

---

## Content-level (checked per content type found on a page)

For content→schema recognition, **reuse the recognition table in `references/recognition.md` inside the `structured-data` skill** — do NOT redefine the mapping here. Apply it as follows:

1. Identify which content types are present on the page using the recognition table.
2. For each recognized content type, verify the matching schema is present, valid (passes Rich Results Test or equivalent), and mirrors visible on-page content.
3. Flag any recognized content type that lacks its expected schema.

| Item | Detail | Owning skill |
|------|--------|--------------|
| Schema matches recognized content types | See `structured-data` → `references/recognition.md` | structured-data |
| Schema is valid | No missing required fields; no contradictions with visible content | structured-data |
| Image alt attributes present | Every content image has a descriptive `alt` attribute | media-seo |
| Image filenames are descriptive | Filenames are human-readable, not hashed or auto-generated codes | media-seo |
| Images included in sitemap (if applicable) | Key images are listed in the sitemap or an image sitemap extension | media-seo |

---

## Technical (checked at build/deploy level)

| Item | Detail | Owning skill |
|------|--------|--------------|
| Real HTTP status codes | No soft-404s (pages returning 200 with "not found" content) | canonicalization-and-redirects |
| No redirect chains | A→B→C chains are collapsed to A→C | canonicalization-and-redirects |
| History API routing / crawlable `<a href>` | Navigation uses History API (not hash-based); all internal links use `<a href>` so crawlers can follow them | javascript-seo · url-structure |
| Faceted / pagination crawl safety | Faceted parameters and paginated series are handled to avoid crawl budget waste and duplicate content | url-structure |
| Core Web Vitals thresholds | LCP ≤ 2.5 s, INP ≤ 200 ms, CLS ≤ 0.1 (measure with CrUX / PSI; static check only flags obvious anti-patterns such as unoptimized render-blocking resources) | page-experience |
| Hashed / cache-busted static assets | JS and CSS assets include a content hash for long-term caching | javascript-seo |
| Security headers (technical layer) | Verify headers are set at the HTTP response level, not only via meta tags | page-experience |
| Agent-friendly markup | Pages render meaningful HTML without JavaScript execution required for core content (verify by disabling JS or inspecting raw HTML response) | javascript-seo |
