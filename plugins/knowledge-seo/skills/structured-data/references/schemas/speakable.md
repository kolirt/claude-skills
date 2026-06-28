# Speakable — content sections designed for text-to-speech delivery
**When:** Page is a news article from a registered news publisher, and specific sections are suitable for audio playback on voice assistants (e.g. Google Home).

> **Status: BETA.** As of the current Google documentation, `Speakable` remains in beta, limited to news publishers in the US publishing in English. Do not implement for general content sites until Google announces broader availability.

## Fields
Required (Google): one of `cssSelector` OR `xPath` (not both) on `SpeakableSpecification`.

Recommended: none beyond the required locator.

`speakable` is a property on `Article` or `WebPage` (not a standalone type).

## Input contract (neutral, not an entity)
```ts
interface SpeakableSchemaInput {
  pageType: 'Article' | 'WebPage';
  pageUrl: string;
  locatorType: 'cssSelector' | 'xPath';
  selectors: string[];   // CSS selectors or XPath expressions
}
```

## JSON-LD skeleton
```json
{
  "@context": "https://schema.org/",
  "@type": "WebPage",
  "name": "Article Title",
  "url": "https://example.com/article",
  "speakable": {
    "@type": "SpeakableSpecification",
    "cssSelector": [
      ".article-headline",
      ".article-summary"
    ]
  }
}
```

### XPath variant
```json
{
  "@context": "https://schema.org/",
  "@type": "WebPage",
  "name": "Article Title",
  "url": "https://example.com/article",
  "speakable": {
    "@type": "SpeakableSpecification",
    "xPath": [
      "/html/head/title",
      "/html/head/meta[@name='description']/@content"
    ]
  }
}
```

## Pitfalls
- Use either `cssSelector` OR `xPath` — never both in the same `SpeakableSpecification` object.
- `speakable` is a property, not a top-level type; it must be nested inside an `Article` or `WebPage` block.
- Currently limited to US English news publishers only — implementing on non-news or non-English pages has no effect.
- Speakable sections should be concise and make sense out of context when read aloud; avoid marking up sections that reference visual elements (tables, images, charts).
- The selected content is read verbatim by voice assistants — avoid markup-heavy or list-heavy sections that sound odd when spoken.
- Beta status means the feature can be changed or removed without notice; monitor Google Search Central announcements before investing heavily.
