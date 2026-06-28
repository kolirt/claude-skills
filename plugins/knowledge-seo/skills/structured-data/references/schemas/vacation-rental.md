# VacationRental — short-term accommodation listing markup

**When:** the page represents a vacation rental property (entire home, private room, or shared room) listed on a booking platform or direct-booking site, and you want the listing surfaced in Google's vacation rental and hotel search experiences.

---

## Fields

### VacationRental required

| Property | Type | Notes |
|---|---|---|
| `identifier` | Text | Stable, content-independent unique ID for the property. Must not change when listing content updates. Use the same ID across language variants. |
| `image` | Repeated URL | Minimum 8 photos required; must include at least one each of: bedroom, bathroom, and common area. |
| `containsPlace` | Accommodation | Nested node describing the physical accommodation unit. |
| `containsPlace.occupancy` | QuantitativeValue | Maximum guest count. |
| `containsPlace.occupancy.value` | Integer | Numeric maximum guest count. |

### VacationRental recommended

`name`, `description`, `address` (PostalAddress), `checkinTime` / `checkoutTime` (ISO 8601 time with UTC offset), `petsAllowed` (Boolean), `brand` (Brand with `name`), `aggregateRating`.

### containsPlace recommended

`additionalType` — room type: `"EntirePlace"`, `"PrivateRoom"`, or `"SharedRoom"`.
`amenityFeature` (LocationFeatureSpecification with `name`, `value`/Boolean), `bed` (BedDetails with `numberOfBeds`, `typeOfBed`), `floorSize` (QuantitativeValue with `value` + `unitCode`: `"MTK"` for m² or `"FTK"` for ft²), `numberOfBedrooms`, `numberOfBathroomsTotal`.

---

## Input contract (neutral interface)

```ts
interface VacationRentalSchemaInput {
  identifier: string;
  image: string[];              // minimum 8 URLs
  name?: string;
  description?: string;
  address?: {
    streetAddress?: string;
    addressLocality: string;
    addressRegion?: string;
    postalCode?: string;
    addressCountry: string;     // ISO 3166-1 alpha-2, e.g. "US"
  };
  checkinTime?: string;         // ISO 8601 time, e.g. "15:00:00+00:00"
  checkoutTime?: string;
  petsAllowed?: boolean;
  brand?: string;
  containsPlace: {
    additionalType?: "EntirePlace" | "PrivateRoom" | "SharedRoom";
    occupancy: { value: number };
    numberOfBedrooms?: number;
    numberOfBathroomsTotal?: number;
    floorSize?: { value: number; unitCode: "MTK" | "FTK" };
    bed?: Array<{ numberOfBeds: number; typeOfBed: string }>;
    amenityFeature?: Array<{
      name: string;
      value: boolean | string;
    }>;
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
  "@context": "https://schema.org/",
  "@type": "VacationRental",
  "name": "Oceanfront Cottage with Private Beach",
  "identifier": "prop-00142",
  "description": "A serene two-bedroom cottage steps from a private beach. Ideal for families of up to four.",
  "image": [
    "https://example.com/photos/cottage/bedroom-1.jpg",
    "https://example.com/photos/cottage/bedroom-2.jpg",
    "https://example.com/photos/cottage/bathroom.jpg",
    "https://example.com/photos/cottage/living-room.jpg",
    "https://example.com/photos/cottage/kitchen.jpg",
    "https://example.com/photos/cottage/outdoor.jpg",
    "https://example.com/photos/cottage/exterior.jpg",
    "https://example.com/photos/cottage/beach-access.jpg"
  ],
  "address": {
    "@type": "PostalAddress",
    "addressLocality": "Malibu",
    "addressRegion": "CA",
    "addressCountry": "US"
  },
  "checkinTime": "15:00:00+00:00",
  "checkoutTime": "11:00:00+00:00",
  "petsAllowed": false,
  "brand": { "@type": "Brand", "name": "brandIdName" },
  "containsPlace": {
    "@type": "Accommodation",
    "additionalType": "EntirePlace",
    "occupancy": {
      "@type": "QuantitativeValue",
      "value": 4
    },
    "numberOfBedrooms": 2,
    "numberOfBathroomsTotal": 1,
    "floorSize": {
      "@type": "QuantitativeValue",
      "value": 85,
      "unitCode": "MTK"
    },
    "bed": [
      { "@type": "BedDetails", "numberOfBeds": 1, "typeOfBed": "King" },
      { "@type": "BedDetails", "numberOfBeds": 2, "typeOfBed": "Single" }
    ],
    "amenityFeature": [
      {
        "@type": "LocationFeatureSpecification",
        "name": "WiFi",
        "value": true
      },
      {
        "@type": "LocationFeatureSpecification",
        "name": "Air conditioning",
        "value": true
      },
      {
        "@type": "LocationFeatureSpecification",
        "name": "Kitchen",
        "value": true
      }
    ]
  },
  "aggregateRating": {
    "@type": "AggregateRating",
    "ratingValue": 4.7,
    "ratingCount": 63,
    "bestRating": 5
  }
}
```

---

## Pitfalls

- **Minimum 8 images is a hard requirement.** Fewer images will cause the listing to be ineligible for Google vacation rental experiences. Each photo must be crawlable and indexable.
- **`identifier` must be stable.** Do not use the listing title, URL, or any content-derived value. Changing the identifier breaks Google's ability to track the property across updates and languages.
- **`brand` must match Hotel Center.** The `brand.name` value must correspond to a brand ID registered in Google Hotel Center. Using a free-form name does not link to hotel branding.
- **`amenityFeature` values must be in English.** Both `name` and string `value` must be English strings even for non-English page locales, per Google's specification.
- **`containsPlace.additionalType` is limited to three exact strings.** Only `"EntirePlace"`, `"PrivateRoom"`, and `"SharedRoom"` are recognized; any other value is ignored.
- **This type targets Google's accommodation surfaces, not the main rich results gallery.** Do not expect traditional rich result snippets. The benefit appears in Google's hotel and vacation rental search surfaces, which require a Google Hotel Center integration.
