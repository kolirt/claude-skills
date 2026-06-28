# Review / AggregateRating — user rating and review snippet markup

**When:** the page displays an authored review of a single item (`Review`), or aggregates ratings from multiple reviewers (`AggregateRating`), and you want star-rating rich results to appear under the blue link in Google Search. Both types must be about a supported item — products, books, movies, recipes, local businesses, or similar entities.

---

## Fields

### Review (single authored review)

Required (Google): `author` (nested `Person` or `Organization` with `name`), `itemReviewed` (with `name`), `reviewRating` (nested `Rating` with `ratingValue`).

Recommended: `datePublished`, `publisher`, `reviewBody`, `reviewRating.bestRating`, `reviewRating.worstRating`.

### AggregateRating (aggregated across many reviews)

Required (Google): `itemReviewed` (with `name`), `ratingValue`, one of `ratingCount` or `reviewCount`.

Recommended: `bestRating` (defaults to 5 if omitted), `worstRating` (defaults to 1 if omitted).

> **Note:** `AggregateRating` is most commonly embedded inside a `Product`, `LocalBusiness`, `Movie`, or `Recipe` node rather than used as a standalone top-level type. Either pattern is valid; use standalone only when the page is dedicated to ratings without a parent entity type.

---

## Input contract (neutral, not an entity)

```ts
interface ReviewSchemaInput {
  itemReviewed: {
    type: string;  // e.g. "Product", "Restaurant", "Book", "Movie"
    name: string;
    image?: string;
  };
  author: {
    type: "Person" | "Organization";
    name: string;
  };
  reviewRating: {
    ratingValue: number;
    bestRating?: number;   // defaults to 5
    worstRating?: number;  // defaults to 1
  };
  datePublished?: string;  // ISO 8601 date, e.g. "2024-03-15"
  publisher?: string;
  reviewBody?: string;
}

interface AggregateRatingSchemaInput {
  itemReviewed: {
    type: string;
    name: string;
    image?: string;
  };
  ratingValue: number;
  ratingCount?: number;
  reviewCount?: number; // at least one of ratingCount or reviewCount required
  bestRating?: number;  // defaults to 5
  worstRating?: number; // defaults to 1
}
```

---

## JSON-LD skeleton

### Standalone Review

```json
{
  "@context": "https://schema.org/",
  "@type": "Review",
  "itemReviewed": {
    "@type": "Product",
    "name": "Example Widget Pro",
    "image": "https://example.com/photos/widget.jpg"
  },
  "author": {
    "@type": "Person",
    "name": "Jane Smith"
  },
  "reviewRating": {
    "@type": "Rating",
    "ratingValue": 4,
    "bestRating": 5,
    "worstRating": 1
  },
  "datePublished": "2024-03-15",
  "publisher": {
    "@type": "Organization",
    "name": "Gadget Weekly"
  },
  "reviewBody": "A solid product with great build quality and easy setup."
}
```

### Standalone AggregateRating

```json
{
  "@context": "https://schema.org/",
  "@type": "AggregateRating",
  "itemReviewed": {
    "@type": "Product",
    "name": "Example Widget Pro",
    "image": "https://example.com/photos/widget.jpg"
  },
  "ratingValue": 4.4,
  "ratingCount": 89,
  "bestRating": 5,
  "worstRating": 1
}
```

### Embedded inside Product (most common pattern)

```json
{
  "@context": "https://schema.org/",
  "@type": "Product",
  "name": "Example Widget Pro",
  "image": "https://example.com/photos/widget.jpg",
  "aggregateRating": {
    "@type": "AggregateRating",
    "ratingValue": 4.4,
    "ratingCount": 89,
    "bestRating": 5
  },
  "review": [
    {
      "@type": "Review",
      "author": { "@type": "Person", "name": "Jane Smith" },
      "reviewRating": { "@type": "Rating", "ratingValue": 5 },
      "datePublished": "2024-03-15",
      "reviewBody": "Excellent quality and fast delivery."
    }
  ]
}
```

---

## Pitfalls

- **First-party self-reviews are banned.** Reviews written by the business itself, its employees, or agents violate Google's policy and can cause the entire domain to lose rich results. Reviews must come from third-party users.
- **`ratingValue` must reflect what is shown on page.** The numeric value in markup must match the visible rating displayed to users. Hiding a rating and marking up a different value is a spam signal.
- **`bestRating` defaults to 5, not 10.** If your scale is 1–10, always declare `"bestRating": 10`; omitting it makes Google interpret a score of 8 as near-perfect on a 1–5 scale.
- **At least one of `ratingCount` or `reviewCount` is required for `AggregateRating`.** Omitting both makes the node invalid.
- **`itemReviewed` must name a supported entity type.** Arbitrary or vague types (e.g. `"Thing"`) are unlikely to trigger rich results. Use `Product`, `LocalBusiness`, `Book`, `Movie`, `Recipe`, `Course`, or another concrete type.
- **Standalone `Review` type requires `itemReviewed`.** When `Review` is the root type rather than embedded in `Product`, Google requires `itemReviewed` to be present.
- **`datePublished` must be a real publish date.** Backdating or using a future date can be flagged as deceptive.
- **Do not apply review markup to review-listing/aggregation pages** that simply link to individual reviews hosted elsewhere. Markup must describe reviews visible and readable on the same page.
