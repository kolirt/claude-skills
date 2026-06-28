# JobPosting — employment listing rich results
**When:** Page describes a single open job position posted by an employer. Eligible for Job Search rich results in Google Search (enhanced display with title, company, location, salary, and apply button).

## Fields
Required (Google):
- `title` — exact job title as it would appear on a business card or in an internal system.
- `description` — full job description in HTML or plain text; must be substantive (not a one-liner). Minimum viable: role summary + responsibilities + qualifications.
- `datePosted` — ISO 8601 date when the job was posted (e.g. `"2025-01-18"`).
- `hiringOrganization` — `Organization` with at minimum `name`; strongly recommended to add `sameAs` (company website) and `logo`.
- `jobLocation` — `Place` with `address` (`PostalAddress`). For remote roles see `jobLocationType`.

Recommended:
- `validThrough` — ISO 8601 datetime after which the posting is no longer valid. Google may stop showing the posting after this date.
- `employmentType` — one or more of: `FULL_TIME`, `PART_TIME`, `CONTRACTOR`, `TEMPORARY`, `INTERN`, `VOLUNTEER`, `PER_DIEM`, `OTHER`.
- `baseSalary` — `MonetaryAmount` with `currency` and `value` (`QuantitativeValue` with `value` or `minValue`/`maxValue` and `unitText`: `HOUR`, `DAY`, `WEEK`, `MONTH`, `YEAR`).
- `identifier` — `PropertyValue` with `name` (company name) and `value` (internal job ID).
- `jobLocationType` — set to `"TELECOMMUTE"` for fully remote roles; pair with `applicantLocationRequirements` (`Country` or `State`).
- `applicantLocationRequirements` — `Country` (or more specific) describing where applicants must be located for remote roles.
- `educationRequirements` — `EducationalOccupationalCredential` with `credentialCategory`.
- `experienceRequirements` — `OccupationalExperienceRequirements` with `monthsOfExperience`.

## Input contract (neutral, not an entity)
```ts
interface JobPostingSchemaInput {
  title: string;
  description: string;          // HTML allowed
  datePosted: string;           // ISO 8601 date
  validThrough?: string;        // ISO 8601 datetime
  employmentType?: string | string[];
  organizationName: string;
  organizationUrl?: string;
  organizationLogo?: string;
  streetAddress?: string;
  addressLocality?: string;
  addressRegion?: string;
  postalCode?: string;
  addressCountry?: string;      // ISO 3166-1 alpha-2
  isRemote?: boolean;
  remoteCountry?: string;       // for applicantLocationRequirements
  salaryValue?: number;
  salaryMin?: number;
  salaryMax?: number;
  salaryCurrency?: string;      // ISO 4217 e.g. "USD"
  salaryUnit?: string;          // "HOUR" | "DAY" | "WEEK" | "MONTH" | "YEAR"
  jobId?: string;               // internal identifier
}
```

## JSON-LD skeleton
```json
{
  "@context": "https://schema.org",
  "@type": "JobPosting",
  "title": "Senior Software Engineer",
  "description": "<p>We are looking for a senior engineer to join our platform team. Responsibilities include designing distributed systems, mentoring junior engineers, and owning reliability targets.</p><p>Requirements: 5+ years of backend experience, proficiency in Go or Python.</p>",
  "identifier": {
    "@type": "PropertyValue",
    "name": "Example Corp",
    "value": "ENG-2025-042"
  },
  "datePosted": "2025-06-01",
  "validThrough": "2025-09-01T00:00",
  "employmentType": "FULL_TIME",
  "hiringOrganization": {
    "@type": "Organization",
    "name": "Example Corp",
    "sameAs": "https://www.example.com",
    "logo": "https://www.example.com/images/logo.png"
  },
  "jobLocation": {
    "@type": "Place",
    "address": {
      "@type": "PostalAddress",
      "streetAddress": "123 Main St",
      "addressLocality": "Austin",
      "addressRegion": "TX",
      "postalCode": "73301",
      "addressCountry": "US"
    }
  },
  "baseSalary": {
    "@type": "MonetaryAmount",
    "currency": "USD",
    "value": {
      "@type": "QuantitativeValue",
      "minValue": 140000,
      "maxValue": 180000,
      "unitText": "YEAR"
    }
  }
}
```

### Remote / work-from-home variant
```json
{
  "@context": "https://schema.org",
  "@type": "JobPosting",
  "title": "Remote Data Analyst",
  "description": "<p>Analyse product metrics and deliver weekly insights to leadership.</p>",
  "datePosted": "2025-06-01",
  "validThrough": "2025-09-01T00:00",
  "employmentType": "FULL_TIME",
  "jobLocationType": "TELECOMMUTE",
  "applicantLocationRequirements": {
    "@type": "Country",
    "name": "US"
  },
  "hiringOrganization": {
    "@type": "Organization",
    "name": "Example Corp",
    "sameAs": "https://www.example.com"
  },
  "baseSalary": {
    "@type": "MonetaryAmount",
    "currency": "USD",
    "value": {
      "@type": "QuantitativeValue",
      "value": 90000,
      "unitText": "YEAR"
    }
  }
}
```

## Pitfalls
- `description` must be substantive — thin descriptions (one sentence) will fail Google's content quality check and suppress the rich result.
- Do not use `validThrough` as a "soft close" date and then leave the posting live past it — Google may stop showing it. Remove or update the markup when the position is filled.
- `employmentType` values are enumerated strings (`FULL_TIME`, not `Full-time`); incorrect casing or phrasing is silently ignored.
- For remote roles, `jobLocationType: "TELECOMMUTE"` must be paired with `applicantLocationRequirements`; without it Google cannot determine who the remote role is open to.
- When a role has a physical office option and a remote option, provide both: include `jobLocation` (the office) AND `jobLocationType: "TELECOMMUTE"`.
- `baseSalary.value.unitText` must be one of the exact enum values (`HOUR`, `DAY`, `WEEK`, `MONTH`, `YEAR`).
- The job posting page must be publicly accessible — gated or login-required pages are ineligible for Job Search rich results.
- Each open position should have its own dedicated URL; listing multiple roles on one page with one `JobPosting` block will not produce correct results.
