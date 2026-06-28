# Organization — site-wide organisation identity and knowledge panel
**When:** Any page where you want Google to understand the publisher/brand behind the site; typically placed on the home page or a dedicated about page. Also used as a nested type inside `LocalBusiness`, `JobPosting` (`hiringOrganization`), and `ProfilePage`.

## Fields
Required (Google): none — all properties are recommended; include what applies to your organisation.

Recommended:
- `name` — legal or trading name; must match the site name Google shows in search results.
- `alternateName` — abbreviated name, DBA, or trade name.
- `url` — canonical home-page URL; helps Google uniquely identify the entity.
- `logo` — `ImageObject` with `url` (the logo image), `width`, and `height`; minimum 112 × 112 px, max 1 MB, no animation.
- `sameAs` — array of URLs to authoritative external profiles (Wikipedia, Wikidata, social networks, review platforms); each URL must resolve to a page that unambiguously identifies the same organisation.
- `contactPoint` — `ContactPoint` with `telephone`, `contactType` (e.g. `"customer service"`), and optionally `areaServed`, `availableLanguage`.
- `address` — `PostalAddress` with `streetAddress`, `addressLocality`, `addressRegion`, `postalCode`, `addressCountry`.
- `telephone` — primary public phone number including country and area code.
- `taxID` / `vatID` — tax identifier; `addressCountry` must match the issuing country.
- `numberOfEmployees` — `QuantitativeValue` with `value` or `minValue`/`maxValue`.

## Input contract (neutral, not an entity)
```ts
interface OrganizationSchemaInput {
  name: string;
  url: string;
  logoUrl: string;
  logoWidth?: number;       // px
  logoHeight?: number;      // px
  alternateName?: string;
  sameAs?: string[];        // social / wiki URLs
  telephone?: string;       // E.164 preferred, e.g. "+14155551234"
  contactType?: string;     // e.g. "customer service"
  streetAddress?: string;
  addressLocality?: string;
  addressRegion?: string;
  postalCode?: string;
  addressCountry?: string;  // ISO 3166-1 alpha-2
}
```

## JSON-LD skeleton
```json
{
  "@context": "https://schema.org",
  "@type": "Organization",
  "name": "Example Corp",
  "alternateName": "ExCorp",
  "url": "https://www.example.com",
  "logo": {
    "@type": "ImageObject",
    "url": "https://www.example.com/images/logo.png",
    "width": 300,
    "height": 100
  },
  "sameAs": [
    "https://www.facebook.com/example",
    "https://twitter.com/example",
    "https://www.linkedin.com/company/example",
    "https://en.wikipedia.org/wiki/Example_Corp"
  ],
  "contactPoint": {
    "@type": "ContactPoint",
    "telephone": "+1-800-555-1234",
    "contactType": "customer service",
    "areaServed": "US",
    "availableLanguage": "English"
  },
  "address": {
    "@type": "PostalAddress",
    "streetAddress": "123 Main St",
    "addressLocality": "Springfield",
    "addressRegion": "IL",
    "postalCode": "62701",
    "addressCountry": "US"
  }
}
```

## Pitfalls
- `name` must be consistent with the site name Google displays — do not use marketing slogans or ALL CAPS variants.
- `logo` must be a stable, crawlable URL; do not use base64 data URIs or CDN URLs that require auth headers.
- `sameAs` URLs must point to pages that are clearly about this organisation, not just brand mentions. Include Wikidata (`https://www.wikidata.org/wiki/Q…`) when available — it is the highest-confidence signal.
- A single `contactPoint` is sufficient for most sites; do not add dummy entries to inflate presence.
- `taxID` is country-specific: e.g. EIN in the US, CRN in the UK — populate only when you have a real value.
- `Organization` and `LocalBusiness` overlap. If the business has a physical walk-in location, use `LocalBusiness` (a subtype of `Organization`) and add `Organization` fields there directly; do not emit two separate top-level blocks with conflicting `name`.
