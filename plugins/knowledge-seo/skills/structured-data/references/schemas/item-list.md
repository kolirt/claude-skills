# ItemList — carousel and list markup

**When:** the page presents a list of homogeneous items (recipes, courses, movies, articles, restaurants, products) and you want Google to display a swipeable carousel rich result or a structured list result in Search.

> `ItemList` is the container type. The carousel rich result is triggered when items are of a type that Google recognises for carousel display (Recipe, Course, Movie, Restaurant, Article, and others). A plain `ItemList` of links on a product catalog or article index also helps Google understand list structure even without carousel display.

---

## Fields

### ItemList

Required: `itemListElement` — array of `ListItem` nodes.

### ListItem — summary page pattern

Use when each item links to its own detail page. The `ListItem` contains a URL to the detail page; the full item markup lives on the detail page.

Required per `ListItem`: `position` (Integer, 1-based), `url` (URL of the detail page).

### ListItem — all-in-one page pattern

Use when all item content is on a single page. The `ListItem` contains the full inline item node.

Required per `ListItem`: `position`, `item` (the full typed item node such as `Recipe`, `Course`, or `Movie`). Each item must also have a `url` that is unique and may use anchor fragments (`#section-id`) when items live on the same page.

---

## Input contract (neutral interface)

```ts
// Summary page (items live on separate detail pages)
interface ItemListSummaryInput {
  items: Array<{
    position: number;
    url: string;  // URL of the detail page; must be same-domain
  }>;
}

// All-in-one page (all item content is inline)
interface ItemListAllInOneInput {
  items: Array<{
    position: number;
    item: {
      "@type": string;    // e.g. "Recipe", "Course", "Movie", "Article"
      url: string;        // unique URL or anchor fragment
      name: string;
      image?: string | string[];
      [key: string]: unknown;
    };
  }>;
}
```

---

## JSON-LD skeleton

### Summary page (items on separate detail pages)

Mark up the index page with `ItemList`. Each detail page carries its own full-type markup (e.g. `Recipe`).

```json
{
  "@context": "https://schema.org",
  "@type": "ItemList",
  "itemListElement": [
    {
      "@type": "ListItem",
      "position": 1,
      "url": "https://example.com/recipes/banana-bread"
    },
    {
      "@type": "ListItem",
      "position": 2,
      "url": "https://example.com/recipes/lemon-cake"
    },
    {
      "@type": "ListItem",
      "position": 3,
      "url": "https://example.com/recipes/apple-pie"
    }
  ]
}
```

### All-in-one page (inline item content)

```json
{
  "@context": "https://schema.org",
  "@type": "ItemList",
  "itemListElement": [
    {
      "@type": "ListItem",
      "position": 1,
      "item": {
        "@type": "Recipe",
        "url": "https://example.com/recipes#banana-bread",
        "name": "Classic Banana Bread",
        "image": ["https://example.com/photos/banana-bread.jpg"],
        "author": { "@type": "Person", "name": "Jane Smith" },
        "recipeYield": "1 loaf",
        "aggregateRating": {
          "@type": "AggregateRating",
          "ratingValue": 4.8,
          "ratingCount": 312
        }
      }
    },
    {
      "@type": "ListItem",
      "position": 2,
      "item": {
        "@type": "Recipe",
        "url": "https://example.com/recipes#lemon-cake",
        "name": "Lemon Drizzle Cake",
        "image": ["https://example.com/photos/lemon-cake.jpg"],
        "author": { "@type": "Person", "name": "Jane Smith" },
        "recipeYield": "12 slices",
        "aggregateRating": {
          "@type": "AggregateRating",
          "ratingValue": 4.6,
          "ratingCount": 190
        }
      }
    }
  ]
}
```

---

## Pitfalls

- **All URLs must be on the same domain.** Every `url` in `itemListElement` must belong to the same domain (or a sub/super domain) as the page hosting the `ItemList`. Cross-domain links are rejected.
- **Every URL must be unique within the list.** Duplicate URLs in a list cause items to be dropped from the carousel. Use anchor fragments (`#slug`) to differentiate items on the same page.
- **Minimum three items for carousel eligibility.** Google typically requires at least three items to render a carousel. A two-item list will not trigger carousel display.
- **`position` must be 1-based and sequential.** Starting at 0 or leaving gaps (1, 2, 4) can cause parsing errors. Always start at 1 and increment by 1.
- **Item type must be carousel-eligible.** Not all `@type` values produce carousel results. Types with known carousel support: `Recipe`, `Course`, `Movie`, `Restaurant`, `Article`, `NewsArticle`. A plain `ItemList` of generic links will not produce a visual carousel.
- **Summary page vs. all-in-one: do not mix patterns.** If using the summary-page pattern, put full markup on detail pages and only URLs on the list page. If using all-in-one, put all content inline. Mixing partial item data with partial detail-page data creates inconsistencies.
- **`ItemList` on a detail page is for host-carousel purposes only.** If a detail page (e.g. a recipe page) also includes `ItemList` markup to be part of a host carousel, the `ItemList` wrapper goes on the index/listing page, not the detail page.
