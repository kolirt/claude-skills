# WebSite — site-level identity for name display in search results
**When:** Home page of any website where you want Google to surface the correct site name in search results. Place exactly once, on the home page (`url` = canonical home URL). Never repeat on inner pages.

> **No SearchAction / Sitelinks Searchbox.** Google removed the Sitelinks Searchbox rich result feature. The `SearchAction` property on `WebSite` no longer produces any search-result enhancement and MUST NOT be included. Adding `SearchAction` to `WebSite` markup is a known pitfall — omit it entirely.

## Fields
Required (Google): none formally required.

Recommended:
- `name` — the site name exactly as you want it displayed in Google Search; keep it short and match the `<title>` of the home page.
- `url` — the canonical URL of the home page (must match `canonical` link tag).
- `alternateName` — a shorter or alternative name (abbreviation, brand alias); used by Google when space is limited.

Properties that were once commonly added but are now obsolete or unsupported:
- `SearchAction` / `potentialAction` — **do not use** (Sitelinks Searchbox removed).
- `publisher` — redundant here; declare via `Organization` instead.

## Input contract (neutral, not an entity)
```ts
interface WebSiteSchemaInput {
  name: string;           // site display name, e.g. "Example"
  url: string;            // canonical home-page URL
  alternateName?: string; // short alias, e.g. "EX"
}
```

## JSON-LD skeleton
```json
{
  "@context": "https://schema.org",
  "@type": "WebSite",
  "name": "Example",
  "alternateName": "EX",
  "url": "https://www.example.com"
}
```

> Pair this block with an `Organization` block in the same `<script>` or a second adjacent block so Google can associate the site name with the organisation's knowledge panel.

## Pitfalls
- **Do not add `SearchAction` or `potentialAction`.** The Sitelinks Searchbox feature was removed by Google; this property is now dead markup that can confuse validators.
- Emit `WebSite` on the home page only — one block per site. Repeating it on every page is unnecessary and creates conflicting signals.
- `name` must match what appears in the page's visible `<title>` or `<h1>`; mismatches may cause Google to ignore the declared name.
- `url` must be the exact canonical URL (including or excluding `www`, matching the preferred version in Search Console).
- Do not add `description`, `author`, or `publisher` here — those belong on individual page types (`Article`, `WebPage`) or on the companion `Organization` block.
