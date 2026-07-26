---
name: performance
description: Use on demand to audit whether a WHOLE application does work it does not need to do — 'performance audit', 'аудит продуктивності', 'why is this slow', 'check for N+1 queries', 'review bundle size', 'will this scale with more data'. Static read of the code: reports known-slow patterns, missing pagination, over-fetching, absent batching, and client-side cost that grows with total data. Read-only — reports findings, never fixes them, and never profiles, benchmarks, or runs the application. Not a failure-under-load review (that is auditing:reliability), not a schema or index review (that is auditing:data), and not Core Web Vitals as an SEO ranking factor (that is auditing:seo). Audits of a PR diff or a set of changes belong to the auditing-prs plugin.
---

# Performance audit

Judges whether the application **does work it does not need to do**: work repeated per item that
could be done once, data fetched that is never used, cost that grows with the size of the dataset
rather than with the size of the request.

The separating sentence: this domain owns **the cost of the work** — not whether the system survives
that cost (`auditing:reliability`) and not whether the schema is shaped to support it
(`auditing:data`).

## 0. Preflight — stack facts this domain needs

Read `../../core/stack-detection.md`. Under the dispatcher the **snapshot** arrives as an input:
detection is not repeated, and this domain does not disagree with the facts it was handed. Invoked
directly, this domain runs the script itself first.

| Fact needed | Used for | When absent |
|---|---|---|
| `data_schema` or `server` | Reading query shape: per-item queries, eager loading, result-set bounds, hot paths, and synchronous blocking calls | Data-access and server-side sub-checks are `skipped: not applicable`; the domain still audits client cost where `ui` is present |
| `ui` | Bundle shape, render cost, list rendering, route splitting — the client-side cost sub-checks | Client-side sub-checks `skipped: not applicable` |
| `api_contract` | Whether a batch form of an endpoint exists next to the per-item form | Batch availability is read from the client and server code instead; coverage says so |
| `convention_plugins` | Whether knowledge tier 3 exists this run | Tiers 1 and 2 run; a coverage line names the missing tier |

Neither `data_schema`/`server` nor `ui` present in a unit means there is no cost surface at all: the
whole domain is `skipped: not applicable` there, wholesale rather than per sub-check. Every skip is
recorded in the coverage section **with the fact that was missing**. A stack this domain does not run
on produces no findings — never invented ones, and never a guess at what a finding would have looked
like.

## 1. What this domain judges

### Known-slow patterns

These are defects **on sight**. No measurement is needed to call them, because the cost is a
property of the shape, not of the data volume that happens to be present today.

- **A query per item over a result set** — a loop, a map, or a lazy relation access issuing one
  request per row where one request could serve the whole set.
- **An unbounded result set** — a fetch with no limit, no pagination, and no upper bound derived from
  anything other than "how much exists".
- **Work repeated per item that could be done once** — a lookup, a compile, a parse, a client
  construction, a permission resolution, or a configuration read performed inside the loop.
- **A cost that grows with total data rather than with the page** — a count, an aggregate, a sort, or
  a filter applied to everything in order to return a page of it.
- **A synchronous blocking call on a hot path** — a network call, a filesystem read, or a heavy
  computation performed inline in a request handler or a render path.

### Data access shape

- **Missing pagination** on any listing surface, and pagination present in the UI while the query
  underneath still reads everything.
- **Over-fetching**: selecting whole records, or eagerly loading whole relation trees, to use one
  field; returning fields the caller demonstrably never reads.
- **Repeated identical requests within one operation** — the same row, the same lookup, or the same
  endpoint hit more than once while serving a single request or rendering a single view.
- **Absent caching where the same expensive answer is recomputed per request.** Note the boundary
  carefully: the *recomputation* is what gets reported, and **adding a cache is a recommendation
  requiring measurement, not a finding**. It goes in the opportunities section, names the measurement
  that would justify it, and carries no severity — a cache introduces invalidation cost that a static
  read cannot weigh.
- Filtering, sorting, or de-duplicating in application code over data the store could have narrowed.

### Client-side cost

- **Bundle shape** — everything imported eagerly where the framework's documented approach is a route
  or component split; a heavy library pulled in whole for one helper; a rarely used surface loaded on
  first paint.
- **Render work proportional to total data** — a computation over the entire collection re-run on
  every render, work done in the render path that does not depend on what changed, a derived value
  recomputed rather than memoised where the framework documents memoisation.
- **Unbounded lists** — every row of an arbitrarily large collection materialised into the DOM with
  no pagination, windowing, or incremental reveal.
- **Media served at many times its displayed size** — a full-resolution asset rendered into a
  thumbnail, no responsive variants, no dimensions reserved.
- **Blocking resources on the critical path** — synchronous scripts, render-blocking stylesheets, or
  fonts loaded such that first paint waits on them.

### Concurrency and waiting

- **Sequential awaits with no dependency between them** — independent calls made one after another
  where they could be issued together, including inside a loop that awaits each iteration.
- **A per-item round trip where the API offers a batch form** — one call per id when a
  multiple-id endpoint, a bulk write, or a single upsert exists.
- Work performed inline that the request's response does not depend on.

## 2. Impact dimensions

Severity is graded by **user-visible or resource impact, never by code shape**. The scale itself
lives in `../../core/report-model.md`; these are its meanings here.

- **blocker** — the path is unusable at realistic data volume, or its cost grows without bound: a
  page that cannot finish loading once the table is large, a job that gets slower every day, a query
  count that rises with the dataset.
