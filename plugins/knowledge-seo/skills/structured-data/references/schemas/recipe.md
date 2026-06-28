# Recipe — cooking and food content markup

**When:** the page presents a recipe (dish or drink) with ingredients and preparation steps, and you want rich results in Google Search (recipe cards, host carousel, Knowledge Panel).

---

## Fields

### Recipe rich result

Required (Google): `name`, `image`.

Recommended: `author` (Person/Organization), `datePublished`, `description`, `recipeCuisine`, `prepTime`, `cookTime`, `totalTime`, `keywords`, `recipeYield`, `recipeCategory`, `nutrition` (NutritionInformation with `calories`), `aggregateRating` (ratingValue + ratingCount), `recipeIngredient` (array of strings), `recipeInstructions` (array of HowToStep with `text`; add `name`, `url`, `image` per step for best display), `video` (VideoObject).

Time values use ISO 8601 duration format (e.g. `"PT30M"` = 30 minutes, `"PT1H10M"` = 1 hour 10 minutes).

### Host carousel eligibility

To appear in a host carousel (a swipeable card list from one site), wrap individual recipe pages in an `ItemList` on the listing/index page. See `item-list.md` for the `ItemList` wrapper pattern.

---

## Input contract (neutral interface)

```ts
interface RecipeSchemaInput {
  name: string;
  /** Provide 1:1, 4:3, and 16:9 crops; minimum 50 K pixels each. */
  image: string | string[];
  description?: string;
  author?: { name: string; url?: string };
  datePublished?: string;        // ISO 8601 date
  prepTime?: string;             // ISO 8601 duration, e.g. "PT15M"
  cookTime?: string;
  totalTime?: string;
  recipeYield?: string | number; // e.g. "4 servings" or 12
  recipeCategory?: string;       // e.g. "Dessert"
  recipeCuisine?: string;        // e.g. "Italian"
  keywords?: string;
  recipeIngredient?: string[];
  recipeInstructions?: Array<{
    text: string;
    name?: string;
    url?: string;
    image?: string;
  }>;
  nutrition?: { calories: string }; // e.g. "240 calories"
  aggregateRating?: {
    ratingValue: number;
    ratingCount: number;
    bestRating?: number;
  };
}
```

---

## JSON-LD skeleton

```json
{
  "@context": "https://schema.org/",
  "@type": "Recipe",
  "name": "Classic Banana Bread",
  "image": [
    "https://example.com/photos/1x1/banana-bread.jpg",
    "https://example.com/photos/4x3/banana-bread.jpg",
    "https://example.com/photos/16x9/banana-bread.jpg"
  ],
  "author": { "@type": "Person", "name": "Jane Smith" },
  "datePublished": "2024-09-15",
  "description": "A moist banana bread with a crispy top crust, ready in under an hour.",
  "recipeCuisine": "American",
  "prepTime": "PT10M",
  "cookTime": "PT55M",
  "totalTime": "PT65M",
  "keywords": "banana, quick bread, breakfast",
  "recipeYield": "1 loaf",
  "recipeCategory": "Bread",
  "nutrition": {
    "@type": "NutritionInformation",
    "calories": "210 calories"
  },
  "aggregateRating": {
    "@type": "AggregateRating",
    "ratingValue": 4.8,
    "ratingCount": 312,
    "bestRating": 5
  },
  "recipeIngredient": [
    "3 ripe bananas, mashed",
    "1/3 cup melted butter",
    "3/4 cup sugar",
    "1 egg, beaten",
    "1 tsp vanilla",
    "1 tsp baking soda",
    "1/4 tsp salt",
    "1 1/2 cups all-purpose flour"
  ],
  "recipeInstructions": [
    {
      "@type": "HowToStep",
      "name": "Mix wet ingredients",
      "text": "Preheat oven to 175°C. Mix bananas, butter, sugar, egg, and vanilla in a bowl.",
      "url": "https://example.com/banana-bread#step1"
    },
    {
      "@type": "HowToStep",
      "name": "Combine and bake",
      "text": "Stir in baking soda and salt. Fold in flour until just combined. Pour into a greased loaf pan and bake 55 minutes.",
      "url": "https://example.com/banana-bread#step2"
    }
  ]
}
```

---

## Pitfalls

- **`image` is required and multi-crop matters.** Provide 1:1, 4:3, and 16:9 variants so Google can choose the best fit for each surface. A single square image often causes the recipe card to be skipped for non-square slots.
- **ISO 8601 durations.** Times must be in duration format (`"PT30M"`, `"PT1H15M"`), not plain strings like `"30 minutes"`. Invalid duration strings silently fail validation.
- **`recipeInstructions` must be `HowToStep` nodes.** A plain string array is not eligible for step-by-step display. Wrap each step in `{ "@type": "HowToStep", "text": "..." }`.
- **Do not mark up content not visible on the page.** Schema markup must reflect what a user can see. Listing ingredients or steps not shown on the page violates Google's policies.
- **`recipeYield` should describe servings, not just a number.** Use `"4 servings"` rather than `4` so the display makes sense to users.
- **`aggregateRating` without visible reviews.** If you show a star rating on the page, include `aggregateRating`. If ratings are behind a login or not shown to users, do not include it.
- **`nutrition.calories` format.** Include the unit: `"240 calories"`, not `240`. Google uses the string as-is in display.
