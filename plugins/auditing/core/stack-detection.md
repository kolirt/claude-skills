# Stack detection (shared preflight)

Every skill in the `auditing` plugin runs this preflight, or receives its result from the
dispatcher, before it says what is wrong with a project. An audit must know what it is auditing
before it can judge it.

Detection answers exactly four questions, and nothing beyond them:

1. **Applicability.** A domain must not report on a surface the project does not have, and must be
   able to say `not applicable` with evidence instead of going quiet.
2. **Selection.** The dispatcher's domain table needs a reason per domain before the user spends a
   run on it.
3. **Units.** In a monorepo a finding has to name which package it belongs to.
4. **Convention tier.** Which codified conventions apply at all — knowledge tier 3.

## Detection is by SURFACE, not by framework catalogue

The audit domains branch on what a project *has*, not on which framework built it: an interface, a
server, a data schema, an API contract. `security` needs a request-handling surface; `data` needs a
schema; `accessibility` needs an interface. None of them needs to know which UI library rendered it.

Framework identity is recorded only where it selects a convention tier — how a thing is normally
done there (tier 2) and which `knowledge-*` plugin codifies it (tier 3). That is a short list, and it
is short on purpose: a catalogue of frameworks nobody in this marketplace works with would be
machinery that decides nothing.

## The script is the authority

Facts are produced by code, not by an agent reading directories:

```
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/detect-stack.py"
```

Run it from the audited repository's own working directory — never `cd` into the plugin. It walks the
tree once, skips vendored and build directories, and writes the snapshot to stdout as JSON. It is
read-only and it never fails on an empty result: a project where every surface is absent is a valid
snapshot, not an error.

Why code and not an agent: the same repository must produce the same snapshot every run, every fact
must carry the marker that proved it, and enumerating directories is not worth a single token of an
audit's context. The script also refuses to guess — a fact with no marker is absent, full stop.

What the JSON carries, per unit: `path`, `manifests`, `framework` (a list — a unit may be both a
server and a client), `architecture`, and `surfaces`, where every surface is
`{"present": bool, "marker": "<what was found>"}`.

**Fallback.** If `python3` is unavailable, establish the same facts by hand, mark the snapshot
`hand-detected` in the report, and say so in the coverage section. A missing interpreter degrades the
preflight; it never aborts the audit. This is the same soft-dependency discipline the whole plugin
follows.

## What the script checks

Documentation of the script's behaviour — the script is the authority, and this table is kept in step
with it. A domain skill cites this by reference and does not restate it.

**The manifest comes first.** `package.json` and `composer.json` are the primary evidence: a declared
dependency is a stated fact about the project, not an inference from directory shape. A file is probed
only where a manifest **cannot** answer — see "Why manifests are not enough" below. That is why no
config file (`vite.config.*`, `nuxt.config.*`, `artisan`) is a marker here, not even as a fallback: it
adds nothing a declared dependency has not already proved.

Three rules govern how manifests are read:

- **A unit's own root manifest only.** Dependency facts come from the manifest at the unit's own root.
  A parent never inherits a nested package's dependencies, and a nested package never inherits its
  parent's.
- **Runtime dependencies decide identity.** A runtime dependency says the project *is* the thing;
  anything else says it merely *works with* it. A package declaring `laravel/framework` under
  `require-dev` to run its own tests is not a Laravel application and has no `server` surface, and a
  component library declaring `vue` as a **peer** dependency is not a Vue application — it is
  something used inside one. The npm runtime/dev split does not carry the PHP meaning — `nuxt` is
  conventionally a devDependency of the app it builds — so the runtime keys are `dependencies` and
  `devDependencies` for JavaScript and `require` for PHP; `peerDependencies` and `require-dev` are
  not runtime keys. `test_harness` is the single deliberate exception, because a test runner is
  legitimately development-only: that one surface reads every declared key. Every other
  dependency-backed fact, `i18n` included, reads runtime keys only.
  The cost of this rule is worth naming: a component library that declares its framework as a peer
  dependency records no framework identity, so tier 3 is empty for it and `accessibility` finds no
  `ui` surface. Its structure is still audited by `auditing:code-quality`, which needs only a
  manifest.
- **A malformed manifest is no manifest.** Unparsable JSON degrades to "no declared dependencies" and
  the walk continues; it never aborts detection.

