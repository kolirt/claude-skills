# Product — e-commerce product page markup (snippet + merchant listing)

**When:** the page sells or describes a single purchasable item and you want price/rating rich results in Google Search, or eligibility for Google's free merchant-listing surfaces (Shopping tab, image search buying panel).

---

## Fields

### Product snippet (star rating / price in blue-link results)

Required (Google): at least one of `review`, `aggregateRating`, or `offers` must accompany the product, plus `name`.

Recommended: `image` (multiple aspect ratios), `description`, `brand`, `sku`, `mpn`, `offers.price`, `offers.priceCurrency`, `offers.availability`.

### Merchant listing (Shopping tab / image carousel)

Required (Google): `name`, `image`, `offers` — within `Offer`: `price` (> 0), `priceCurrency` (ISO 4217), `availability`.

Recommended: `offers.shippingDetails` (`OfferShippingDetails`), `offers.hasMerchantReturnPolicy` (reference via `@id` to a policy page, or inline `MerchantReturnPolicy`), `offers.itemCondition`, `offers.priceValidUntil`, `aggregateRating`.

Variants: wrap individual `Product` nodes inside a `ProductGroup` using `hasVariant`; set `variesBy` to the differentiating dimension (e.g. `"https://schema.org/color"`).

---

## Input contract (neutral, not an entity)

```ts
interface ProductSchemaInput {
  name: string;
  /** One or more image URLs. Provide 1:1, 4:3, and 16:9 crops when possible. */
  image: string | string[];
  description?: string;
  sku?: string;
  mpn?: string;
  brand?: string;
  offers: {
    price: number;           // must be > 0 for merchant listing
    priceCurrency: string;   // ISO 4217, e.g. "USD"
    availability: string;    // full schema.org URL, e.g. "https://schema.org/InStock"
    priceValidUntil?: string; // ISO 8601 date
    itemCondition?: string;  // e.g. "https://schema.org/NewCondition"
    /** Inline or @id reference to a MerchantReturnPolicy. */
    hasMerchantReturnPolicy?: object | { "@id": string };
    shippingDetails?: {
      shippingRate: { value: number | string; currency: string };
      shippingDestination: { addressCountry: string; addressRegion?: string[] }[];
      deliveryTime?: { minValue: number; maxValue: number; unitCode: string };
    };
  };
  aggregateRating?: {
    ratingValue: number;
    ratingCount: number;
    bestRating?: number;
  };
  review?: Array<{
    author: string;
    reviewRating: number;
    datePublished?: string;
  }>;
}
```

---

## JSON-LD skeleton

### Product snippet (with rating + price)

```json
{
  "@context": "https://schema.org/",
  "@type": "Product",
  "name": "Example Widget Pro",
  "image": [
    "https://example.com/photos/1x1/widget.jpg",
    "https://example.com/photos/4x3/widget.jpg",
    "https://example.com/photos/16x9/widget.jpg"
  ],
  "description": "A durable, lightweight widget for everyday use.",
  "sku": "WID-1234",
  "brand": { "@type": "Brand", "name": "Example Co" },
  "aggregateRating": {
    "@type": "AggregateRating",
    "ratingValue": 4.4,
    "ratingCount": 89,
    "bestRating": 5
  },
  "offers": {
    "@type": "Offer",
    "url": "https://example.com/products/widget-pro",
    "priceCurrency": "USD",
    "price": 49.99,
    "priceValidUntil": "2026-12-31",
    "availability": "https://schema.org/InStock",
    "itemCondition": "https://schema.org/NewCondition"
  }
}
```

### Merchant listing (with shipping + return policy reference)

```json
{
  "@context": "https://schema.org/",
  "@type": "Product",
  "name": "Example Widget Pro",
  "image": ["https://example.com/photos/1x1/widget.jpg"],
  "sku": "WID-1234",
  "brand": { "@type": "Brand", "name": "Example Co" },
  "offers": {
    "@type": "Offer",
    "priceCurrency": "USD",
    "price": 49.99,
    "priceValidUntil": "2026-12-31",
    "availability": "https://schema.org/InStock",
    "itemCondition": "https://schema.org/NewCondition",
    "hasMerchantReturnPolicy": {
      "@id": "https://example.com/returns#policy"
    },
    "shippingDetails": {
      "@type": "OfferShippingDetails",
      "shippingRate": {
        "@type": "MonetaryAmount",
        "value": "0",
        "currency": "USD"
      },
      "shippingDestination": [
        {
          "@type": "DefinedRegion",
          "addressCountry": "US"
        }
      ],
      "deliveryTime": {
        "@type": "ShippingDeliveryTime",
        "handlingTime": {
          "@type": "QuantitativeValue",
          "minValue": 0,
          "maxValue": 1,
          "unitCode": "DAY"
        },
        "transitTime": {
          "@type": "QuantitativeValue",
          "minValue": 3,
          "maxValue": 5,
          "unitCode": "DAY"
        }
      }
    }
  }
}
```

