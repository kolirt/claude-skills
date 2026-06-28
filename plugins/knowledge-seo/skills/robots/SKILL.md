---
name: robots
description: Use when configuring robots.txt — crawl access, sitemap link, AI-crawler allow/deny, closing dev/staging from crawl. (Page-level noindex is the meta-tags skill.)
---

# robots.txt — crawl access, sitemaps, AI-bots, crawl budget

`robots.txt` governs **crawl access only**. It does not control indexing.
A URL disallowed in `robots.txt` can still appear in search results if
another page links to it. Page-level indexing signals (`noindex`, `canonicals`)
belong to the `meta-tags` skill.

## Rules

### Core behaviour

- [invariant · desired] `robots.txt` controls whether a crawler **fetches** a URL, not
  whether the URL is **indexed**. A disallowed-but-linked URL can still appear in search
  results.
  - ✅ do: use `robots.txt` to block crawl of URLs you never want fetched (internal search
    results, checkout flows, staging areas).
  - ❌ don't: rely on `robots.txt` alone to keep a URL out of the index — a `noindex`
    directive on the crawlable page is required (see `meta-tags` skill).

- [invariant · desired] Always include at least one `Sitemap:` directive pointing to the
  XML sitemap. This helps crawlers discover canonical URLs without crawling the whole site.
  ```
  Sitemap: https://example.com/sitemap.xml
  ```

- [invariant · desired] Non-HTML resources (PDFs, images, feeds) cannot carry a
  `<meta robots>` tag. Use the `X-Robots-Tag` HTTP response header instead to send
  `noindex` or other directives.
  - ✅ do: configure the web server or CDN to emit `X-Robots-Tag: noindex` on PDFs and
    other non-HTML assets that should not be indexed.

### Dev and staging environments

- [invariant · desired] Every non-production environment (dev, staging, preview) is
  **closed to crawlers** with a blanket `Disallow: /` rule for all user-agents.
  ```
  # staging robots.txt
  User-agent: *
  Disallow: /
  ```

- [invariant · desired] `Disallow: /` blocks **crawling only**. If a staging URL is
  publicly reachable (no auth), it can still be indexed via links or direct URL discovery.
  A staging environment that must stay out of search results needs **both** a crawl block
  **and** one of the following: HTTP authentication, a crawlable `noindex` response header,
  or restricted network access.
  - ❌ don't: treat a staging `Disallow: /` as a sufficient privacy control — it is not.

### Crawl budget

- [preference · desired] Block faceted navigation, pagination variants, and
  parameter-generated duplicates to conserve crawl budget for canonical content.
  ```
  Disallow: /*?sort=
  Disallow: /*?color=
  Disallow: /search?
  ```

- [preference · desired] Keep redirect chains short (one hop) and server response times
  fast. Slow or multi-hop responses waste crawl budget even when URLs are allowed.

- [preference · desired] Use accurate `lastmod` values in the XML sitemap. Stale or
  universal `lastmod` dates cause crawlers to re-crawl unchanged content unnecessarily.

### AI-crawler decisions

- [invariant · desired] Make an **explicit per-bot allow/deny decision** rather than a
  blanket policy. Whether to allow an AI crawler is a **business and legal choice**
  (licensing, scraping terms of service, brand risk), not a technical default.

  Common AI crawlers and their identifiers:

  | Bot | User-agent token |
  |-----|-----------------|
  | OpenAI training | `GPTBot` |
  | OpenAI search | `OAI-SearchBot` |
  | ChatGPT browsing | `ChatGPT-User` |
  | Anthropic | `ClaudeBot` |
  | Perplexity | `PerplexityBot` |
  | Google AI training | `Google-Extended` |

  - ✅ do: list each bot explicitly with a deliberate `Allow` or `Disallow` after reviewing
    each provider's terms and your own content licensing.
  - ❌ don't: add `User-agent: * / Disallow: /` to block all bots and assume AI crawlers
    are covered — legitimate crawlers follow the spec; the main audience for a blanket block
    is Googlebot, which you almost certainly do not want to block.

- [invariant · desired] CDN and edge platforms (Cloudflare, Fastly, Akamai, Vercel Edge)
  may apply their own AI-bot blocking rules that operate **before** a request reaches your
  origin and therefore **override** your `robots.txt`. Verify platform-level WAF or bot
  management rules when auditing AI-crawler access.

### Security and privacy

- [anti-pattern · desired] Do not treat `robots.txt` as a security or privacy control.
  The file is public and unauthenticated; disallowing a path does not prevent a human or
  a non-compliant bot from accessing it. Sensitive endpoints must be protected by
  authentication or authorization, not by `robots.txt` entries.

### URL removals

- [preference · desired] Choose the removal mechanism that matches the goal:

  | Goal | Recommended mechanism |
  |------|-----------------------|
  | Temporarily remove a URL from search results | Google Search Console Removals tool |
  | Permanently remove a page | Return `410 Gone` (or `404`) and add `noindex` while indexed |
  | Remove a page you control and keep it live | `noindex` in `<meta robots>` or `X-Robots-Tag` |
  | Block access entirely | Authentication (not `robots.txt`) |

  - ❌ don't: use the Removals tool as a permanent solution — it expires and requires
    renewal; a `noindex` directive on a crawlable URL is the durable signal.

## Related skills (by name)

- `meta-tags` — page-level `noindex`, `nofollow`, and other `<meta robots>` directives
- `generative-seo` — programmatic and AI-assisted content strategy
- `sitemaps` — XML sitemap structure, `lastmod`, `changefreq`, submission
- `canonicalization-and-redirects` — canonical tags, redirect chains, duplicate URL handling
