# recognition — content → schema recognition map

**This is the single source of truth for the content→schema recognition map.**
The `seo-audit` skill and the `vue-work` skill reference this table by name when
auto-applying structured data based on page content patterns.

---

## Content pattern → schema type

| Visible content pattern | Primary `@type`(s) | Notes |
|---|---|---|
| FAQ section / Q&A accordion | `FAQPage` + `Question` + `Answer` | Each question–answer pair maps to one `Question` entity. See FAQ caveat in `schema-types.md`. |
| Contacts block (address, phone, map) | `Organization` + `ContactPoint` | Use `PostalAddress` for the address; `telephone` for phone. |
| Reviews section / star rating | `Review` or `AggregateRating` | Use `AggregateRating` when aggregating multiple reviews; `Review` for a single authored review. |
| Price / buy button / add-to-cart | `Product` + `Offer` | `Offer.price` + `Offer.priceCurrency` required; `Offer.availability` from schema.org values. |
| Event listing / date + venue | `Event` | `startDate`, `endDate`, `location` are required by Google. |
| Article / news / blog post | `Article` or `BlogPosting` or `NewsArticle` | Use `NewsArticle` for timely news; `BlogPosting` for personal/editorial; `Article` for general. |
| Product listing / catalog grid | `ItemList` | Each item is a `ListItem` with `position` and `url`. |
| Video embed / video page | `VideoObject` | `name`, `description`, `thumbnailUrl`, `uploadDate` required. |
| Breadcrumb navigation | `BreadcrumbList` + `ListItem` | Apply to every page deeper than the home page. |
| Product detail page | `Product` + `Offer` | Combine with `AggregateRating` if reviews are shown. |
| Recipe / ingredient list + steps | `Recipe` | `recipeIngredient`, `recipeInstructions`, `cookTime` expected. |
| How-to / step-by-step guide | `HowTo` + `HowToStep` | Each step maps to one `HowToStep` with `text`. |
| Local business / store info | `LocalBusiness` (subtype) | Use the most precise subtype (e.g. `Restaurant`, `Store`). |
| Job listing / vacancy | `JobPosting` | `title`, `hiringOrganization`, `jobLocation`, `datePosted` required. |
| Course / curriculum | `Course` | `provider`, `description`, `hasCourseInstance` expected. |
| Software / app page | `SoftwareApplication` | `applicationCategory`, `operatingSystem` expected. |
| Person bio / author page | `Person` | Include `sameAs` array for authoritative profile links. |
| Organisation about page | `Organization` | Include `sameAs` array; `logo` property links the logo image. |
| Book / publication page | `Book` | `author`, `isbn`, `publisher` expected. |
| Home page (site root) | `WebSite` + `Organization` (or `Person`) | `WebSite` enables the site name in SERPs. |

---

## Usage by referencing skills

- **seo-audit**: scans visible page content against the patterns above; flags missing or
  mismatched schema types as audit findings.
- **vue-work**: when auto-generating page schema, resolves the correct `@type` by matching
  the page's content patterns to this table before delegating to the appropriate schema
  factory.

When a content pattern does not appear in this table, do not invent a type — consult
`schema-types.md` to determine whether an appropriate type exists in the catalog.