**The recognised stack is deliberately narrow.** Framework identity covers `vue-vite`, `nuxt` and
`laravel` because those are the stacks whose conventions this marketplace codifies — they are what
selects a knowledge tier. A project outside that set is not misreported: its surfaces are still found
by the generic probes (`index.html`, a `migrations/` directory, an OpenAPI document, a `server/` entry
point), and it simply records no framework identity, which means tier 3 is empty and coverage says so.
Adding a framework here is a deliberate edit to the script, not something an audit infers at run time.

### Surfaces

| Surface | Present when | Answers for |
|---|---|---|
| `ui` | `vue` or `nuxt` in `package.json`; failing that a `*.blade.php` template, or an `index.html` at the unit root | `accessibility`, `seo`, client-side `performance` |
| `server` | `laravel/framework` in `composer.json`, or `nuxt` in `package.json` (server-capable runtime); failing that a `routes/*.php` or a `server/` entry point | `security`, `reliability`, `api-contracts`, server-side `performance`, and `business-analysis` as a product surface |
| `data_schema` | `database/migrations/*.php` (plus `app/Models/` when present), or a `*.sql` file under a `migrations/` directory | `data`, index-related `performance` |
| `api_contract` | an `openapi*.{json,yaml,yml}` or `swagger*.{json,yaml,yml}` file | `api-contracts` full mode |
| `i18n` | `vue-i18n` or `@nuxtjs/i18n` in `package.json`; failing that a `lang/` or `locales/` directory | the hreflang checks in `seo` |
| `test_harness` | a known runner declared in either manifest under any dependency key, or a script whose name starts with `test` (`test`, `test:unit`, `test:integration`) in either manifest | dead-code confidence in `code-quality` |

The runner list and the surface probes are enumerated in the script itself, which is the authority; a
project that keeps a schema, an OpenAPI document or a server entry point somewhere the probes do not
look is a reason to change the script, never to record a fact by hand and call it detected.

### Framework identity and architecture

| Fact | Recorded when | Used for |
|---|---|---|
| `vue-vite` | `vue` in `package.json` (with `vite` cited alongside it when declared) | tier 2 idiom; tier 3 via `knowledge-vue` |
| `nuxt` | `nuxt` in `package.json` | tier 2 idiom; tier 3 via `knowledge-vue` |
| `laravel` | `laravel/framework` in `composer.json` | tier 2 idiom; tier 3 is empty until a Laravel convention plugin exists |
| `architecture` | `fsd` when `src/` holds numbered layer directories (`01-app`, `02-…`); `flat` when `src/` exists without them | `code-quality` and `knowledge-vue:architecture` |

### Why manifests are not enough

Four facts are invisible to a manifest, and they are the ones the domains gate on hardest:

- **`data_schema`** — `laravel/framework` is declared by every Laravel project including a package
  that has no schema at all. The fact is `database/migrations/*.php`, not a dependency. The whole
  `data` domain rests on it.
- **`api_contract`** — an OpenAPI document is a file, never a dependency. `api-contracts` switches
  mode on it.
- **`architecture`** — `fsd` versus `flat` is directory shape; no manifest field expresses it.
- **`ui` for a server-rendered app** — Blade ships inside `laravel/framework` with no dependency of
  its own. Read from the manifest alone, such a project looks interface-less, and `accessibility` and
  `seo` would wrongly go `not applicable`.

`i18n` is the partial case: a JavaScript i18n package is declared, a framework's own `lang/` directory
is not.

A unit may record more than one framework — a repository that serves its own frontend is both. No
framework is treated as the "real" one, none is discarded in favour of another, and each domain
states in its coverage which of them it audited.

Partial evidence is absence, not a weaker presence: a marker that exists in a form the script does
not recognise leaves the fact absent, and if that is wrong for a project, the fix is a change to the
script, not a guess in a report.

Path markers are matched on whole path **components**, never as substrings — `not_migrations/x.sql`
and `database/migrations_backup/x.php` are not schemas. Where several files could serve as one
surface's marker, the cited one is chosen in sorted order, so the same tree yields the same snapshot
on every run and every filesystem.

### The two facts the script cannot produce

