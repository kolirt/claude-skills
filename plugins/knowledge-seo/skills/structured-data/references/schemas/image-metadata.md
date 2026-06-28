# ImageObject — image licensing and attribution metadata
**When:** Page features standalone images or you want to surface licensing, creator credit, and copyright information in Google Images.

## Fields
Required (Google): none formally required, but at least one of `license` or `acquireLicensePage` must be present for the licensing badge to appear in Google Images.

Recommended:
- `contentUrl` — direct URL to the image file.
- `license` — URL of the applicable licence (e.g. Creative Commons page).
- `acquireLicensePage` — URL where a user can purchase or request a licence.
- `creditText` — credit line displayed with the image.
- `creator` — `Person` or `Organization` with `.name`.
- `copyrightNotice` — short copyright statement.

## Input contract (neutral, not an entity)
```ts
interface ImageObjectSchemaInput {
  contentUrl: string;           // direct image URL
  license?: string;             // URL of the licence
  acquireLicensePage?: string;  // URL to get a licence
  creditText?: string;          // e.g. "Photo Lab"
  creatorName?: string;         // photographer / creator name
  copyrightNotice?: string;     // e.g. "© 2025 Jane Doe"
}
```

## JSON-LD skeleton
```json
{
  "@context": "https://schema.org/",
  "@type": "ImageObject",
  "contentUrl": "https://example.com/photos/photo.jpg",
  "license": "https://example.com/license",
  "acquireLicensePage": "https://example.com/how-to-use-my-images",
  "creditText": "Example Photo Lab",
  "creator": {
    "@type": "Person",
    "name": "Jane Doe"
  },
  "copyrightNotice": "© 2025 Jane Doe"
}
```

## Pitfalls
- `ImageObject` on its own does not produce a traditional rich result in Google Search — it surfaces the licensing badge and creator attribution inside Google Images.
- The markup should be on the page that hosts the image, not on a CDN or external domain.
- `license` must be a resolvable URL, not a short identifier like "CC BY 4.0".
- IPTC photo metadata embedded in the image file is an alternative to JSON-LD; both methods are recognised. JSON-LD is preferred for CMS-generated pages.
- Avoid using the same `ImageObject` block for multiple images; each image should have its own block with its own `contentUrl`.
- `copyrightNotice` and `creditText` are separate fields — `creditText` is the attribution shown to users; `copyrightNotice` is the legal copyright string.
