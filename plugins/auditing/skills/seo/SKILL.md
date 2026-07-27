---
name: seo
description: Use on demand to audit a project's SEO baseline — 'check/audit SEO', 'SEO review before deploy', 'SEO-аудит', 'перевір SEO'. Static code check across the WHOLE project — reports what is missing, never fixes it. NOT a deep-crawl/scoring/monitoring product, and not the Vue delivery layer (knowledge-vue:seo wires meta tags into a Vue app — this skill audits the baseline). Audits of a PR diff or a set of changes belong to the auditing-prs plugin. SEO policy lives in the knowledge-seo plugin; this skill uses it when present and runs on universal invariants and general practice when it is not.
---

# SEO audit

Judges whether a project's SEO baseline is closed: whether every page can be found, understood, and
indexed correctly, and whether the signals that should exist actually do.

The separating sentence: this domain owns **discoverability and indexing signals** — not whether an
`alt` attribute is present for accessibility (`auditing:accessibility`), not the delivery mechanism
that renders tags into a Vue app (`knowledge-vue:seo`), and not the raw page-speed cost behind a
ranking factor (`auditing:performance`).

## 0. Preflight — stack facts this domain needs

Read `../../core/stack-detection.md`. The snapshot is produced by the detection script it documents.
Under the dispatcher the **snapshot** arrives as an input: detection is not repeated, and this domain
does not disagree with the facts it was handed. Invoked directly, this domain runs the detection
script itself first.

| Fact needed | Used for | When absent |
|---|---|---|
| `ui` (a web-delivery surface) | Establishes there are pages to audit at all — a `server` surface alone does not: an API-only backend has no page for a crawler to fetch | `ui` absent in this unit: the whole domain is `skipped: not applicable` for that unit, whatever `server` says |
| `framework` (`vue-vite` or `nuxt`) | Whether JS-rendering sub-checks (SSR/SSG, crawlable routing) apply | Neither recorded: client-rendering sub-checks `skipped: not applicable`; delivery is assumed server-rendered or static |
| `i18n` | Whether an hreflang scaffold is expected at all | hreflang checklist item `skipped: not applicable` |
| `convention_plugins` | Whether `knowledge-seo` supplies knowledge tier 3 this run | Tiers 1 and 2 run; a coverage line names `knowledge-seo` as unavailable |
| `indexability` (public / internal / unreleased) | This domain's stake — how much a discoverability gap costs, which scopes severity, never applicability | A **domain input**, not a detected fact: under the dispatcher it is asked after this domain is selected and arrives as an input; invoked directly, ask it once here. An unanswered question is recorded as unknown, never assumed public |

