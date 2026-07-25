# Stack detection (shared preflight)

Every skill in the `auditing` plugin runs this preflight, or receives its result from the
dispatcher, before it says what is wrong with a project. An audit must know what it is auditing
before it can judge it. Detection is evidence-based: a fact is recorded only when its marker is
actually present in the repository — never inferred from a project's name, a README claim, or
what would be typical for a project of this kind.

## Marker table

Reproduced verbatim. A domain skill cites this table by reference; it does not restate it.

| Fact | Markers |
|---|---|
| Vue (Vite) | `vite.config.*` + `vue` in `package.json` |
| Nuxt | `nuxt.config.*` |
| React | `react` in `package.json` |
| Laravel | `artisan` + `composer.json` with `laravel/framework` |
| WordPress | `wp-config.php` or `wp-content/` |
| FSD architecture | numbered layer dirs under `src/` (`01-app`, `02-…`) |
| Data layer — Laravel | `database/migrations/*.php` + `app/Models/` |
| Data layer — Prisma | `prisma/schema.prisma` |
| Data layer — Drizzle | `drizzle.config.*` + a `schema.ts` |
| Data layer — raw SQL | `*.sql` under a `migrations/` dir |
| API schema | `openapi.*`, `swagger.*`, or a generated client dir |
| i18n | `vue-i18n`/`next-intl` in `package.json`, or `lang/`/`locales/` |
| Test harness | a test runner in `package.json` scripts or `composer.json` |
| Convention plugins | which `knowledge-*` skills are available this session |

A fact not backed by one of its markers is not recorded. Partial evidence (the marker exists but
in a form not listed) is absence, not a weaker version of presence.

## The snapshot

Detection produces a **snapshot**: a named set of facts from the table above, each resolved to one
of two states —

- **present**, with the marker that was actually found cited (e.g. `vite.config.ts` +
  `"vue": "^3.4.0"` in `package.json`), or
- **absent** — the marker was looked for and not found.

There is no third state. A fact that was never checked is not part of the snapshot; every fact the
table defines is either checked-and-present or checked-and-absent.

The **dispatcher detects once** and passes the snapshot down to every domain subagent it invokes —
domains do not re-run detection under the dispatcher, and do not disagree with the snapshot they
were handed. A **domain invoked directly** (not through the dispatcher) runs detection itself
before producing findings.

The snapshot is stated in the report. A reader must be able to tell, without reading the code
themselves, what the audit believed about the project — which facts were found, on what evidence,
and which were checked and came back absent.

## Per-domain declaration

Every audit skill declares, in its own body, which stack facts from the table it requires and what
it does when a required fact is absent. This declaration is not optional and not implicit — it is
written out in the skill.

When a required fact is absent, the domain's behavior is fixed: `skipped: not applicable`,
recorded in the coverage section together with the reason (which fact was missing). The domain
does not invent findings for a stack it does not run on, and does not guess at what a finding would
have looked like had the fact been present.

`skipped: not applicable` is a legitimate, complete outcome for a domain — not a failure of the
audit and not something to pad with speculative content. A security audit that finds no Laravel
data layer to check says so and stops that sub-check there.

## Monorepos

Detection runs **per package**, not once for the whole repository. A **unit** is recognized by its
own manifest — a `package.json` or `composer.json` — found under a subdirectory; each such manifest
marks the boundary of one unit with its own snapshot.

The snapshot therefore carries a **list** of detected units, each with its own set of resolved
facts, never a single scalar snapshot for the repository as a whole.

Every finding names which unit it belongs to. A domain may be applicable in one unit (its required
fact is present there) and not applicable in another (the fact is absent there) within the same
run. The coverage section records this per unit — `skipped: not applicable` for the units where the
fact was absent, findings and inspected scope for the units where it was present.

## Two runtimes present at once

A repository can hold two runtimes simultaneously — for example a backend framework (Laravel) and a
separate frontend application (Vue) in the same tree, neither one a subdirectory unit of the other.
Detection records both as present. Neither is treated as the "real" one and neither is discarded in
favor of the other.

Each domain decides for itself which of the two it audits: a domain may apply to one runtime, to
both, or to neither, and states which in its coverage section. A security domain, for instance, may
audit both; an i18n domain may find its markers only on the frontend side and mark the backend
`skipped: not applicable` for that domain.

## Convention plugins are a detected fact too

Which `knowledge-*` skills are available this session is itself a row in the marker table, detected
the same way as any stack fact: checked, and recorded present or absent. Its presence or absence
determines whether knowledge tier 3 exists for a given domain in this run.

Detecting the absence of a convention plugin is what makes the soft dependency between an audit
domain and its matching `knowledge-*` plugin work: when tier 3 is absent, the domain still runs on
tiers 1 and 2 and records the missing tier — it does not abort and does not treat the missing
plugin as a reason to skip the domain outright. For what tiers 1–3 mean, read
`../../core/report-model.md`.

## Anti-patterns

- Inferring a stack fact from a project's name, a README claim, or a directory name that merely
  suggests a framework — a fact requires its marker, not a suggestion of one.
- Treating one detected marker as proof of a whole architecture (e.g. one numbered directory as
  proof of full FSD compliance across the tree).
- Auditing a framework the repository does not contain because the domain "usually" applies to
  projects like this one.
- Reporting a fact as present without citing the marker that was found for it.
