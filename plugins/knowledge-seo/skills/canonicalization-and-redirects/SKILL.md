---
name: canonicalization-and-redirects
description: Use when handling canonical URLs, duplicate content, redirects, HTTP status codes, trailing slashes, or a site/HTTPS migration.
---

# canonicalization-and-redirects — URL consolidation, redirects, and HTTP status semantics

Stack-independent rules for telling crawlers which URL is the authoritative version of a page, how to follow redirects safely, and what HTTP status codes signal to indexing pipelines.

## Rules

### Canonical signals

- [invariant · desired] Every indexable HTML page carries **exactly one** `<link rel="canonical" href="...">` in `<head>` pointing to the preferred URL. When a page is its own canonical, use a **self-referencing** canonical — never omit it.
- [invariant · desired] The canonical URL must be **absolute**: scheme + host + path (e.g. `https://example.com/blog/post`). Relative canonicals are interpreted inconsistently across crawlers.
- [invariant · desired] For **non-HTML resources** (PDF, CSV, XML feeds, images served at a canonical endpoint), signal the preferred URL via the **HTTP `Link:` response header** — there is no `<head>` available:
  ```
  Link: <https://example.com/report.pdf>; rel="canonical"
  ```
  - ✅ do: emit the `Link:` header from the server or CDN edge for every PDF/binary resource that has a canonical URL.
  - ❌ don't: rely on a `<link>` tag inside the PDF body — crawlers do not read it.
- [invariant · desired] Pick **one canonical method per resource** and be consistent. Mixing `<link rel="canonical">` with `Link:` on the same HTML page produces conflicting signals; the `Link:` header wins in some crawlers and loses in others.
- [invariant · desired] The canonical URL must **return 200**. A canonical pointing to a 301, 404, or 5xx response is treated as broken; crawlers fall back to their own selection.
  - ✅ do: verify canonical URLs are live and return 200 before publishing.
  - ❌ don't: set the canonical to a redirect target you have not yet set up.
- [invariant · desired] **Reinforce the canonical** with three additional signals so all agree:
  1. Internal links point to the canonical URL (not to duplicate variants).
  2. The XML sitemap lists only canonical URLs.
  3. A 301 redirect from every non-canonical variant to the canonical URL.
  - ❌ don't: declare a canonical but then include the non-canonical variant in the sitemap — this contradicts the signal and reduces crawl budget efficiency.

### Duplicate consolidation

- [invariant · desired] Duplicate pages (same content reachable via multiple URLs — e.g. with/without `www`, with/without trailing slash, HTTP vs HTTPS, with/without UTM parameters) must be **consolidated onto one canonical URL**. The canonical should be chosen once and never changed without a redirect.
- [anti-pattern · desired] Using **multiple consolidation methods simultaneously** (canonical tag + noindex + disallow in robots.txt) on the same duplicate creates contradictory signals. Choose the appropriate single method:
  - `rel="canonical"` — preferred URL is indexable, others are duplicates.
  - `noindex` — page should not be indexed at all (canonical is irrelevant here).
  - `robots.txt Disallow` — page must not be crawled (use only for truly private content, not for duplicate management).
- [preference · desired] **UTM parameters and session IDs** should be excluded from the canonical URL so tracking variants are never indexed.

### Redirects

- [invariant · desired] Use **301 (Moved Permanently)** or **308 (Permanent Redirect)** for permanent URL changes — these signal that ranking signals (link equity) should migrate to the new URL. 308 differs from 301 only in that it preserves the HTTP method; prefer 301 for GET-based page URLs.
  - ✅ do: 301 when a page permanently moves to a new slug.
  - ❌ don't: use 302 for a permanent move — crawlers treat 302 as temporary and do not transfer signals.
- [invariant · desired] Use **302 (Found)** or **307 (Temporary Redirect)** only for genuinely temporary redirects (A/B testing, seasonal campaigns, maintenance pages). Remove temporary redirects as soon as the condition ends.
- [invariant · desired] Keep **redirect chains short** — ideally a single hop (A → B). Chains longer than two hops cost crawl budget and dilute signal transfer. Every time a URL in the chain changes, collapse the chain so older entrypoints redirect directly to the final destination.
  - ✅ do: when adding a new redirect for C → D, check whether A → B → C already exists and update A → D.
  - ❌ don't: accumulate A → B → C → D chains over time without auditing.
- [invariant · desired] **Trailing-slash consistency**: choose one canonical form (trailing slash or no trailing slash) and enforce it site-wide with a 301. Mix causes duplicate indexing.
  - ✅ do: `https://example.com/blog/` always redirects `https://example.com/blog` (or vice versa) with 301.
  - ❌ don't: serve both forms with 200 and no canonical — both will be indexed as duplicates.

### Site migration, domain change, HTTPS upgrade

