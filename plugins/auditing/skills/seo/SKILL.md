---
name: seo
description: Use on demand to audit a project's SEO baseline — 'check/audit SEO', 'SEO review before deploy', 'SEO-аудит', 'перевір SEO'. Static code check across the WHOLE project: reports what is missing, never fixes it. NOT a deep-crawl/scoring/monitoring product, and not the Vue delivery layer (knowledge-vue:seo wires meta tags into a Vue app — this skill audits the baseline). Audits of a PR diff or a set of changes belong to the auditing-prs plugin. REQUIRES the knowledge-seo plugin, which owns all SEO policy knowledge.
---

# seo — SEO baseline audit

A **lightweight, on-demand static sanity-check** that verifies the SEO baseline is closed across a
project. Run it like a linter — manually and deliberately, NOT on every file change.

This skill owns the audit **process**. It owns no SEO policy: every rule, threshold and convention
lives in the `knowledge-seo` plugin and is reached by invoking those skills by name.

## 0. Preflight — knowledge-seo is required (do this FIRST)

Before inspecting a single file, confirm the `knowledge-seo` skills are available in this session —
`knowledge-seo:meta-tags`, `knowledge-seo:robots` and the rest listed under "Policy skills" below.

If they are not available, do **not** audit anything, not even partially. Report exactly this and
stop:

> This audit requires the `knowledge-seo` plugin, which owns all SEO policy knowledge. Without it
> the audit would only guess at the rules. Install it and re-run:
>
> ```
> /plugin install knowledge-seo@claude-skills
> ```

A partial audit run without the policy source is worse than no audit: it produces findings the user
will trust and that were never checked against the real baseline.

## What this skill does and does not do

**Does:** enumerate pages, check each item in `references/checklist.md`, grade by SEO impact, and
produce a report naming the remediating skill for each finding.

**Does not:** auto-fix anything, and does not mutate the repository in any way — see
`../../core/report-model.md`. Each finding names its remediating skill; the user invokes that skill
if they want the fix applied.

**Scope — lightweight static check only.** This skill is NOT a full audit product. Out of scope:

- Deep crawling or large-scale link analysis
- 0–100 scoring or benchmark comparisons
- Regression / drift tracking over time
- Competitor or keyword analysis
- Live monitoring of any kind

Those belong to specialized SEO tooling (Screaming Frog, Ahrefs, Semrush, Lighthouse CI, and so on).

## Impact dimensions (how severity is graded here)

Grade by SEO harm, never by code shape:

- **Indexing harm** — the page cannot be indexed, or is actively excluded.
- **Crawl harm** — crawlers waste budget or cannot traverse the site.
- **Ranking harm** — a signal actively works against the page.
- **Signal loss** — a positive signal that should exist is simply absent.

Map onto the shared `blocker | major | minor` scale in the report model: a staging `Disallow: /`
left on production is a blocker (indexing harm); missing meta descriptions site-wide are major
(signal loss); a missing favicon is minor.

## Method

1. **Enumerate the project's routes/pages** — locate route definitions, page files, or any source of
   URL structure. Stack-neutral: the mechanism depends on the framework in use.
2. **Enumerate the project root** — global assets and config: robots.txt, sitemap.xml, favicon,
   security headers, HTTPS config.
3. **Enumerate content blocks** — identify the content types present on each page and cross-reference
   them against the recognition table owned by `knowledge-seo:structured-data` (invoke that skill to
   obtain it) to determine which schemas are expected.
4. **Run `references/checklist.md`** — apply every item at its correct scope (Project / Page /
   Content / Technical).
5. **Report** per `../../core/report-model.md`.

For any item whose rule you need to state precisely, invoke the owning policy skill rather than
recalling the rule from memory — that is what the hard dependency is for.

## Policy skills (invoke by fully-qualified name)

`knowledge-seo:meta-tags` · `knowledge-seo:structured-data` · `knowledge-seo:social-preview` ·
`knowledge-seo:robots` · `knowledge-seo:sitemaps` · `knowledge-seo:canonicalization-and-redirects` ·
`knowledge-seo:page-experience` · `knowledge-seo:international` · `knowledge-seo:media-seo` ·
`knowledge-seo:javascript-seo` · `knowledge-seo:indexnow` · `knowledge-seo:url-structure` ·
`knowledge-seo:generative-seo`

Always fully qualified — a bare `robots` or `seo` is ambiguous across plugins. Always by skill name,
never by file path: cross-plugin paths break the moment a plugin is relocated or versioned.

## Report

Follow `../../core/report-model.md` for the scope declaration, finding fields, severity, confidence,
opportunities and the mandatory coverage section. Group findings by scope (Project-level /
Page-level / Content / Technical) and fill each finding's `remediating skill` with the
fully-qualified `knowledge-seo:<skill>` from the checklist — a value may name more than one skill.

Findings that are absences (no sitemap, no canonical) use the `expected surface absent` evidence
locator; there is no line to cite for something that does not exist.

Close the report with the coverage section and this recommendation:

> **Recommendation:** for live data — indexing coverage, real-world Core Web Vitals, crawl errors —
> check Google Search Console, PageSpeed Insights and CrUX. These require site registration and/or
> API keys and are outside the scope of a static code audit.

## Out-of-scope signals (never flag)

- Keyword strategy, content strategy, A/B test results
- Competitor gap analysis
- Social media performance
- Paid search / advertising

These are the domain of a human SEO specialist, not this skill.
