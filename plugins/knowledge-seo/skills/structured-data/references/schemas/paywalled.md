# Paywalled — subscription and paywalled content markup
**When:** Page contains content that is partially or fully locked behind a paywall or registration requirement, and you want Google to index the content without applying a cloaking penalty.

> **Note:** This is not a separate `@type`. Paywalled markup is added as properties (`isAccessibleForFree`, `hasPart`) to an existing `CreativeWork` type — typically `NewsArticle`.

## Fields
Required (Google) additions to the existing CreativeWork block:
- `isAccessibleForFree` — `false` on the article (or `true` if the content is free despite requiring login).
- `hasPart.@type` — `WebPageElement`.
- `hasPart.isAccessibleForFree` — `false`.
- `hasPart.cssSelector` — CSS selector matching the paywalled DOM element(s).

Recommended:
- All standard `NewsArticle` / `Article` fields (headline, image, datePublished, author).

## Input contract (neutral, not an entity)
```ts
interface PaywalledSchemaInput {
  articleType: 'NewsArticle' | 'Article' | 'BlogPosting';
  headline: string;
  image: string;
  datePublished: string;          // ISO 8601
  dateModified?: string;          // ISO 8601
  authorName: string;
  authorUrl?: string;
  description?: string;
  isAccessibleForFree: false;     // always false for paywalled
  paywallCssSelector: string;     // e.g. ".paywall"
}
```

## JSON-LD skeleton
```json
{
  "@context": "https://schema.org",
  "@type": "NewsArticle",
  "headline": "Article headline",
  "image": "https://example.com/thumbnail.jpg",
  "datePublished": "2025-02-05T08:00:00+00:00",
  "dateModified": "2025-02-05T09:20:00+00:00",
  "author": {
    "@type": "Person",
    "name": "John Doe",
    "url": "https://example.com/profile/johndoe"
  },
  "description": "A summary of the article visible before the paywall.",
  "isAccessibleForFree": false,
  "hasPart": {
    "@type": "WebPageElement",
    "isAccessibleForFree": false,
    "cssSelector": ".paywall"
  }
}
```

### HTML companion
```html
<div class="non-paywall">
  <!-- Freely visible content / preview paragraph -->
</div>
<div class="paywall">
  <!-- Subscriber-only content -->
</div>
```

## Pitfalls
- The `cssSelector` in `hasPart` must exactly match the class or selector wrapping the gated content in the HTML — a mismatch means Googlebot cannot identify paywalled sections and may flag cloaking.
- Never show Googlebot different content than what users see behind the paywall — that is cloaking and will result in a manual action.
- `isAccessibleForFree: false` at the article level plus `hasPart` with `isAccessibleForFree: false` is the correct pattern; do not omit either.
- This pattern should also be applied to AMP versions of the page when AMP is served.
- If the page is freely available to all (even if registration is required), set `isAccessibleForFree: true` and omit the `hasPart` paywall block.
- Multiple paywalled sections can be declared by passing an array to `hasPart`, each with its own `cssSelector`.
