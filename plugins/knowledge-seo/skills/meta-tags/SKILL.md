---
name: meta-tags
description: Use when setting or reviewing a page's head meta — title, description, canonical link, robots meta, favicon, head validity, outbound link qualifiers, site name, and AI-snippet directives. (OG/Twitter is the social-preview skill; hreflang is the international skill.)
---

# meta-tags — head META and link elements

Stack-independent rules for every element that belongs in `<head>` to communicate page identity, indexing intent, and link semantics to crawlers and browsers.

## Rules

### Title

- [invariant · desired] Each page has a **unique** `<title>`. Duplicated titles across pages are a crawl signal that pages carry duplicate content.
- [preference · desired] Aim for **50–60 visible characters** — this is a display guidance range, not a hard limit. Longer titles are truncated in SERPs; shorter titles waste signal space.
  - ✅ do: `Product name | Site name` (template suffix, populated at build/render time)
  - ❌ don't: hand-write the site name into every page's title literal — use a layout-level template suffix instead.
- [invariant · desired] The **site name** in the title comes from a **template or layout suffix**, never from a per-page hard-coded string. This ensures renaming the site only requires one change.

### Description

- [invariant · desired] `<meta name="description">` is **unique per page** and is not a copy of the title.
- [preference · desired] Keep description content under **~160 characters** — content beyond that is truncated in most SERP snippets.
  - ✅ do: summarise the page's specific value proposition.
  - ❌ don't: copy the page `<title>` text into the description.

### Canonical link

- [invariant · desired] Every indexable page carries **exactly one** `<link rel="canonical" href="...">`.
  - ✅ do: self-referencing, absolute URL, same scheme and host as the page.
  - ❌ don't: include more than one canonical on the same page — crawlers treat this as a conflicting signal and may ignore both.
- [invariant · desired] The canonical URL must be **absolute** (includes scheme + host).
- [invariant · desired] **UTM parameters and tracking query strings are stripped** from the canonical URL. Only allowlisted query parameters (those that change meaningful content) may appear.
  - ❌ don't: `?utm_source=newsletter&utm_medium=email` in the canonical href.
- [anti-pattern · desired] Setting `noindex` **and** a canonical on the same page is contradictory — `noindex` removes the page from the index so the canonical preference is never processed. Choose one intent.
- Note: the HTTP `Link:` response-header form of canonical is covered by the **canonicalization-and-redirects** skill, not here.

### Robots meta

- [invariant · desired] The default indexing stance is `<meta name="robots" content="index,follow">`. Omitting the tag is equivalent; include it explicitly only when you need to communicate a non-default value.
- [invariant · desired] Use `noindex` deliberately — only for pages that are thin, private, paginated duplicates, or internal tooling. Do not apply `noindex` site-wide by mistake.
  - ✅ do: `<meta name="robots" content="noindex,follow">` on account settings, search-results pages with no unique content, staging environments.

### AI-preview and snippet directives

- [preference · desired] Control how AI overviews and rich snippets sample the page via these directives on `<meta name="robots">` or as attributes:
  - `nosnippet` — prevent any text or video snippet from being shown.
  - `max-snippet:N` — limit snippet to N characters.
  - `max-image-preview:[none|standard|large]` — control image preview size.
  - `max-video-preview:N` — limit video preview duration in seconds.
  - `noimageindex` — do not index images on the page.
  - `noarchive` — do not show a cached link in SERPs.
  - `notranslate` — do not offer translation of the page in SERPs.
  - `data-nosnippet` (HTML attribute) — exclude a specific inline element from snippet extraction without affecting the whole page.
- [preference · desired] Multiple directives can be combined in one `content` value with commas: `content="max-snippet:150,max-image-preview:large"`.

### Favicon

- [invariant · desired] Declare the favicon via `<link rel="icon" href="...">` in `<head>`.
- [preference · desired] Use a **square** (1:1) image, minimum **48 × 48 px** recommended for high-density displays.
- [invariant · desired] The favicon file must be **crawlable** (not blocked by `robots.txt` or authentication).

### Valid `<head>` children

- [invariant · desired] Only elements valid inside `<head>` go in `<head>`: `<title>`, `<meta>`, `<link>`, `<style>`, `<script>`, `<base>`, `<noscript>`, `<template>`. Block-level or interactive elements (`<div>`, `<p>`, `<a>`, `<img>`, etc.) must not appear in `<head>` — browsers move them to `<body>` silently, which can break your SEO and layout assumptions.

### Outbound link qualifiers

- [invariant · desired] Annotate outbound links with the appropriate `rel` qualifier when the relationship is not editorially earned:
  - `rel="nofollow"` — general signal that the link should not pass ranking credit (e.g. untrusted user content).
  - `rel="ugc"` — link is user-generated content (comments, forum posts).
  - `rel="sponsored"` — link is part of an advertisement or paid placement.
- [preference · desired] Multiple values combine: `rel="nofollow ugc"`.

### Site name

- [preference · desired] Declare the site's canonical name via `alternateName` in structured data (JSON-LD `WebSite` or `Organization`) on the **home page**. This signals the site's name to crawlers independently of the `<title>` template suffix.
- [preference · desired] Place the `WebSite` / `Organization` structured-data block on the **home page only**, not on every page.

## Anti-patterns

- [anti-pattern · desired] `<title>` text equals `<meta name="description">` content — crawlers treat this as low-effort metadata and may generate their own snippets instead.
- [anti-pattern · desired] UTM or tracking parameters in the canonical URL — causes the tracking variant to be indexed instead of the clean URL.
- [anti-pattern · desired] Multiple `<link rel="canonical">` elements on one page — conflicting signals lead crawlers to ignore both.
- [anti-pattern · desired] `noindex` combined with a self-referencing canonical on the same page — mutually contradictory directives; pick one intent.

## Related skills (by name)

- **social-preview** — Open Graph and Twitter/X card meta tags.
- **canonicalization-and-redirects** — HTTP `Link:` canonical header, redirect chains, and URL consolidation strategy.
- **international** — `hreflang` annotations for multi-language and multi-region pages.
- **structured-data** — JSON-LD, Schema.org types, and rich-result eligibility.
