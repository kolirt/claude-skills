# Article — editorial content, news, and blog posts
**When:** Page contains an article, news story, or blog post authored by a person or organisation.

## Fields
Required (Google): none explicitly — but omitting recommended fields reduces eligibility for rich results.

Recommended:
- `headline` — article title, max 110 characters.
- `image` — one or more URLs; supply 1×1, 4×3, and 16×9 variants for best coverage.
- `datePublished` — ISO 8601 datetime with timezone.
- `dateModified` — ISO 8601 datetime with timezone.
- `author` — `Person` or `Organization` with `.name` and `.url`.

## Input contract (neutral, not an entity)
```ts
interface ArticleSchemaInput {
  type: 'Article' | 'NewsArticle' | 'BlogPosting';
  headline: string;           // max 110 chars
  images: string[];           // at least one URL; 1×1, 4×3, 16×9 preferred
  datePublished: string;      // ISO 8601 with timezone
  dateModified: string;       // ISO 8601 with timezone
  authorName: string;
  authorUrl?: string;         // profile page URL
}
```

## JSON-LD skeleton
```json
{
  "@context": "https://schema.org",
  "@type": "NewsArticle",
  "headline": "Title of the Article",
  "image": [
    "https://example.com/photos/1x1/photo.jpg",
    "https://example.com/photos/4x3/photo.jpg",
    "https://example.com/photos/16x9/photo.jpg"
  ],
  "datePublished": "2025-01-05T08:00:00+00:00",
  "dateModified": "2025-01-06T09:00:00+00:00",
  "author": [{
    "@type": "Person",
    "name": "Jane Doe",
    "url": "https://example.com/profile/janedoe"
  }]
}
```

## Pitfalls
- `headline` is truncated in rich results if it exceeds 110 characters.
- Use `NewsArticle` for time-sensitive news; `BlogPosting` for informal blog content; `Article` as the generic fallback.
- Images must be crawlable and indexable; do not use placeholder or CDN-blocked URLs.
- `datePublished` and `dateModified` must match the visible dates on the page — mismatches can cause a manual action.
- Each author in the `author` array should have a `url` pointing to a profile page marked up with `ProfilePage` structured data.
- Multiple authors go in an array; never duplicate the type with separate script blocks.
- Timezone offset is strongly recommended; without it Googlebot defaults to its own timezone.
