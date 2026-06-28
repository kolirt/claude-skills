---
name: social-preview
description: Use when adding social link-preview tags — Open Graph, Twitter/X Cards, and per-platform (Facebook/LinkedIn/Pinterest/Telegram/Discord/Slack) preview behaviour.
---

# social-preview — Open Graph, Twitter/X Cards, and per-platform link previews

Stack-independent rules for the `<head>` meta tags that control how a page's link
preview renders when shared on social platforms. This skill covers **social sharing
only** — these tags have no direct effect on Google Search ranking or indexation
(they are not a Google SEO criterion).

## Minimal cross-platform set

The following snippet satisfies the preview renderer on virtually every major
platform. Add it to every shareable page; extend it per-platform as needed.

```html
<!-- Open Graph core (required) -->
<meta property="og:title"       content="Page title here" />
<meta property="og:type"        content="website" />
<meta property="og:url"         content="https://example.com/page" />
<meta property="og:image"       content="https://example.com/images/share.jpg" />

<!-- Open Graph recommended -->
<meta property="og:description" content="A short summary of the page." />
<meta property="og:site_name"   content="Site Name" />
<meta property="og:locale"      content="en_US" />

<!-- Open Graph image sub-properties (follow immediately after their og:image) -->
<meta property="og:image:secure_url" content="https://example.com/images/share.jpg" />
<meta property="og:image:type"       content="image/jpeg" />
<meta property="og:image:width"      content="1200" />
<meta property="og:image:height"     content="630" />
<meta property="og:image:alt"        content="Descriptive alt text for the image" />

<!-- Twitter/X Card (no OG fallback — required independently) -->
<meta name="twitter:card" content="summary_large_image" />
```

## Rules

### Open Graph — core properties

- [invariant · desired] Every shareable page declares all four **required** OG
  properties: `og:title`, `og:type`, `og:image`, `og:url`. Without any one of
  them, some platforms refuse to generate a preview entirely.
  - ✅ do: include all four on every page that can be shared.
  - ❌ don't: omit `og:image` and rely on a platform's fallback heuristic — the
    result is unpredictable (a random in-page image, no image, or a broken card).

- [invariant · desired] `og:url` must equal the page's **canonical URL** — same
  scheme, host, path, and allowlisted query parameters as `<link rel="canonical">`.
  - ✅ do: set `og:url` to the same absolute URL as the canonical link element.
  - ❌ don't: set `og:url` to the tracking URL or a URL that differs from the
    canonical — platforms deduplicate shares by `og:url`, so mismatches split
    share counts across variants.

- [preference · desired] Set `og:type` to `article` for blog posts and news
  content, `product` for e-commerce items, and `website` as the default for
  everything else. The value influences how some platforms display publish dates
  or product data.

### Open Graph — recommended properties

- [preference · desired] Include `og:description` (keep it under ~200 characters)
  and `og:site_name` on every page.
  - ✅ do: use a unique description per page — the same text as `<meta name="description">` is fine.
  - ❌ don't: copy `og:title` verbatim into `og:description`.

- [preference · desired] Set `og:locale` using the format `language_TERRITORY`
  (e.g. `en_US`, `fr_FR`). If the page is available in other locales, add
  additional `<meta property="og:locale:alternate" content="..." />` tags.

### Open Graph — image rules

- [invariant · desired] The `og:image` URL must be **absolute and use HTTPS**.
  HTTP image URLs are rejected or silently dropped by several platforms.
  - ✅ do: `content="https://example.com/images/share.jpg"`
  - ❌ don't: use a relative path (`/images/share.jpg`) or `http://`.

- [invariant · desired] `og:image:alt` must be present alongside every `og:image`.
  Missing alt text causes accessibility failures and may suppress the image on
  some platforms.

- [invariant · desired] Image sub-properties (`og:image:secure_url`,
  `og:image:type`, `og:image:width`, `og:image:height`, `og:image:alt`) must
  appear **immediately after** the `og:image` they describe. Parsers associate
  sub-properties with the preceding root property.

- [preference · desired] Optimal OG image size is **1200 × 630 px** (aspect ratio
  1.91:1, JPEG or PNG). This fits the Facebook and LinkedIn recommended specs
  without cropping on any major platform.

