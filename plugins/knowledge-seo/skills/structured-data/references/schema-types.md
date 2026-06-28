# schema-types — working-type catalog

This file is the authoritative type catalog for the `structured-data` skill.
A type is usable **only if it appears here**. Absence = do not use.

> **Reconciliation complete (Task 18, 2026-06-28):** The table below has been
> reconciled against the live Google Search Central rich-results gallery and current
> documentation. Changes from reconciliation:
> - ADDED deep files: `recipe.md`, `vacation-rental.md`, `course.md`, `math-solver.md`,
>   `movie.md`, `breadcrumb-list.md`, `item-list.md`, `faq-page.md`,
>   `education-qa.md` (reconciliation addition), `employer-rating.md` (reconciliation addition).
> - SKIPPED / MARKED REMOVED: `Dataset` (retired from rich results late 2025),
>   `Practice problems` (retired late 2025), `How-to` (rich results removed Sept 2023),
>   `Learning video` as a distinct rich-result type (retired June 2025; `VideoObject`
>   for regular video is still active — see `video.md`), `ClaimReview` / Fact check
>   (retired June 2025), `VehicleListing` (retired June 2025), `EstimatedSalary`
>   (retired June 2025), `FAQPage` rich result (discontinued all sites May 7, 2026 —
>   `faq-page.md` written with full discontinued caveat; markup still aids AI extraction).
> - CourseInfo carousel retired June 2025; Course list format remains active (see `course.md`).

---

## Page → type cheat-sheet

| Page / context | Primary type(s) | Supporting type(s) |
|---|---|---|
| Home page | `WebSite` + `Organization` (or `Person`) | — |
| Article / blog post | `Article` or `BlogPosting` | `BreadcrumbList` |
| News article | `NewsArticle` | `BreadcrumbList` |
| Product / card page | `Product` + `Offer` | `BreadcrumbList`, `AggregateRating` |
| Product listing / catalog | `ItemList` | `BreadcrumbList` |
| Recipe page | `Recipe` | `BreadcrumbList` |
| Event page | `Event` | `BreadcrumbList` |
| Video page / embed | `VideoObject` | `BreadcrumbList` |
| FAQ / Q&A page | `FAQPage` | — |
| How-to / instructional | `HowTo` | `BreadcrumbList` |
| Local business page | `LocalBusiness` (or subtype) | `PostalAddress`, `GeoCoordinates` |
| Person / author bio | `Person` | `sameAs` links |
| Organisation about page | `Organization` | `sameAs` links |
| Review page | `Review` or `AggregateRating` | `Product` / `LocalBusiness` |
| Course page | `Course` | `BreadcrumbList` |
| Job posting | `JobPosting` | — |
| Software / app | `SoftwareApplication` | `AggregateRating` |
| Book page | `Book` | `BreadcrumbList` |
| Any page deeper than home | — | `BreadcrumbList` |

---

## Google rich-result feature table

> **FAQ status (May 7, 2026):** Google discontinued FAQPage rich results for all sites. `faq-page.md` is provided for AI-extraction signal only — do not implement expecting a Google rich-result display.
>
> **Dataset status (late 2025):** Retired from Google rich results. No deep file. Do not use for rich-result benefit.

