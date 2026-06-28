# Course — structured learning content with enrollment info

**When:** the page presents one or more structured courses (online or in-person) and you want Google's course list rich results. Minimum three courses are required for carousel eligibility.

> **Status note (June 2025):** The *CourseInfo carousel* format was retired by Google in June 2025. The *Course list* format (multiple `Course` nodes on one page, or a summary page linking to detail pages) remains active. Use the patterns below. Do not use the retired single-course `CourseInfo` carousel structure.

---

## Fields

### Course (list format)

Required (Google): `name`, `description` (display limit ~60 characters).

Recommended: `provider` (Organization with `name` and optionally `sameAs`).

### CourseInstance (course session details, on detail pages)

Recommended on detail pages alongside `Course`: `hasCourseInstance` containing a `CourseInstance` node with:
- `courseMode` — `"online"`, `"onsite"`, or `"blended"`.
- `instructor` — Person with `name`.
- `startDate` / `endDate` — ISO 8601 date.
- `location` — Place with `name` (for onsite).
- `offers` — Offer with `price`, `priceCurrency`, `url`, `availability`.
- `courseSchedule` — Schedule with `repeatFrequency`, `repeatCount`.

---

## Input contract (neutral interface)

```ts
interface CourseSchemaInput {
  name: string;
  description: string;   // keep under 60 characters for display
  provider?: { name: string; sameAs?: string };
  url?: string;          // canonical URL of the course detail page
  hasCourseInstance?: Array<{
    courseMode: "online" | "onsite" | "blended";
    instructor?: { name: string };
    startDate?: string;   // ISO 8601 date
    endDate?: string;
    location?: { name: string };
    offers?: {
      price: number | string;
      priceCurrency: string;
      url: string;
      availability?: string; // full schema.org URL
    };
  }>;
}

// Listing page: array of CourseSchemaInput wrapped in ItemList
interface CourseListingSchemaInput {
  courses: CourseSchemaInput[];
}
```

---

## JSON-LD skeleton

### Summary (listing) page — all-in-one

```json
{
  "@context": "https://schema.org/",
  "@type": "ItemList",
  "itemListElement": [
    {
      "@type": "ListItem",
      "position": 1,
      "item": {
        "@type": "Course",
        "url": "https://example.com/courses/intro-to-python",
        "name": "Introduction to Python",
        "description": "Learn Python programming from scratch in 6 weeks.",
        "provider": {
          "@type": "Organization",
          "name": "Example Academy",
          "sameAs": "https://example.com"
        }
      }
    },
    {
      "@type": "ListItem",
      "position": 2,
      "item": {
        "@type": "Course",
        "url": "https://example.com/courses/data-analysis",
        "name": "Data Analysis with Python",
        "description": "Master pandas and matplotlib for real-world data analysis.",
        "provider": {
          "@type": "Organization",
          "name": "Example Academy",
          "sameAs": "https://example.com"
        }
      }
    },
    {
      "@type": "ListItem",
      "position": 3,
      "item": {
        "@type": "Course",
        "url": "https://example.com/courses/machine-learning",
        "name": "Applied Machine Learning",
        "description": "Build and deploy ML models using scikit-learn and TensorFlow.",
        "provider": {
          "@type": "Organization",
          "name": "Example Academy",
          "sameAs": "https://example.com"
        }
      }
    }
  ]
}
```

### Detail page — Course with session info

```json
{
  "@context": "https://schema.org/",
  "@type": "Course",
  "name": "Introduction to Python",
  "description": "Learn Python programming from scratch in 6 weeks.",
  "provider": {
    "@type": "Organization",
    "name": "Example Academy",
    "sameAs": "https://example.com"
  },
  "hasCourseInstance": [
    {
      "@type": "CourseInstance",
      "courseMode": "online",
      "instructor": {
        "@type": "Person",
        "name": "Alex Johnson"
      },
      "startDate": "2026-09-01",
      "endDate": "2026-10-12",
      "offers": {
        "@type": "Offer",
        "price": 199,
        "priceCurrency": "USD",
        "url": "https://example.com/courses/intro-to-python/enroll",
        "availability": "https://schema.org/InStock"
      }
    },
    {
      "@type": "CourseInstance",
      "courseMode": "onsite",
      "location": {
        "@type": "Place",
        "name": "Example Academy Campus, New York"
      },
      "startDate": "2026-10-05",
      "endDate": "2026-11-16"
    }
  ]
}
```

---

## Pitfalls

- **Minimum three courses for carousel eligibility.** Google requires at least three distinct courses to display the carousel. Two or fewer courses will not render as a carousel.
- **`description` display limit is approximately 60 characters.** Longer descriptions are truncated in the rich result. Keep the key differentiation within the first 60 characters.
- **CourseInfo single-course carousel was retired June 2025.** Do not implement the legacy `CourseInfo` pattern that placed a single course in a hosted carousel slot. Use the `Course` + optional `CourseInstance` approach instead.
- **All course URLs must be on the same domain.** When using `ItemList`, every `url` in `itemListElement` must belong to the same domain or a sub/super domain of the current page.
- **`courseMode` values are a fixed vocabulary.** Use `"online"`, `"onsite"`, or `"blended"` exactly. Free-form strings such as `"Online"` or `"virtual"` are not recognised.
- **`provider` is recommended, not required, but omitting it reduces eligibility.** When a single organization runs all courses, define `provider` once per course or use a shared `@id` reference.
