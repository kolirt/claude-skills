---
name: seo-audit
description: Use on demand to audit a project's SEO baseline — 'check/audit SEO', 'SEO review before deploy'. Reports missing baseline; does not auto-fix. Static code check only — NOT a deep-crawl/scoring/monitoring audit product.
---

# seo-audit — SEO baseline audit

A **lightweight, on-demand static sanity-check** that verifies the SEO baseline is closed across a project. Run it like a linter — manually and deliberately, NOT on every file change.

## What this skill does and does not do

**Does:** enumerate pages, check each item in `references/checklist.md`, classify severity, and produce a grouped report with the owning skill named for each finding.

**Does not:** auto-fix anything. Each finding names the owning skill; ask for that skill explicitly if you want a fix applied.

**Scope — lightweight static check only.** This skill is NOT a full audit product. The following are out of scope:
- Deep crawling or large-scale link analysis
- 0–100 scoring or benchmark comparisons
- Regression / drift tracking over time
- Competitor or keyword analysis
- Live monitoring of any kind

Those tasks belong to specialized SEO tooling (Screaming Frog, Ahrefs, Semrush, Lighthouse CI, etc.).

## Method

1. **Enumerate the project's routes/pages** — locate route definitions, page files, or any source of URL structure in the project (stack-neutral; the exact mechanism depends on the framework in use).
2. **Enumerate the project root** — check global assets and config files (robots.txt, sitemap.xml, favicon, security headers, HTTPS config).
3. **Enumerate content blocks** — identify content types present on each page and cross-reference them against the `structured-data` skill's recognition table (`references/recognition.md` in the `structured-data` skill) to determine which schemas are expected.
4. **Run `references/checklist.md`** — apply every item at the correct scope (Project / Page / Content / Technical).
5. **Classify severity** and produce a report.

## Severity levels

- **blocker** — prevents indexing or causes active ranking harm (e.g., `Disallow: /` left from a staging robots.txt on production).
- **major** — significant signal loss or user-facing quality issue (e.g., missing `<meta name="description">` on all pages).
- **minor** — low-impact gap or best-practice deviation (e.g., favicon missing — no indexing impact, minor brand signal).

## Report format

```
## SEO Audit Report

### Project-level
| # | Finding | Severity | Owning skill |
|---|---------|----------|--------------|
| 1 | robots.txt: Sitemap directive missing | major | robots |
| 2 | sitemap.xml not found | major | sitemaps |

### Page-level  [page: /about]
| # | Finding | Severity | Owning skill |
|---|---------|----------|--------------|
| 1 | <title> missing | blocker | meta-tags |
| 2 | og:image missing | major | social-preview |

### Content
| # | Finding | Severity | Owning skill |
|---|---------|----------|--------------|
| 1 | Article content found; no Article schema | major | structured-data |

### Technical
| # | Finding | Severity | Owning skill |
|---|---------|----------|--------------|
| 1 | Pagination URLs lack rel=next/prev or canonical | major | url-structure |

---
Summary: 1 blocker · 4 major · 2 minor
```

Each row names the owning skill. To fix a finding, invoke that skill by name.

## Tagging

Use `[type · provenance]` inline tags where useful (middot U+00B7 `·`; every tag carries provenance). Examples: `[invariant · desired]`, `[preference · desired]`.

## Live-data recommendation (closing note)

Always end the audit report with:

> **Recommendation:** for live data — indexing coverage, real-world Core Web Vitals, crawl errors — check Google Search Console, PageSpeed Insights, and CrUX. These require site registration and/or API keys and are outside the scope of a static code audit.

## Out-of-scope signals (never flag)

- Keyword strategy, content strategy, A/B test results
- Competitor gap analysis
- Social media performance
- Paid search / advertising

These are the domain of a human SEO specialist, not this skill.

## Related skills (by name)

meta-tags · social-preview · robots · sitemaps · structured-data · url-structure · canonicalization-and-redirects · javascript-seo · page-experience · media-seo · international · indexnow
