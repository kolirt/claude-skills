---
name: url-structure
description: Use when designing URLs, routes, pagination, faceted navigation, or internal linking — readable URLs, crawl-safe filters/pagination, crawlable internal links.
---

# url-structure — URL design, crawl control, and internal linking

Stack-independent rules for structuring URLs so they are human-readable, crawl-efficient, and free of duplicate-content traps. Covers readable URL conventions, faceted-navigation crawl control, pagination patterns, and internal-linking architecture.

## Rules

### Readable URLs

- [invariant · desired] Use **hyphens** to separate words in URL path segments — never underscores.
  - ✅ do: `/running-shoes/womens-trail`
  - ❌ don't: `/running_shoes/womens_trail` — search engines historically treat underscores as word joiners, not separators.
- [invariant · desired] Path segments are **lowercase** — mixed-case paths create duplicate-content pairs unless a canonical or redirect is in place.
  - ✅ do: `/blog/seo-guide`
  - ❌ don't: `/Blog/SEO-Guide`
- [invariant · desired] **Session IDs, tracking tokens, and click-attribution query strings are never part of the canonical URL.** Strip them server-side before the canonical is formed; include them only in analytics layers (e.g. GA4 client-side parameters, not in the URL served to crawlers).
  - ❌ don't: `/checkout?sessionid=abc123` as a canonical URL.
- [preference · desired] URL hierarchy should reflect **topical grouping** — parent paths group related content so crawlers infer topic relationships from the path itself.
  - ✅ do: `/shoes/running/trail` (category → sub-category → facet)
  - ❌ don't: `/p/12345` (opaque IDs carry no topical signal).
- [preference · desired] Keep paths **short and meaningful** — remove stop words when they add no topical value, but never truncate to the point of ambiguity.

### Faceted navigation crawl control

- [invariant · desired] Filter and sort URL combinations that produce **duplicate or thin content** must be blocked from indexing. Use `robots.txt` disallow rules or `noindex` meta tags for this purpose (see the **robots** and **meta-tags** skills for the exact mechanisms).
  - ✅ do: block `/products?sort=price-asc`, `/products?color=red&size=M` when those pages duplicate the base category page content.
  - ❌ don't: leave all filter/sort parameter combinations open to crawlers — combinatorial explosion creates thousands of near-duplicate URLs.
- [preference · desired] If a faceted combination creates genuinely unique, high-value content (a distinct landing page), give it a **clean, static URL** and treat it as a regular indexable page rather than a query-parameter variant.
- [anti-pattern · desired] Relying solely on `noindex` to control faceted URLs without also blocking crawl via `robots.txt` wastes crawl budget — the crawler still visits and renders the page even if it does not index it.

### Pagination, load-more, and infinite scroll

- [invariant · desired] Every page in a paginated sequence has a **persistent, indexable URL** — `?page=2`, `/page/2`, or an equivalent stable parameter. Transient or session-scoped page identifiers are not acceptable.
  - ✅ do: `/articles?page=3` — bookmarkable, shareable, crawlable.
  - ❌ don't: load content via a stateful cursor that has no URL representation.
- [invariant · desired] Each paginated page must be **sequentially crawlable**: the rendered HTML includes a visible `<a href>` link to the next page (and optionally previous page) so crawlers can walk the sequence without JavaScript.
- [invariant · desired] Every page in the sequence must **link back to page 1** (the root paginated URL) so crawlers can discover the canonical entry point of the sequence.
- [anti-pattern · desired] Do not rely on deprecated `rel="next"` / `rel="prev"` link hints as an **indexing signal** — major crawlers dropped support for these as a ranking/merging mechanism. Crawlable `<a href>` links in the content are the reliable signal.
- [preference · desired] For **infinite scroll**: render an equivalent paginated HTML view (e.g. `/feed?page=N`) accessible at a stable URL. The infinite-scroll UI can load content dynamically, but the paginated URL equivalent must exist for crawlers.
- [preference · desired] For **load-more** patterns: ensure the "load more" button is a real `<a href>` pointing to the next page URL, not a `<button>` with a JavaScript click handler — this makes the next page crawlable without JavaScript execution.

### Internal-linking architecture

- [invariant · desired] Internal links must be **crawlable `<a href>` elements** pointing to the destination URL — not JavaScript click handlers, `window.location` assignments, or `onclick` attributes without an `href`.
  - ✅ do: `<a href="/category/shoes">Shoes</a>`
  - ❌ don't: `<span onclick="navigate('/category/shoes')">Shoes</span>` — invisible to crawlers that do not execute JavaScript.
- [invariant · desired] Use **descriptive anchor text** that reflects the target page's topic. Generic anchors ("click here", "read more") dilute the topical signal passed through the link.
  - ✅ do: `<a href="/guides/keyword-research">Keyword research guide</a>`
  - ❌ don't: `<a href="/guides/keyword-research">Read more</a>`
- [preference · desired] Structure internal links as a **hub-and-spoke architecture**: high-authority hub pages (category, pillar, index) link to spoke pages (articles, products), and spoke pages link back to the hub. This concentrates crawl depth and distributes link equity predictably.
- [invariant · desired] **No page should be an orphan** — every indexable page must be reachable via at least one crawlable `<a href>` from another indexed page. Pages reachable only through sitemaps or direct URL entry are fragile; a crawlable in-site link path is required.
  - ✅ do: audit for orphan pages whenever routes are added or removed; add linking from a relevant hub or index page.
  - ❌ don't: publish a page and add it only to the sitemap without adding an in-site `<a href>` link from existing content.
- [preference · desired] Keep **link depth** (clicks from the home page) within 3–4 levels for important pages. Pages buried deeper than 4 clicks from the root receive less crawl priority and link equity.

## Related skills (by name)

- **canonicalization-and-redirects** — canonical URL declaration, redirect chains, and URL consolidation.
- **robots** — `robots.txt` disallow rules and crawl-budget control for faceted/parameterised URLs.
- **javascript-seo** — crawlability requirements when navigation or content is rendered client-side.
- **sitemaps** — declaring indexable URLs to crawlers independently of internal linking.