- **major** — a substantial, user-visible slowdown at realistic volume, on a path users actually
  take.
- **minor** — measurable waste with no user-visible effect yet: real unnecessary work, bounded, on a
  cold path or at a volume that keeps it invisible.

Two output channels, and they never blur:

- **Known-slow patterns are reported as findings**, with severity, because their cost follows from
  the shape.
- **Any other optimisation is an opportunity**, carrying no severity, and it **names the measurement
  it would need** to become a finding — which path, under what data volume, measured how.

An elegant refactor with no cost consequence is neither.

## 3. What this domain does NOT cover

- **Schema facts about indexes.** `auditing:data` owns whether an index exists and whether it backs a
  real filter — that is a property of the schema, read from migrations or the schema definition. This
  domain owns **the query pattern that needs one**: a filter, sort, or join whose cost grows with
  total rows. The seam runs both ways, so neither file is read alone: a finding that a declared index
  is unused or duplicated is `DATA`; a finding that a listing query scans everything is `PERF`, and
  it names the missing support without asserting what the schema should declare. Where both apply,
  each domain files its own side rather than one absorbing the other.
- **Behaviour under load and failure.** `auditing:reliability` owns timeouts, retries, backoff,
  circuit breaking, queue depth, rate limiting as a capacity control, and what happens when a
  dependency is slow or down. This domain owns the cost of a **successful** operation; the moment the
  question becomes "and what happens when it does not finish", it is `REL`.
- **Core Web Vitals as a ranking concern.** Page experience as an SEO signal belongs to
  `auditing:seo`, and the policy behind it lives in `knowledge-seo:page-experience`. This domain
  owns the **underlying cost** — the oversized asset, the blocking resource, the render work — and
  states it in cost terms. It does not grade against a vitals threshold, does not report a metric
  target, and does not claim a ranking effect; a finding phrased as "this hurts LCP for search"
  belongs to `auditing:seo`, while "this image is served at ten times its displayed size" is `PERF`.
- **Correctness and code shape.** `auditing:code-quality` owns duplication, complexity, and
  structure. A tangle that costs nothing is not a finding here.

## 4. How to audit

Static reading only. **No profiling, no benchmarks, nothing is run** — no load is generated, no
timer is read, no query plan is executed, no application is started. That limit is stated in the
coverage section, not left implicit.

A claim that something is slow therefore **rests on the pattern, not on a number this audit does not
have**. Findings describe shape and growth ("one query per row, so the query count rises with the
result set"), never fabricated timings, percentages, or "roughly N times faster". No number appears
in a finding unless it was read directly out of the code or configuration.

Order of work:

1. Establish the hot paths first: entry points, request handlers, the routes and views a user
   actually reaches, and anything on the first-paint path.
2. For each hot path, follow the data: what is fetched, how much of it, how many round trips, and
   what the response does with what it received.
3. Read the loops. Every iteration is a candidate for a per-item query, a repeated lookup, or a
   sequential await.
4. Read the client entry and the largest surfaces last: import graph, list rendering, media.

**Establishing absence.** Missing pagination, an absent batch call, or an unset bound has no
`file:line` of its own; use the `expected surface absent` locator from
`../../core/report-model.md`, state where the bound was expected, and state how you established it
is not applied elsewhere — a default page size in a base class, a store-level limit, or a gateway
constraint all count as elsewhere.

**Findings versus notes.** A finding names the pattern, the surface, and how the cost grows with
what. If the growth cannot be stated, it is an opportunity with its measurement named. Confidence is
`medium` where the pattern is clear in code but the realistic data volume was never confirmed, and
`low` where the path's reachability itself is inferred — the volume assumption goes in `assumptions`
explicitly rather than being smuggled in as certainty.

## 5. Knowledge tiers

- **Tier 1 — universal invariants.** The known-slow patterns and the shape questions in section 1:
  no work per item that can be done once, no unbounded result set, no cost that scales with total
  data to serve one page, no blocking call on a hot path, no sequential wait without a dependency.
  Always applied.
- **Tier 2 — ecosystem general practice.** The detected framework's own **documented performance
  guidance** — its eager-loading and query-batching facilities, its pagination primitives, its
  code-splitting and lazy-loading mechanism, its caching layers, its memoisation and list-key
  conventions, its documented rendering costs. A framework facility that exists and is bypassed by
  hand-rolled per-item work is a tier-2 finding.
- **Tier 3 — codified project conventions.** From `knowledge-principles:performance`, and for a Vue
  project additionally from the `knowledge-vue` conventions (its data-fetching, caching, and
  component skills). **Both are soft**: absent means tiers 1 and 2 run normally and a coverage line
  records each missing tier by name. Such a line is a coverage fact, not a finding.

## 6. Report

Read `../../core/report-model.md` and follow it exactly — output location, finding fields, evidence
locators, severity and confidence, opportunities, run comparison, and the mandatory coverage
section. Nothing from it is restated here.

- **Finding-id prefix: `PERF`** — `PERF-1`, `PERF-2`, … stable within the report.
- **Remediating skill.** Name the fully-qualified skill that owns the fix when one exists, and leave
  the field empty when none does. Data-fetching and caching fixes in a Vue project typically name
  `knowledge-vue:tanstack-query` or `knowledge-vue:http-request`; render and component-split fixes
  name `knowledge-vue:components`. Never a bare name — always fully qualified.
- The bridge to fixing is `auditing:remediate`. This audit names findings and stops.