- **`convention_plugins`** — which `knowledge-*` skills are available this session. That is session
  state, not a file on disk, so the agent adds it to the snapshot itself. Its presence decides
  whether knowledge tier 3 exists for a domain; for what tiers 1–3 mean, read `report-model.md`.
- **`indexability`** — whether the project is public, internal, or unreleased. That is intent, not
  evidence; the dispatcher asks, and an unanswered question is recorded as unknown rather than
  assumed.

A **domain input** like `indexability` is asked only when the domain that needs it is actually going to
run — under the dispatcher, after the domain selection, never in preflight. No verdict depends on such
an answer, precisely so that the question can wait until it is known to be worth asking: a domain input
scopes an audit's severity or evidence, it never decides applicability. A domain invoked directly asks
for its own input itself, or records it as unknown.

## The snapshot

The snapshot is the script's output plus those two agent-supplied facts.

Every **detected** fact is either present with a cited marker or absent; there is no third state and
nothing detected is left unchecked. The two **agent-supplied** facts are different by nature and may
be `unknown`: `convention_plugins` is enumerated from the session, and `indexability` rests on an
answer the user may not give. `unknown` is recorded as `unknown` and carried into coverage — it is
never silently resolved to the convenient value, and in particular an unanswered `indexability` is
never read as public.

The **dispatcher detects once** and passes the snapshot to every domain subagent. Domains do not
re-run detection under the dispatcher and do not disagree with the snapshot they were handed. A
**domain invoked directly** runs the script itself first.

The snapshot is stated in the report. A reader must be able to tell, without reading the code
themselves, what the audit believed about the project: which facts were found, on what evidence, and
which came back absent.

## Per-domain declaration

Every audit skill declares in its own body which surfaces it requires and what it does when one is
absent. The declaration is written out, not implied.

When a required surface is absent, the behaviour is fixed: `skipped: not applicable`, recorded in the
coverage section with the missing surface named. The domain invents no findings for a surface that is
not there and does not speculate about what it would have found.

`skipped: not applicable` is a legitimate, complete outcome — not a failure and not something to pad.
Two domains deliberately reduce their scope instead of skipping, and say so themselves: `data` drops
to API-boundary integrity when there is no schema, and `api-contracts` has three modes — full
contract checking with a contract document and an implementation, client-internal consistency with
an implementation and no document, and contract-document-only with a document and no implementation
surface visible.

A verdict decided in preflight is a **dispatch** decision, taken from the snapshot before any code is
read. A domain may still conclude `not applicable` **after** it starts reading — a surface is not
proof that the thing behind it exists, so a unit with a `server` surface and no data-handling code, or
a `ui` surface and no request-making code, ends as `not applicable` with that reason. That is a
coverage outcome, not a contradiction of the preflight verdict, and each domain states its own case.

## Monorepos

Detection runs **per unit**. A unit is a directory with its own `package.json` or `composer.json`,
plus the repository root, which is always a unit — a repository can be a documentation or
configuration tree with real surfaces and no manifest at all.

A nested unit's tree is **excluded from its parent**, including the nested unit's own directory entry:
a monorepo root does not inherit its packages' surfaces, and a package directory that happens to be
named `lang`, `locales` or `src` does not set its parent's `i18n` or `architecture`. The snapshot
therefore carries a **list** of units, never one scalar verdict for the whole repository.

There is **no depth limit** on unit discovery. A cap would be doubly wrong: a package below it would
vanish from the snapshot entirely *and* its files would count as its ancestor's, producing a false
negative and a false positive from one arbitrary number. Vendored and build directories are excluded
by the walk, which is what a depth cap was really guarding against.

Every finding names its unit. A domain may be applicable in one unit and not applicable in another
inside the same run, and the coverage section records that per unit.

## Anti-patterns

- Inferring a surface from a project's name, a README claim, or a directory name that merely
  suggests a framework. A fact requires its marker.
- Reading directories by hand when the script is available, or "double-checking" the snapshot with
  ad-hoc `find` calls. The script is the authority; if it is wrong, change the script.
- Re-running detection inside a domain subagent that was handed a snapshot.
- Treating one marker as proof of a whole architecture — one numbered directory is not FSD
  compliance across the tree.
- Auditing a framework the repository does not contain because the domain "usually" applies to
  projects like this one.
- Reporting a fact as present without citing the marker that was found for it.
