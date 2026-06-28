---
name: structured-data
description: Use when adding schema.org structured data (JSON-LD) — choosing a type, required fields, validity. Type catalog: references/schema-types.md; content→type map: references/recognition.md.
---

# structured-data — schema.org JSON-LD markup

Stack-independent rules for embedding machine-readable structured data in any page.
Structured data communicates page semantics to Google, Bing, Yandex, Pinterest, and
AI extraction pipelines — not only to Google.

Read `references/schema-types.md` for the working-type catalog and page→type cheat-sheet.
Read `references/recognition.md` for the content→schema recognition map (single source of truth).

## Rules

### Format and embedding

- [invariant · desired] **JSON-LD is the preferred format** for structured data. Do not use
  Microdata or RDFa for new markup — they couple schema to the HTML structure and are
  harder to maintain.
- [invariant · desired] Every JSON-LD block declares `"@context": "https://schema.org"`.
- [invariant · desired] The `<script type="application/ld+json">` tag is placed inside
  `<head>` or at the top of `<body>` — before the closing `</body>` tag at minimum.
- [invariant · desired] When serialising the JSON-LD block into HTML, **replace `<` with
  `<`** to prevent `</script>` injection / XSS. In JavaScript source this reads:
  `.replace(/</g, '\\u003c')` — two backslashes in JS source produce the literal
  six-character escape sequence in the output string.
- [invariant · desired] When a page carries multiple schema objects, group them in a single
  block as an **array** or under `@graph` — do not scatter multiple bare `<script>` tags
  with one object each.

### Content fidelity

- [invariant · desired] Structured data must **mirror visible content**. Do not mark up
  information that is not displayed to users — Google will penalise deceptive markup.
- [invariant · desired] Dates use **ISO 8601** format (`YYYY-MM-DD` or full datetime
  `YYYY-MM-DDTHH:MM:SSZ`).
- [invariant · desired] All URL values are **absolute** (include scheme + host).

### Type selection

- [invariant · desired] **Choose a type only from the catalog** in `references/schema-types.md`.
  Absence from the catalog means: do not use. This rule implicitly excludes deprecated,
  removed, and unverified types without requiring an explicit blocklist.
- [invariant · desired] It is "**Google-supported rich-result types**", not "the full
  schema.org catalog". schema.org defines 700+ types; only the Google-supported subset
  reliably triggers rich results. Types outside that subset (Dataset Search, niche vertical
  types) are optional for AI/general extraction — they do not guarantee rich results.
- [invariant · desired] **No SearchAction / sitelinks searchbox**. Google removed sitelinks
  searchbox rich results; omit `SearchAction` markup entirely.

### Schema factory design

- [invariant · desired] A **schema factory function takes an explicit neutral input type**,
  never a domain entity object. The caller maps domain entity → input DTO before passing it
  in. This keeps the factory domain-agnostic and reusable across codebases.
  - ✅ do: `buildProductSchema({ name, price, currency, availability })`
  - ❌ don't: `buildProductSchema(productEntity)` where `productEntity` is a domain model

### Entity authority

- [invariant · desired] **Organization / Person identity** is declared once per site using
  `Organization` or `Person` with a `sameAs` array pointing to authoritative profiles
  (e.g., LinkedIn, Wikipedia, Wikidata, social accounts). This markup lives in THIS skill's
  scope — not in social-preview or meta-tags.
- [preference · desired] Reference the organisation from other schema objects (e.g.,
  Article's `publisher`) using an `@id` pointer rather than repeating the full object.

### Multi-consumer awareness

- [preference · desired] The same JSON-LD markup is consumed by Bing, Yandex, Pinterest,
  and AI extraction pipelines — not only by Google. Write valid, complete markup rather
  than targeting Google's subset exclusively.

### Depth notes (covered in deep skill files — Tasks 15–18)

- **E-commerce depth**: product variants / `ProductGroup`, availability states
  (in-stock, out-of-stock, pre-order), returns policy markup, shipping policy markup.
- **LocalBusiness depth**: NAP parity (HTML ↔ schema), `tel:` links in schema,
  crawlable store locator, precise `@type` subtype, multi-location `@id` / `branchOf`.

## Tags

Use `[type · provenance]` tags on every rule (middot U+00B7 `·`; every tag includes
provenance).

## Related skills (by name)

- meta-tags
- social-preview
- media-seo
- javascript-seo