### Merchant listing (inline per-country return policy)

Use an inline `MerchantReturnPolicy` node when different countries have different return windows. Set `returnPolicyCountry` to the ISO 3166-1 alpha-2 country code.

```json
{
  "@context": "https://schema.org/",
  "@type": "Product",
  "name": "Example Widget Pro",
  "image": ["https://example.com/photos/1x1/widget.jpg"],
  "sku": "WID-1234",
  "brand": { "@type": "Brand", "name": "Example Co" },
  "offers": {
    "@type": "Offer",
    "priceCurrency": "USD",
    "price": 49.99,
    "priceValidUntil": "2026-12-31",
    "availability": "https://schema.org/InStock",
    "hasMerchantReturnPolicy": {
      "@type": "MerchantReturnPolicy",
      "returnPolicyCategory": "https://schema.org/MerchantReturnFiniteReturnWindow",
      "returnPolicyCountry": "US",
      "merchantReturnDays": 30
    }
  }
}
```

### Variant group (ProductGroup)

```json
{
  "@context": "https://schema.org/",
  "@type": "ProductGroup",
  "name": "Example Widget Pro",
  "productGroupID": "WID-PRO",
  "variesBy": "https://schema.org/color",
  "hasVariant": [
    {
      "@type": "Product",
      "name": "Example Widget Pro — Blue",
      "image": "https://example.com/photos/widget-blue.jpg",
      "color": "Blue",
      "sku": "WID-PRO-BLU",
      "offers": {
        "@type": "Offer",
        "priceCurrency": "USD",
        "price": 49.99,
        "availability": "https://schema.org/InStock"
      }
    },
    {
      "@type": "Product",
      "name": "Example Widget Pro — Red",
      "image": "https://example.com/photos/widget-red.jpg",
      "color": "Red",
      "sku": "WID-PRO-RED",
      "offers": {
        "@type": "Offer",
        "priceCurrency": "USD",
        "price": 49.99,
        "availability": "https://schema.org/OutOfStock"
      }
    }
  ]
}
```

---

## Pitfalls

- **Price > 0 for merchant listing.** Product snippets allow `price: 0` (e.g. free items); merchant listing experiences reject it. Always supply a real price.
- **`availability` must be a full URL.** Use `"https://schema.org/InStock"` not `"InStock"`. Valid values: `InStock`, `OutOfStock`, `PreOrder`, `BackOrder`, `Discontinued`, `LimitedAvailability`.
- **`priceCurrency` is ISO 4217.** Use `"USD"`, `"EUR"`, `"GBP"` — not currency symbols or locale-specific strings.
- **Image guidelines.** Minimum 50 K pixels (width × height). Provide 1:1, 4:3, and 16:9 variants. URLs must be crawlable.
- **`priceValidUntil` affects eligibility.** If the date passes without update, Google may demote or drop the rich result. Keep this date current.
- **Self-reviews are banned.** Ratings or reviews written by the seller or their agents violate Google's policy and can remove all rich results from the domain.
- **`hasMerchantReturnPolicy` at Offer level vs. Organisation level.** Prefer setting a global policy on `Organization` markup; use `Offer`-level only to override for specific products.
- **`ProductGroup` goes on the group page, not individual variant pages.** Each variant URL should carry its own `Product` markup; the `ProductGroup` belongs on the page that lists all variants.
- **Merchant listing URL 404 at time of authoring.** The dedicated merchant-listings doc path returned HTTP 404; the authoritative source at the time of writing was `developers.google.com/search/docs/appearance/structured-data/merchant-listing?hl=en`. Confirm current URL against the live Google rich-results gallery.
