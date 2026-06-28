# SoftwareApplication — software / app page markup

**When:** the page describes a downloadable or installable software application (mobile app, desktop program, or web app) and you want the app's price, platform, and rating to appear as rich results in Google Search.

---

## Fields

Required (Google): `name`, `operatingSystem`, `applicationCategory`.

Recommended: `offers` (with `price` and `priceCurrency`), `aggregateRating` (with `ratingValue` and `ratingCount`).

### `applicationCategory` accepted values (Google)

`GameApplication`, `SocialNetworkingApplication`, `TravelApplication`, `ShoppingApplication`, `SportsApplication`, `LifestyleApplication`, `BusinessApplication`, `DesignApplication`, `DeveloperApplication`, `DriverApplication`, `EducationalApplication`, `HealthApplication`, `FinanceApplication`, `SecurityApplication`, `BrowserApplication`, `CommunicationApplication`, `DesktopEnhancementApplication`, `EntertainmentApplication`, `MultimediaApplication`, `HomeApplication`, `UtilitiesApplication`, `ReferenceApplication`.

---

## Input contract (neutral, not an entity)

```ts
interface SoftwareApplicationSchemaInput {
  name: string;
  /** Platform string, e.g. "ANDROID", "iOS", "Windows", "macOS", "Web". */
  operatingSystem: string;
  /**
   * Must be one of the accepted schema.org/applicationCategory values
   * that Google recognises — see values list above.
   */
  applicationCategory: string;
  offers?: {
    price: number;          // 0 for free apps
    priceCurrency: string;  // ISO 4217, e.g. "USD"
  };
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
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  "name": "Example Note-Taking App",
  "operatingSystem": "Android",
  "applicationCategory": "UtilitiesApplication",
  "offers": {
    "@type": "Offer",
    "price": 0,
    "priceCurrency": "USD"
  },
  "aggregateRating": {
    "@type": "AggregateRating",
    "ratingValue": 4.6,
    "ratingCount": 8864,
    "bestRating": 5
  }
}
```

### Paid app variant

```json
{
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  "name": "Example Design Tool",
  "operatingSystem": "macOS, Windows",
  "applicationCategory": "DesignApplication",
  "offers": {
    "@type": "Offer",
    "price": 9.99,
    "priceCurrency": "USD"
  },
  "aggregateRating": {
    "@type": "AggregateRating",
    "ratingValue": 4.2,
    "ratingCount": 1230,
    "bestRating": 5
  }
}
```

---

## Pitfalls

- **`applicationCategory` must be an accepted value.** Google validates against a fixed list; unrecognised categories (e.g. `"App"` or `"Software"`) will not trigger the rich result. Use one of the listed values verbatim.
- **`operatingSystem` is a free-text string, not a URL.** Write `"Android"`, `"iOS"`, `"Windows"` — not a schema.org URL.
- **Free apps must still include `offers` with `price: 0`.** Omitting `offers` when the app is free means Google cannot display the price (shown as "Free") in the rich result.
- **`priceCurrency` is ISO 4217.** Use `"USD"`, `"EUR"`, `"GBP"` — not currency symbols.
- **`aggregateRating.ratingValue` must match the visible on-page rating.** Do not mark up a rating that is not displayed to the user.
- **First-party self-reviews prohibited.** Same rule as `Review` / `AggregateRating` — ratings must originate from real third-party users.
- **One schema block per app.** Do not output multiple `SoftwareApplication` blocks on the same page for the same app (e.g. splitting Android and iOS into two blocks); combine platforms in a single `operatingSystem` field separated by commas or use separate pages per platform.
- **Web apps:** Use `"operatingSystem": "Web"` and `"applicationCategory"` as appropriate; Google treats web apps the same as native apps for this rich result.
