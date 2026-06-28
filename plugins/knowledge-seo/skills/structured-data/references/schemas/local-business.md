# LocalBusiness — physical business location rich results
**When:** Any page describing a physical business location (store, restaurant, clinic, salon, etc.) where users can visit in person. Use the most specific `LocalBusiness` subtype available (e.g. `Restaurant`, `DaySpa`, `HealthClub`, `AutoRepair`, `Pharmacy`). If no precise subtype fits, use `LocalBusiness` directly.

Multiple subtypes are allowed as an array: `"@type": ["Electrician", "Plumber"]`.

`LocalBusiness` is a subtype of `Organization` — all `Organization` recommended fields (logo, sameAs, etc.) apply here too.

## Fields
Required (Google):
- `address` — `PostalAddress` with as many sub-fields as possible: `streetAddress`, `addressLocality`, `addressRegion`, `postalCode`, `addressCountry` (ISO 3166-1 alpha-2).

Recommended:
- `name` — business name; must exactly match the name displayed on the page and on Google Business Profile.
- `telephone` — primary customer-facing number; use E.164 format (`+14155551234`).
- `url` — URL of this specific location's page (not the home page if it is a chain).
- `image` — one or more image URLs (1×1, 4×3, 16×9 variants preferred).
- `geo` — `GeoCoordinates` with `latitude` and `longitude`; improves Maps integration.
- `openingHoursSpecification` — array of `OpeningHoursSpecification` objects (preferred over legacy `openingHours` string).
- `priceRange` — string of `$` symbols (e.g. `"$$"`).
- `servesCuisine` — (Restaurant subtype) comma-separated cuisine types.
- `menu` — (Restaurant) URL to the menu page.
- `department` — nested `LocalBusiness` blocks for in-store departments (e.g. `Pharmacy` inside a `Store`).

### Website-side notes (NAP parity, tel: links, store locator, multi-location)

**NAP parity (Name · Address · Phone):** The name, address, and phone number in the schema markup must be character-for-character identical to what appears in the visible HTML on the same page. Google cross-checks these; discrepancies between the markup and the page content can suppress or demote rich results and reduce trust for Google Business Profile merging.

**`tel:` links:** Render the telephone number as an HTML `<a href="tel:+14155551234">` link — it confirms to Googlebot that the number is interactive/real and not decorative text, and it enables tap-to-call on mobile. Include the identical value in `"telephone"` in the schema.

**Crawlable store locator:** For chains or franchises, each physical location must have its own crawlable HTML page (not rendered client-side only via JS) containing that location's markup. A single aggregated page with all locations in one JSON-LD block is not an equivalent substitute. Ensure the store locator pages are in the sitemap and not blocked by `robots.txt`.

**Multi-location `@id` and `branchOf`:** When a brand has multiple locations, give each location block a stable `@id` URI (e.g. `"@id": "https://www.example.com/locations/san-jose"`). Use `parentOrganization` (preferred over deprecated `branchOf`) to link each location back to the corporate entity. Example:

```json
{
  "@type": "Restaurant",
  "@id": "https://www.example.com/locations/san-jose",
  "name": "Example Diner — San Jose",
  "parentOrganization": {
    "@type": "Organization",
    "@id": "https://www.example.com",
    "name": "Example Diner"
  }
}
```

## Input contract (neutral, not an entity)
```ts
interface LocalBusinessSchemaInput {
  type: string;                // e.g. "Restaurant", "DaySpa", "LocalBusiness"
  id?: string;                 // stable URI for multi-location (@id)
  name: string;
  streetAddress: string;
  addressLocality: string;
  addressRegion?: string;
  postalCode: string;
  addressCountry: string;      // ISO 3166-1 alpha-2
  telephone?: string;          // E.164, e.g. "+14155551234"
  url?: string;                // URL of this location's page
  latitude?: number;
  longitude?: number;
  openingHours?: Array<{
    dayOfWeek: string[];       // "Monday", "Tuesday", etc.
    opens: string;             // "HH:MM"
    closes: string;            // "HH:MM"
    validFrom?: string;        // ISO date — omit for year-round
    validThrough?: string;
  }>;
  priceRange?: string;         // "$", "$$", "$$$"
  imageUrls?: string[];
  parentOrganizationId?: string;
}
```

## JSON-LD skeleton
```json
{
  "@context": "https://schema.org",
  "@type": "Restaurant",
  "@id": "https://www.example.com/locations/downtown",
  "name": "Example Diner — Downtown",
  "image": [
    "https://www.example.com/photos/1x1/diner.jpg",
    "https://www.example.com/photos/4x3/diner.jpg",
    "https://www.example.com/photos/16x9/diner.jpg"
  ],
  "address": {
    "@type": "PostalAddress",
    "streetAddress": "123 Main St",
    "addressLocality": "Springfield",
    "addressRegion": "IL",
    "postalCode": "62701",
    "addressCountry": "US"
  },
  "geo": {
    "@type": "GeoCoordinates",
    "latitude": 39.7999,
    "longitude": -89.6499
  },
  "telephone": "+12175550100",
  "url": "https://www.example.com/locations/downtown",
  "priceRange": "$$",
  "servesCuisine": "American",
  "openingHoursSpecification": [
    {
      "@type": "OpeningHoursSpecification",
      "dayOfWeek": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"],
      "opens": "11:00",
      "closes": "22:00"
    },
    {
      "@type": "OpeningHoursSpecification",
      "dayOfWeek": ["Saturday", "Sunday"],
      "opens": "10:00",
      "closes": "23:00"
    }
  ],
  "parentOrganization": {
    "@type": "Organization",
    "@id": "https://www.example.com",
    "name": "Example Diner"
  }
}
```

## Pitfalls
- Use the most specific subtype — `Restaurant` outperforms `LocalBusiness` for restaurant-related rich results. Browse `https://schema.org/LocalBusiness#subtypes` for the full list.
- NAP discrepancies between markup and visible page text are the single most common cause of LocalBusiness rich result suppression. Audit both in sync.
- Avoid using `openingHours` (legacy string format like `"Mo-Fr 09:00-17:00"`) alongside `openingHoursSpecification` — pick one; `openingHoursSpecification` is more expressive and handles seasonal or cross-midnight hours.
- For hours past midnight (e.g. Saturday bar stays open until 02:00 Sunday), use a single `OpeningHoursSpecification` with `"dayOfWeek": "Saturday"`, `"opens": "18:00"`, `"closes": "02:00"`.
- Do not place `LocalBusiness` markup on a page that is not specifically about that location (e.g. do not put it on the home page of a chain with 50 locations).
- `branchOf` is deprecated — use `parentOrganization` instead.