- [anti-pattern · desired] Declaring multiple `og:image` tags — the **first one
  wins** across all platforms. Additional images are ignored by Facebook,
  LinkedIn, and Slack. If you do use multiple images, order the preferred image
  first, and ensure each image is followed by its own full set of sub-properties
  before the next `og:image` tag.

### Twitter/X Cards

- [invariant · desired] `twitter:card` has **no OG fallback**. Without it, no
  card renders on X/Twitter at all — the post shows as a plain URL.
  - ✅ do: always include `<meta name="twitter:card" content="...">` independently.
  - ❌ don't: rely on `og:*` tags alone and expect a Twitter card to appear.

- [preference · desired] Choose the card type deliberately:
  - `summary` — small square image (up to 120 × 120 px, 1:1 recommended), used
    for articles and generic pages.
  - `summary_large_image` — large rectangular image (~2:1 ratio, minimum 300 × 157 px,
    recommended 1200 × 628 px). Use for visual content, blog posts, and
    marketing pages.

- [preference · desired] `twitter:title`, `twitter:description`, and
  `twitter:image` fall back to their `og:*` counterparts when not explicitly
  set, so you only need to add them if the Twitter-specific copy should differ.

- [invariant · desired] `twitter:image` must also be an absolute HTTPS URL; the
  same image used for `og:image` at 1200 × 628 px satisfies both.

### Caches and re-scraping

- [invariant · desired] Social platforms **cache previews aggressively**. After
  changing any OG or card tag, use the platform's debug/re-scrape tool to force
  an update. Updated meta tags do not propagate automatically.
  - ✅ do: after publishing a change, re-scrape via the platform debugger before
    announcing or sharing the URL.
  - ❌ don't: assume the cache clears on its own within hours — some platforms
    hold caches for days.

### Per-platform notes

- [preference · desired] **Facebook** — recommended image: 1200 × 630 px (1.91:1).
  Add `<meta property="fb:app_id" content="YOUR_APP_ID" />` for Facebook
  Insights integration. Force re-scrape via the [Facebook Sharing Debugger](https://developers.facebook.com/tools/debug/).

- [preference · desired] **LinkedIn** — minimum image: 1200 × 627 px. Inspect
  how the post will render via the [LinkedIn Post Inspector](https://www.linkedin.com/post-inspector/).

- [preference · desired] **Pinterest Rich Pins** — Pinterest extends OG with
  three rich-pin types: `Article`, `Product`, and `Recipe`. Rich Pins require a
  **one-time domain approval** submitted via the Pinterest developer portal.
  Once approved, OG and Schema.org markup is read automatically.

- [preference · desired] **Telegram and Discord** — both read standard OG tags.
  Discord additionally reads `<meta name="theme-color" content="#HEX" />` to
  colour the embed accent strip.

- [preference · desired] **Slack** — unfurls links using OG tags. Slack caches
  aggressively; clear the unfurl for a specific URL via Slack's link-unfurl
  settings or by re-posting after content settles.

## Anti-patterns

- [anti-pattern · desired] Relative or HTTP image URLs in `og:image` — HTTPS
  absolute URLs are the only format accepted consistently across all platforms.
- [anti-pattern · desired] Omitting `og:image:alt` — causes accessibility issues
  and may suppress the image card on accessible-first clients.
- [anti-pattern · desired] `og:url` set to a tracking URL or UTM-parameterised
  variant — splits share counts and can cause a mismatch with the canonical URL.
- [anti-pattern · desired] Skipping `twitter:card` and relying on OG — results in
  no card rendering on X/Twitter, not a degraded card.
- [anti-pattern · desired] Updating OG tags without triggering a platform
  re-scrape — the old cached preview continues to appear until the cache expires.

## Related skills (by name)

- **meta-tags** — page `<title>`, `<meta name="description">`, canonical link, and
  robots directives in `<head>`.
- **structured-data** — JSON-LD, Schema.org types, and rich-result eligibility.
- **canonicalization-and-redirects** — canonical URL strategy, redirect chains,
  and URL consolidation.