| Feature | `@type`(s) | When to use | Deep file |
|---|---|---|---|
| Article rich result | `Article` / `NewsArticle` / `BlogPosting` | Editorial content, news, blog posts | ✓ `schemas/article.md` |
| Breadcrumb | `BreadcrumbList` + `ListItem` | Any page deeper than home | ✓ `schemas/breadcrumb-list.md` |
| Carousel (hosted) | `ItemList` + item types | Lists of articles, recipes, courses, restaurants | ✓ `schemas/item-list.md` |
| Course | `Course` + `CourseInstance` | Structured learning content with enrollment info (list format only; CourseInfo carousel retired June 2025) | ✓ `schemas/course.md` |
| Dataset | `Dataset` | ~~Research / open data~~ — **REMOVED** from rich results late 2025. Do not use for SEO benefit. | — removed |
| Discussion forum | `DiscussionForumPosting` / `SocialMediaPosting` | Forum threads and social media posts | ✓ `schemas/discussion-forum.md` |
| Education Q&A | `Quiz` + `Question` + `Answer` | Educational flashcard question-and-answer pairs | ✓ `schemas/education-qa.md` |
| Employer aggregate rating | `EmployerAggregateRating` | Employer / company review aggregates | ✓ `schemas/employer-rating.md` |
| EstimatedSalary | — | **REMOVED** from rich results June 2025. Do not use. | — removed |
| Event | `Event` | Concerts, webinars, in-person or virtual events | ✓ `schemas/event.md` |
| FAQ | `FAQPage` + `Question` + `Answer` | Rich result **DISCONTINUED** May 7, 2026 (all sites). Markup still aids AI extraction. | ✓ `schemas/faq-page.md` (AI signal only) |
| Fact check / ClaimReview | `ClaimReview` | **REMOVED** from rich results June 2025. Do not use. | — removed |
| How-to | `HowTo` + `HowToStep` | **REMOVED** from rich results September 2023. Do not use. | — removed |
| Image metadata | `ImageObject` | Standalone image pages or images with licence/credit | ✓ `schemas/image-metadata.md` |
| Job posting | `JobPosting` | Employment listings | ✓ `schemas/job-posting.md` |
| Learning video (rich result) | `VideoObject` + `Clip` | **REMOVED** as a distinct Learning Video rich result June 2025. Use `video.md` for standard video markup. | — removed (see `schemas/video.md`) |
| Local business | `LocalBusiness` (subtype) | Physical business locations | ✓ `schemas/local-business.md` |
| Logo | `Organization` with `logo` property | Site-wide organisation identity | ✓ `schemas/organization.md` |
| Math solver | `MathSolver` + `LearningResource` | Mathematical problem-solving tools | ✓ `schemas/math-solver.md` |
| Movie | `Movie` (in `ItemList`) | Film carousel / cinema list pages | ✓ `schemas/movie.md` |
| Practice problems | `Quiz` | **REMOVED** from rich results late 2025. Do not use. | — removed |
| Profile page | `ProfilePage` + `Person` / `Organization` | User and author profile pages | ✓ `schemas/profile-page.md` |
| Product | `Product` + `Offer` | E-commerce product pages | ✓ `schemas/product.md` |
| Product snippet | `Product` + `AggregateRating` | Products with star ratings | ✓ `schemas/product.md` |
| Q&A page | `QAPage` + `Question` + `Answer` | Community Q&A threads (single question, multiple answers) | ✓ `schemas/qapage.md` |
| Recipe | `Recipe` | Cooking / food content | ✓ `schemas/recipe.md` |
| Review snippet | `Review` or `AggregateRating` | Products, books, movies with user ratings | ✓ `schemas/review.md` |
| Sitelinks searchbox | _(removed — do not use)_ | — | — removed |
| Software app | `SoftwareApplication` | Mobile / desktop app pages | ✓ `schemas/software-app.md` |
| Speakable | `SpeakableSpecification` | Content designed for text-to-speech / voice assistants | ✓ `schemas/speakable.md` |
| Subscription / paywalled content | `CreativeWork` with `isAccessibleForFree` | Paywalled articles with free preview | ✓ `schemas/paywalled.md` |
| Vacation rental | `VacationRental` | Short-term accommodation listings on booking platforms | ✓ `schemas/vacation-rental.md` |
| VehicleListing | — | **REMOVED** from rich results June 2025. Do not use. | — removed |
| Video | `VideoObject` | Video content pages or embedded videos | ✓ `schemas/video.md` |
| WebSite | `WebSite` | Site name display in Google Search; no SearchAction (removed) | ✓ `schemas/website.md` |
| Web story (visual) | `WebPage` with AMP story format | Google Web Stories | pending |
