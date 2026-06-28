# Movie — film carousel markup

**When:** the page presents a list of movies (e.g. best films of a year, award nominees, director filmography) and you want Google to display a swipeable movie carousel rich result in Search.

> Movie markup works as a **hosted carousel**: an `ItemList` on a single page lists movie items with their full details. Each item is a `Movie` node. There is no "summary + detail page" split requirement for movies; the all-in-one pattern is the standard approach.

---

## Fields

### ItemList (wrapper)

Required: `itemListElement` — array of `ListItem` nodes.

Each `ListItem` requires: `position` (Integer, 1-based), `item` (the `Movie` node).

### Movie (each item)

Required (Google): `name`, `url`.

Recommended: `image`, `dateCreated` (ISO 8601 date), `director` (Person with `name`), `aggregateRating` (AggregateRating with `ratingValue`, `ratingCount`, `bestRating`), `review` (Review with `reviewRating.ratingValue` and `author.name`), `description`.

---

## Input contract (neutral interface)

```ts
interface MovieCarouselSchemaInput {
  movies: Array<{
    position: number;
    url: string;
    name: string;
    image?: string;
    dateCreated?: string;      // ISO 8601 date, e.g. "2024-10-05"
    director?: { name: string };
    description?: string;
    aggregateRating?: {
      ratingValue: number;
      bestRating: number;
      ratingCount: number;
    };
    review?: {
      ratingValue: number;
      authorName: string;
    };
  }>;
}
```

---

## JSON-LD skeleton

```json
{
  "@context": "https://schema.org",
  "@type": "ItemList",
  "itemListElement": [
    {
      "@type": "ListItem",
      "position": 1,
      "item": {
        "@type": "Movie",
        "url": "https://example.com/movies/2024-best-picture-noms#film-one",
        "name": "The Grand Journey",
        "image": "https://example.com/photos/grand-journey-poster.jpg",
        "dateCreated": "2024-03-22",
        "description": "An epic adventure spanning three continents and two decades.",
        "director": {
          "@type": "Person",
          "name": "Maria Vega"
        },
        "aggregateRating": {
          "@type": "AggregateRating",
          "ratingValue": 88,
          "bestRating": 100,
          "ratingCount": 24501
        },
        "review": {
          "@type": "Review",
          "reviewRating": {
            "@type": "Rating",
            "ratingValue": 5
          },
          "author": {
            "@type": "Person",
            "name": "James L."
          }
        }
      }
    },
    {
      "@type": "ListItem",
      "position": 2,
      "item": {
        "@type": "Movie",
        "url": "https://example.com/movies/2024-best-picture-noms#film-two",
        "name": "Parallel Lives",
        "image": "https://example.com/photos/parallel-lives-poster.jpg",
        "dateCreated": "2024-07-14",
        "director": {
          "@type": "Person",
          "name": "Sam Okoro"
        },
        "aggregateRating": {
          "@type": "AggregateRating",
          "ratingValue": 74,
          "bestRating": 100,
          "ratingCount": 11823
        }
      }
    }
  ]
}
```

---

## Pitfalls

- **All movie URLs must share the same domain.** Each `Movie.url` must be on the same domain (or a sub/super domain) as the page containing the `ItemList`. Linking to third-party film databases (IMDb, Rotten Tomatoes) for the `url` field will cause the carousel to be rejected.
- **`position` must be 1-based and sequential.** Gaps or starting from 0 can cause carousel display issues. Numbering must match the visual order on the page.
- **`url` is required per Movie item.** Without a `url` on each `Movie`, Google cannot link users to the detail page, and the carousel item may be dropped.
- **`aggregateRating.bestRating` is necessary when using a non-5 scale.** If ratings are out of 100, set `"bestRating": 100`. Omitting it defaults to 5, which makes a score of `88` appear out of 5 rather than 100.
- **Markup must reflect content visible on the page.** The movie list in the markup must correspond to a visible movie list on the page. Hidden or non-displayed lists violate Google's policies.
- **Movie carousel is distinct from the general Carousel (ItemList).** While both use `ItemList`, Movie items do not link to separate detail pages the way recipe or course carousels do. The all-in-one structure with anchor-linked `url` values per item is the accepted pattern.