**`knowledge-seo` is a soft dependency, not a precondition.** If it is available this session, it is
knowledge tier 3 — the source of SEO policy — and this skill defers to its skills by fully-qualified
name: `knowledge-seo:meta-tags`, `knowledge-seo:structured-data`, `knowledge-seo:robots`,
`knowledge-seo:sitemaps`, `knowledge-seo:social-preview`, and the rest listed under "Knowledge tiers"
below. If it is **not** available, the audit still runs, on tier 1 (universal invariants — a page
needs a title, a canonical, crawlable content, an indexable status) and tier 2 (general SEO practice
from the model's own knowledge). Name the missing tier in the coverage section rather than guessing at
policy or refusing to run. A degraded run is a **legitimate, complete outcome**; the coverage line is
what keeps it honest — it tells the reader exactly which checks rested on codified project convention
and which did not, instead of leaving that silently implied.

## 1. What this domain judges

### Project-level

Global assets and config: robots.txt (present, not closing production, pointing at the sitemap, an
explicit AI-crawler stance), sitemap.xml, home-page Organization/WebSite structured data, favicon,
a site-name title template, HTTPS/HSTS, baseline security headers, and an hreflang scaffold where the
project targets more than one language/region.

### Page-level

Per public page: unique `<title>`, unique meta description, self-referencing absolute canonical,
deliberate `<meta name="robots">` (private pages carry `noindex`), Open Graph and Twitter Card basics,
viewport meta, server-rendered content for indexable routes, and BreadcrumbList structured data on
pages more than one level deep.

### Content-level

Per content type found on a page: cross-reference against the recognition table owned by
`knowledge-seo:structured-data` (invoke that skill to obtain it) to determine which schema is
expected, then check it is present, valid, and mirrors the visible content. Image alt text and
descriptive filenames are checked here as an SEO signal — see the accessibility seam in section 3.

### Technical

Real HTTP status codes (no soft-404s), collapsed redirect chains, History-API routing with crawlable
`<a href>` links, faceted/pagination crawl safety, Core Web Vitals anti-patterns, hashed static
assets, and agent-friendly markup (meaningful HTML without requiring JS execution).

The full checklist, with each item's detail and remediating skill, is `references/checklist.md` —
run every item at its correct scope (Project / Page / Content / Technical).

## 2. Impact dimensions

Grade by SEO harm, never by code shape. The scale itself lives in `../../core/report-model.md`;
these are its meanings here:

- **blocker** (Indexing harm) — the page cannot be indexed, or is actively excluded (e.g. a staging
  `Disallow: /` left on production).
- **major** (Crawl harm / Signal loss) — crawlers waste budget or cannot traverse the site; or a
  positive signal that should exist site-wide is simply absent (e.g. missing meta descriptions).
- **minor** (Signal loss, low impact) — a small gap with no material harm (e.g. a missing favicon).
- Ranking harm (a signal actively working against the page) is graded blocker or major by how much of
  the page's discoverability it undermines.

## 3. What this domain does NOT cover

- **The Vue delivery layer** — `knowledge-vue:seo` owns wiring meta tags, Open Graph properties, and
  JSON-LD into a Vue page via `@unhead/vue`. This domain audits whether the baseline is closed, not
  how it is implemented in framework code.
- **Accessibility** — `auditing:accessibility` owns the `alt` attribute as an accessibility
  obligation; this domain owns it as an SEO signal. The two domains check the same attribute for
  different reasons but **do not double-report** it — one finding, filed by whichever domain runs,
  is enough; if both run in the same pass, the finding is filed once under the domain that owns the
  matching audit context (accessibility for a missing-alt defect, SEO for a signal-loss reading).
- **Performance** — Core Web Vitals as a ranking concern belong here, with policy from
  `knowledge-seo:page-experience`; the underlying page-speed cost that produces the metric is
  `auditing:performance`'s to fix. This domain flags the ranking exposure; it does not audit the
  render pipeline.
- **Deep crawling, scoring, and monitoring** — no large-scale link analysis, no 0–100 scoring or
  benchmark comparison, no regression/drift tracking, no competitor or keyword analysis, no live
  monitoring. Those belong to specialized SEO tooling (Screaming Frog, Ahrefs, Semrush, Lighthouse
  CI, and so on).
- **Live data** — indexing coverage, real-world Core Web Vitals, and crawl errors require Google
  Search Console, PageSpeed Insights, and CrUX; a static code audit cannot see them.
- **Out-of-scope signals, never flagged** — keyword/content strategy, A/B test results, competitor
  gap analysis, social media performance, paid search or advertising. These are the domain of a
  human SEO specialist, not this skill.

## 4. How to audit

1. Enumerate the project's routes/pages — locate route definitions, page files, or any source of URL
   structure. Stack-neutral: the mechanism depends on the detected framework.
2. Enumerate the project root — global assets and config: robots.txt, sitemap.xml, favicon, security
   headers, HTTPS config.
3. Enumerate content blocks per page and cross-reference against the `knowledge-seo:structured-data`
   recognition table to determine expected schemas.
4. Run `references/checklist.md` at its correct scope (Project / Page / Content / Technical).
5. For any item whose rule must be stated precisely, invoke the owning `knowledge-seo` skill when
   available rather than reciting the rule from memory; when it is not available, apply tier 1 and
   tier 2 knowledge and say so in coverage.

**Establishing absence.** A missing sitemap, canonical, or schema block has no `file:line`; use the
`expected surface absent` locator from `../../core/report-model.md` — state where it was expected and
how its absence elsewhere was ruled out (a layout-level default, a plugin, a build step).

## 5. Knowledge tiers

- **Tier 1 — universal invariants.** A page needs a title, a canonical URL, crawlable content, and an
  intentional indexable status. Always applied.
- **Tier 2 — ecosystem general practice.** General SEO practice for the detected stack, from the
  model's own knowledge: meta completeness, structured-data hygiene, redirect and status-code
  correctness, crawlability of client-rendered routes. Always applied.
- **Tier 3 — codified project conventions.** From `knowledge-seo`, when available this session:
  `knowledge-seo:meta-tags`, `knowledge-seo:structured-data`, `knowledge-seo:social-preview`,
  `knowledge-seo:robots`, `knowledge-seo:sitemaps`, `knowledge-seo:canonicalization-and-redirects`,
  `knowledge-seo:page-experience`, `knowledge-seo:international`, `knowledge-seo:media-seo`,
  `knowledge-seo:javascript-seo`, `knowledge-seo:indexnow`, `knowledge-seo:url-structure`,
  `knowledge-seo:generative-seo`. The dependency is **soft**: absent means tiers 1 and 2 run normally
  and a coverage line records `tier 3 unavailable — knowledge-seo not present in this session`. That
  line is a coverage fact, not a finding. Always fully qualified — a bare `robots` is ambiguous
  across plugins — and always invoked by skill name, never by file path.

## 6. Report

Read `../../core/report-model.md` and follow it exactly — output location, finding fields, evidence
locators, severity and confidence, opportunities, run comparison, and the mandatory coverage section.
Nothing from it is restated here.

- **Finding-id prefix: `SEO`** — `SEO-1`, `SEO-2`, … stable within the report.
- **Remediating skill.** Fill each finding's `remediating skill` with the fully-qualified
  `knowledge-seo:<skill>` named in `references/checklist.md` when tier 3 was available; a value may
  name more than one skill. When tier 3 was unavailable, leave the field naming the same skill by
  name anyway (it is still the eventual fix owner) and let the coverage section carry the caveat that
  the rule was applied from tier 1/2 knowledge, not tier 3.
- Close with the recommendation to check Google Search Console, PageSpeed Insights, and CrUX for live
  data, per section 3.
- The bridge to fixing is **`auditing:remediate`**, which reads a report out of a run directory and
  produces a plan under `docs/plans/`. This audit names findings and stops — it changes nothing
  itself.
