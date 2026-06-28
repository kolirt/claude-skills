# EmployerAggregateRating — employer review aggregate markup

**When:** the page aggregates employee reviews of an employer or company and you want the aggregate rating displayed in Google Search results as a rich result snippet.

---

## Fields

### EmployerAggregateRating

Required (Google): `itemReviewed` (Organization with `name` and `sameAs`), `ratingValue` (Number), one of `ratingCount` or `reviewCount` (Integer).

Recommended: `bestRating` (defaults to 5 if omitted), `worstRating` (defaults to 1 if omitted), `ratingCount` (total number of ratings), `reviewCount` (total number of written reviews).

### itemReviewed (Organization)

Required: `name` — the employer's name.

Recommended: `sameAs` — canonical URL to the employer's website or a well-known knowledge graph entity (e.g. the company's official website). This helps Google disambiguate the employer entity.

---

## Input contract (neutral interface)

```ts
interface EmployerAggregateRatingSchemaInput {
  employer: {
    name: string;
    sameAs?: string;    // canonical URL, e.g. "https://www.example-corp.com"
  };
  ratingValue: number;  // numeric rating
  bestRating?: number;  // defaults to 5; set explicitly when using a different scale
  worstRating?: number; // defaults to 1
  ratingCount?: number; // total number of ratings
  reviewCount?: number; // total number of written reviews (use either or both)
}
```

---

## JSON-LD skeleton

```json
{
  "@context": "https://schema.org/",
  "@type": "EmployerAggregateRating",
  "itemReviewed": {
    "@type": "Organization",
    "name": "Example Corp",
    "sameAs": "https://www.example-corp.com"
  },
  "ratingValue": 3.9,
  "bestRating": 5,
  "worstRating": 1,
  "ratingCount": 847,
  "reviewCount": 612
}
```

---

## Pitfalls

- **`itemReviewed` is mandatory.** Omitting it produces an incomplete markup that Google cannot attribute to an employer entity and will not render as a rich result.
- **`sameAs` on the reviewed Organization improves entity disambiguation.** Without `sameAs`, Google must infer which company "Example Corp" refers to. Point `sameAs` to the company's canonical website or a prominent directory profile.
- **`ratingValue` must be within the `worstRating`–`bestRating` range.** A `ratingValue` of 3.9 with `bestRating: 5` is valid; a `ratingValue` of 8.2 with `bestRating: 5` is invalid and will be rejected.
- **At least one of `ratingCount` or `reviewCount` is required.** Providing both is preferred when the data is available; Google uses these numbers to evaluate the aggregate's credibility.
- **Content must reflect genuine employee reviews.** Fabricated, incentivised, or selectively cherry-picked ratings violate Google's review policies. The aggregate must be computed from actual employee submissions.
- **Page content must visibly show the ratings.** The markup must correspond to a rating display that users can see. A page that shows only the markup without a visible score will be treated as hidden structured data and may trigger a manual action.
- **Do not confuse with `AggregateRating`.** `AggregateRating` is the general-purpose aggregated rating type (used for Products, LocalBusiness, etc.). `EmployerAggregateRating` is the specific subtype for employer/workplace review aggregates and triggers the distinct employer rating rich result experience.
