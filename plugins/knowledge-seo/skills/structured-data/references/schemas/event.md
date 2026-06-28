# Event — concerts, webinars, in-person and virtual events
**When:** Page describes a specific scheduled event with a date, time, and location (physical, virtual, or hybrid). Eligible for Event rich results in Google Search.

## Fields
Required (Google):
- `name` — title of the event.
- `startDate` — ISO 8601 datetime with timezone offset (e.g. `"2025-07-21T19:00-05:00"`); include time, not just date.
- `location` — `Place` object with `location.address` (`PostalAddress`). For online-only events use `VirtualLocation` with a `url`; for hybrid use both.

Recommended:
- `endDate` — ISO 8601 datetime; same format as `startDate`. Helps users find events that fit their schedule.
- `eventStatus` — one of: `EventScheduled`, `EventCancelled`, `EventMovedOnline`, `EventPostponed`, `EventRescheduled`. Defaults to `EventScheduled` if omitted. Do not remove `startDate` when status changes.
- `eventAttendanceMode` — `OfflineEventAttendanceMode`, `OnlineEventAttendanceMode`, or `MixedEventAttendanceMode`.
- `description` — concise description of the event; do not repeat date/location fields.
- `image` — array of image URLs; supply 1×1, 4×3, and 16×9 variants; minimum 720 px wide (1920 px recommended).
- `offers` — `Offer` with `url`, `price`, `priceCurrency`, `availability`, `validFrom`.
- `organizer` — `Organization` or `Person` with `name` and `url`.
- `performer` — `PerformingGroup`, `Person`, or `MusicGroup` with `name`.
- `location.name` — venue name (e.g. `"Madison Square Garden"`); do not repeat the event title here.

## Input contract (neutral, not an entity)
```ts
interface EventSchemaInput {
  name: string;
  startDate: string;              // ISO 8601 with timezone
  endDate?: string;               // ISO 8601 with timezone
  eventStatus?: string;           // schema.org EventStatusType URL suffix
  attendanceMode?: string;        // schema.org EventAttendanceModeEnumeration URL suffix
  venueName?: string;
  streetAddress?: string;
  addressLocality?: string;
  addressRegion?: string;
  postalCode?: string;
  addressCountry?: string;        // ISO 3166-1 alpha-2
  virtualUrl?: string;            // for online events
  description?: string;
  imageUrls?: string[];
  offerUrl?: string;
  offerPrice?: number | string;   // 0 for free events
  offerCurrency?: string;         // ISO 4217 e.g. "USD"
  offerAvailability?: string;     // schema.org ItemAvailability URL suffix
  offerValidFrom?: string;        // ISO 8601
  organizerName?: string;
  organizerUrl?: string;
}
```

## JSON-LD skeleton
```json
{
  "@context": "https://schema.org",
  "@type": "Event",
  "name": "Annual Tech Summit",
  "startDate": "2025-09-15T09:00-05:00",
  "endDate": "2025-09-15T18:00-05:00",
  "eventStatus": "https://schema.org/EventScheduled",
  "eventAttendanceMode": "https://schema.org/OfflineEventAttendanceMode",
  "location": {
    "@type": "Place",
    "name": "Convention Center East",
    "address": {
      "@type": "PostalAddress",
      "streetAddress": "500 E Trade St",
      "addressLocality": "Charlotte",
      "addressRegion": "NC",
      "postalCode": "28202",
      "addressCountry": "US"
    }
  },
  "image": [
    "https://www.example.com/events/summit-1x1.jpg",
    "https://www.example.com/events/summit-4x3.jpg",
    "https://www.example.com/events/summit-16x9.jpg"
  ],
  "description": "A full-day conference on emerging software technologies.",
  "offers": {
    "@type": "Offer",
    "url": "https://www.example.com/events/summit/tickets",
    "price": 199,
    "priceCurrency": "USD",
    "availability": "https://schema.org/InStock",
    "validFrom": "2025-06-01T00:00-05:00"
  },
  "organizer": {
    "@type": "Organization",
    "name": "Example Tech Group",
    "url": "https://www.example.com"
  }
}
```

### Online event variant
```json
{
  "@context": "https://schema.org",
  "@type": "Event",
  "name": "Virtual Product Launch",
  "startDate": "2025-10-01T14:00+00:00",
  "endDate": "2025-10-01T15:30+00:00",
  "eventStatus": "https://schema.org/EventScheduled",
  "eventAttendanceMode": "https://schema.org/OnlineEventAttendanceMode",
  "location": {
    "@type": "VirtualLocation",
    "url": "https://www.example.com/live/product-launch"
  },
  "offers": {
    "@type": "Offer",
    "url": "https://www.example.com/live/register",
    "price": 0,
    "priceCurrency": "USD",
    "availability": "https://schema.org/InStock"
  }
}
```

## Pitfalls
- `startDate` must include the time and timezone — a date-only value (e.g. `"2025-09-15"`) may be accepted but produces lower-quality rich results.
- When an event is cancelled or rescheduled, **do not delete the markup** — update `eventStatus` and keep the original `startDate` so Google can match and delist the old event correctly.
- `location.name` must be the venue name, not the event title; putting the event title there is a common mistake caught by Rich Results Test.
- For free events, set `"price": 0` explicitly — do not omit `offers` entirely if the event is ticketed.
- `image` dimensions: minimum 50 000 px² (width × height); minimum width 720 px. Provide all three aspect ratios for best carousel coverage.
- Do not mark up events that have already ended — outdated event markup can be demoted.
- `eventAttendanceMode` must use a full schema.org URL (`https://schema.org/OfflineEventAttendanceMode`), not just the short name.