- [invariant · desired] **Full site migration playbook** (old domain → new domain, HTTP → HTTPS, or www ↔ non-www):
  1. Set up the new destination first; verify it returns 200 for all pages.
  2. Implement 301 redirects from every old URL to its exact new counterpart (not just to the homepage).
  3. Cover **both www and non-www variants** of the old domain so no variant is left without a redirect.
  4. Update all internal links, the XML sitemap, and structured-data URLs to the new canonical.
  5. Submit a **change-of-address** signal in Google Search Console (domain migration feature) to expedite re-indexing.
  6. Keep the old domain's redirects live for **at least 12 months** after migration; signal transfer is gradual.
  - ✅ do: redirect `http://example.com/page` → `https://example.com/page` and `http://www.example.com/page` → `https://example.com/page` with separate rules so all four HTTP/HTTPS × www/non-www variants resolve correctly.
  - ❌ don't: redirect only the homepage and leave interior pages returning 404 on the old domain.
- [invariant · desired] **HTTPS migration specifically**: after all pages redirect correctly, add an `HSTS` (`Strict-Transport-Security`) header to prevent future HTTP requests from being made at all. Preload HSTS only after the site is stable on HTTPS.

### HTTP status semantics

- [invariant · desired] **200 OK** — page exists and is indexable. Return 200 only for pages with real content; never return 200 for a not-found or error state (see soft-404 below).
- [invariant · desired] **404 Not Found** — the resource does not exist (and has never existed or is permanently gone). Crawlers eventually drop 404 URLs from the index, but it may take months.
- [invariant · desired] **410 Gone** — the resource existed and has been permanently removed. Prefer 410 over 404 for intentionally deleted content; crawlers remove 410 URLs from the index faster than 404s.
  - ✅ do: return 410 when a product is discontinued and will never return.
- [invariant · desired] **301/308** — permanent redirect (see Redirects section).
- [invariant · desired] **302/307** — temporary redirect (see Redirects section).
- [invariant · desired] **429 Too Many Requests** — use this (not 401 or 403) to **rate-limit crawlers**. Include a `Retry-After` header so the crawler backs off correctly. 401/403 instruct crawlers the content is permanently inaccessible, which leads to de-indexing; 429 signals a transient condition.
  - ✅ do: return 429 with `Retry-After: 60` when a bot crawls too aggressively.
  - ❌ don't: return 403 to throttle crawlers — it signals the resource is permanently forbidden and triggers de-indexing.
- [invariant · desired] **503 Service Unavailable** — return during planned maintenance windows, with a `Retry-After` header. Crawlers treat 503 as a transient signal and preserve index status. Do not leave 503 running for more than a few hours or crawlers will begin to treat it as permanent.
- [invariant · desired] **5xx errors** (500, 502, 503, 504) — never allow sustained 5xx responses on important pages. Crawlers lower crawl frequency for sites with persistent 5xx responses and may eventually de-index affected URLs.
- [anti-pattern · desired] **Soft-404**: returning **200 for a not-found page** is a soft-404. A page that says "We couldn't find that" but returns HTTP 200 will be indexed by crawlers as a real page. It wastes crawl budget and may generate thin-content ranking penalties.
  - ✅ do: ensure every "page not found" template returns HTTP 404 (or 410 for deleted content).
  - ❌ don't: return 200 from a generic "not found" template — even if the visible content says "404".

### AI-hallucinated URL handling

- [preference · desired] Language models sometimes cite **URLs that do not exist** but are plausible variants of real pages (wrong slug, missing word, outdated path). When a 404 pattern clearly maps to an existing real URL, return a **301 to the real page** rather than a bare 404.
  - ✅ do: implement fuzzy-match redirect logic (slug similarity, common AI-cited patterns) so inbound traffic from AI-cited URLs lands on the intended content.
  - ❌ don't: ignore 404 traffic from AI referrers — analyse the referrer logs to identify AI-hallucinated URL patterns, then create targeted 301 redirects.
- [preference · desired] Use server-side 301 redirects for AI-hallucinated URLs, not client-side JavaScript redirects. Client-side redirects are slower and do not transfer ranking signals.

## Anti-patterns

- [anti-pattern · desired] **Canonical to a redirect** — the canonical href points to a URL that itself 301s elsewhere. Crawlers follow the chain but the signal is weakened. Always canonical to the final 200 URL.
- [anti-pattern · desired] **Self-referencing canonical on a page you want to consolidate** — a page that should yield to a master URL must not also carry a self-referencing canonical; the self-canonical overrides the consolidation intent.
- [anti-pattern · desired] **Redirect chain accumulation** — adding new redirects without auditing existing chains causes A → B → C → D stacks that silently dilute link equity and slow down crawling.
- [anti-pattern · desired] **Using 302 for permanent moves** — the most common redirect mistake. 302 does not transfer signals and the old URL stays indexed.
- [anti-pattern · desired] **Inconsistent www vs non-www** — serving both with 200 and no redirect creates duplicate home pages, each accumulating separate link equity.
- [anti-pattern · desired] **Soft-404** (200 on not-found pages) — wastes crawl budget and risks thin-content indexation.
- [anti-pattern · desired] **Returning 403 to throttle crawlers** — de-indexes the affected URLs; use 429 with `Retry-After` instead.

## Related skills (by name)

- **meta-tags** — `<link rel="canonical">` in `<head>`, robots meta, and head validity.
- **url-structure** — URL slug conventions, query-parameter management, and URL design.
- **sitemaps** — XML sitemap contents, canonical URL inclusion, and change-frequency signals.
- **javascript-seo** — crawlability of client-rendered pages, dynamic canonical injection, and redirect handling in SPAs.
