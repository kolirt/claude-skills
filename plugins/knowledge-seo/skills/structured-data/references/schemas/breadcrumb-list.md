# BreadcrumbList — navigation trail markup

**When:** the page is deeper than the home page in the site hierarchy, and you want Google to display the breadcrumb path in the blue-link result instead of the raw URL. Apply to every non-home page.

---

## Fields

### BreadcrumbList

Required: `itemListElement` — ordered array of `ListItem` nodes representing the trail from root to current page.

### ListItem (each crumb)

Required: `position` (Integer, 1-based), `name` (Text — the human-readable label for the crumb).

Recommended: `item` (URL — the canonical URL of that level). The last crumb (current page) may omit `item`; all preceding crumbs should include it.

> Multiple breadcrumb trails can coexist on one page (e.g. when a page lives under two category paths). Emit one `BreadcrumbList` per trail as an array of JSON-LD blocks.

---

## Input contract (neutral interface)

```ts
interface BreadcrumbSchemaInput {
  /** One trail per array entry; multiple trails = multiple BreadcrumbList nodes. */
  trails: Array<Array<{
    position: number;   // 1-based
    name: string;
    url?: string;       // omit for the last (current) crumb
  }>>;
}
```

---

## JSON-LD skeleton

### Single trail

```json
{
  "@context": "https://schema.org",
  "@type": "BreadcrumbList",
  "itemListElement": [
    {
      "@type": "ListItem",
      "position": 1,
      "name": "Home",
      "item": "https://example.com/"
    },
    {
      "@type": "ListItem",
      "position": 2,
      "name": "Electronics",
      "item": "https://example.com/electronics"
    },
    {
      "@type": "ListItem",
      "position": 3,
      "name": "Laptops",
      "item": "https://example.com/electronics/laptops"
    },
    {
      "@type": "ListItem",
      "position": 4,
      "name": "ProBook X500"
    }
  ]
}
```

### Multiple trails (same page reachable via two category paths)

```json
[
  {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    "itemListElement": [
      { "@type": "ListItem", "position": 1, "name": "Home", "item": "https://example.com/" },
      { "@type": "ListItem", "position": 2, "name": "Books", "item": "https://example.com/books" },
      { "@type": "ListItem", "position": 3, "name": "Science Fiction", "item": "https://example.com/books/sci-fi" },
      { "@type": "ListItem", "position": 4, "name": "Award Winners" }
    ]
  },
  {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    "itemListElement": [
      { "@type": "ListItem", "position": 1, "name": "Home", "item": "https://example.com/" },
      { "@type": "ListItem", "position": 2, "name": "Literature", "item": "https://example.com/literature" },
      { "@type": "ListItem", "position": 3, "name": "Award Winners" }
    ]
  }
]
```

---

## Pitfalls

- **`position` is 1-based and must be sequential.** Numbering from 0 or leaving gaps breaks the trail display. Each crumb position must increment by 1.
- **The current page (last crumb) should omit `item`.** Google treats the last crumb as the current page; including a `url` there is acceptable but redundant. The preceding crumbs must have `item` set.
- **`name` must match the visible breadcrumb text on the page.** If the page shows "Electronics > Laptops > ProBook X500", the markup must use the same labels. Keyword-stuffed names ("Cheap Laptops Best Price") violate Google's quality guidelines.
- **All crumb URLs must be on the same domain.** Cross-domain `item` URLs are not permitted. Each URL must belong to the same site.
- **Do not put breadcrumbs on the home page.** A single-item trail containing only the home page has no SEO value and may confuse Google's parser.
- **BreadcrumbList enhances the URL display, not the ranking.** Adding breadcrumbs replaces the URL string in the snippet with the trail; it does not directly affect ranking. Apply it universally — the overhead per page is minimal and the UX benefit is consistent.
- **Avoid duplicating the current page title in `name` and `<title>` discrepancies.** Keep `name` aligned with the heading/page title so the breadcrumb display matches user expectations.
