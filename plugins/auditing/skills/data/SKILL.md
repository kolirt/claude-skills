---
name: data
description: Use on demand to audit the storage layer of a WHOLE application — 'data audit', 'аудит даних', 'schema audit', 'check the migrations', 'are our constraints right', 'money stored as float', 'orphan rows'. Judges whether the schema makes wrong data impossible: uniqueness, foreign keys and delete behaviour, migration safety, money and time representation, soft-delete consistency, constrained enumerations, indexes behind real filters, nullability. Reports findings, never fixes them and never touches a database. Not a query-speed review (auditing:performance) and not an access-control review (auditing:security). Audits of a PR diff belong to the auditing-prs plugin.
---

# Data audit

Judges the storage layer's invariants: whether the schema **makes wrong data impossible**, or merely
hopes application code will never write it.

The separating sentence: every other domain reads what the code does — this domain reads what the
schema *permits*, and a finding is the gap between the two.

## 0. Preflight — stack facts this domain needs

Read `../../core/stack-detection.md`. Under the dispatcher the snapshot arrives as an input:
detection is not repeated here and the snapshot is not argued with. Invoked directly, this domain
runs detection itself first.

| Fact needed | Used for | When absent |
|---|---|---|
| `data_schema` | Full scope: the schema is the evidence. | Fall back to reduced scope, below. Never `not applicable` on its own. |
| `server` or `ui` (either present) | Establishing what the code *assumes* about the data at the boundary it does have. | Findings are limited to what the schema alone shows; note it in coverage. |
| `convention_plugins` | Whether knowledge tier 3 exists this run. | Tiers 1 and 2 run; the missing tier is a coverage line. |

**Reduced scope when no schema is detected.** This domain does not report `skipped: not applicable`
and stop merely because `data_schema` came back absent. It falls back to **API-boundary data
integrity** — the shapes the application sends, receives and stores through whatever surface it does
have. The reduced scope is stated plainly in the report and recorded in coverage as a deliberate
narrowing, not as full coverage.

`server` or `ui` being present does not by itself prove the unit reads or writes anything. In reduced
scope, if reading the unit turns up no data-handling code at all — no persistence call, no storage
client, nothing kept between requests — the domain records `skipped: not applicable` with that reason,
rather than reporting on a surface that does not actually persist anything.

`skipped: not applicable` is the correct outcome only when `data_schema`, `server`, and `ui` are **all**
absent — no schema and no data-handling surface at all. Absent facts never produce invented findings.

## 1. What this domain judges

### Uniqueness

- Every field the application treats as unique carries a **database-level** unique constraint.
- An application-level "does this already exist" check with no constraint behind it is a race, and a
  finding — two concurrent requests both pass the check.
- Composite uniqueness the product depends on (one membership per user per team) is declared as a
  composite constraint, not assumed.

### Referential integrity and delete behaviour

- Foreign keys are actually declared, not merely implied by a column named `*_id`.
- Every relation has a **defined behaviour on delete** — cascade, restrict, or null — and that
  behaviour matches what the product intends for the child rows.
- Orphan rows are **impossible**, not unlikely: absence of an orphan today is not a constraint.
- A cascade that silently removes rows the product treats as records worth keeping is as much a
  finding as a missing key.

### Migration reversibility and safety

- A migration can be rolled back, or states why it cannot.
- A destructive change (dropped column, narrowed type, deleted rows) declares the intent to lose that
  data; a drop with no stated intent is a finding.
- A migration that assumes an empty table — a non-null column with no default, a unique constraint
  added over existing data, a backfill that is missing — breaks on the first populated environment.
- Order matters: a migration that depends on another having run is a finding when nothing enforces it.

### Money

- Money is **never** a float or a double. An integer minor unit or an exact decimal, nothing else.
- Every amount has a defined currency alongside it. A bare amount column in a product that can hold
  more than one currency is a finding.
- Rounding is decided in **one** place. Two call sites rounding independently is how totals stop
  matching their parts.

### Dates and time

- A timezone-bearing type where the **moment** matters; a plain date where the **calendar day**
  matters; the two never confused for each other.
- No local-time storage that cannot later be interpreted — a naive timestamp with no recorded zone
  and no convention is unrecoverable data.
- Ranges (`starts_at` / `ends_at`) carry the same type and the same interpretation on both ends.

### Soft delete consistency

- If a soft-delete flag or timestamp exists, **every** read path respects it. One query that forgets
  is the finding, not the flag.
- Uniqueness constraints account for soft-deleted rows: either the constraint excludes them or the
  product genuinely cannot reuse the value.
- Relations pointing at a soft-deleted parent have a defined meaning.

### Enumerated values

- A constrained set is enforced by the **schema** — a native enum, a check constraint, or a foreign
  key to a lookup table — not by an unconstrained string column that application code hopes to guard.
- The set in the schema and the set the code branches on are the same set. A value the code handles
  but the schema forbids, or vice versa, is a finding.

### Indexes backing real filters

- The columns the application actually filters, sorts and joins on are indexed. Establish this from
  the query sites, not from intuition.
- The reverse counts too: an index nothing queries is write cost with no read benefit, and a finding
  at `minor`.
- Foreign key columns used in lookups are covered.

### Nullability and defaults

- A column is nullable because the domain genuinely has an unknown state, not because nullable was
  easier to migrate.
- Defaults do not silently invent data — a default status, a default zero amount, or a default
  timestamp that makes a missing value indistinguishable from a real one.
- A nullable column the code dereferences unconditionally is a finding in this domain, because the
  schema permits the state the code denies.

### Reduced scope — API-boundary data integrity

Applies when no schema is detected. Same questions, moved to the boundary:

- Uniqueness and identity assumptions in the client's own state — a keyed collection whose key is not
  actually unique.
- Money represented as a float in transit, or an amount with no currency beside it.
- Dates crossing the boundary without a zone, or a date and a moment handled by the same code path.
- Enumerations validated nowhere — a value accepted from the server or the user and branched on
  without a checked set.

## 2. Impact dimensions

Severity is graded by data impact, never by code shape. The scale itself lives in
`../../core/report-model.md`.

- **blocker** — data can be silently corrupted, lost, or double-counted (money in particular), or the
  schema permits a state the product treats as impossible.
- **major** — a real integrity hole that current application code happens to avoid; nothing but that
  code stands between the schema and bad data.
- **minor** — a hygiene gap: an unused index, a default that is merely untidy, a naming inconsistency
  with no integrity consequence.

## 3. What this domain does NOT cover

- **Query patterns and speed** belong to `auditing:performance` — the N+1, the unbounded read, the
  slow join. This domain owns whether an index **exists** to back a filter the code actually issues;
  performance owns whether the resulting query is fast enough. Both files state this seam.
- **Exposure and access control** belong to `auditing:security` — who may read a column, what a
  response leaks. This domain owns **PII at rest as a schema fact**: which fields hold personal data,
  whether they are constrained, and whether they can actually be deleted. Both files state this seam.
- **A multi-step write that can half-apply** belongs to `auditing:reliability` — transactions,
  retries, idempotency. This domain owns the constraints the storage layer itself enforces.
- **Response and payload shape** belongs to `auditing:api-contracts`; this domain owns the storage
  shape behind it.
- Whether the data model serves the product's flows at all belongs to `auditing:business-analysis`.

## 4. How to audit

Static reading only. Do **not** connect to a database, do not run migrations, do not run a schema
diff tool.

1. Read the migrations in order, then the model/schema definitions. This is the primary evidence:
   what the storage layer actually guarantees.
2. Read the application's read and write paths for each entity that matters. This establishes what
   the code **assumes** — the uniqueness it relies on, the non-null it dereferences, the enum set it
   branches on, the columns it filters by.
3. **A finding is the gap** between what the code assumes and what the schema guarantees. Either side
   alone is a note; the pair is the finding, and both sides get cited.
4. Establish absence properly. A missing constraint has no `file:line` — use the `expected surface
   absent` locator from `../../core/report-model.md`, naming the migration or schema file where the
   constraint was expected and how you established it is not declared elsewhere.
5. Where the live schema may differ from what the migrations say — a hand-applied change, a
   migration squashed or edited after the fact, an environment out of step — record that as a
   **coverage blind spot**, not as a finding.

## 5. Knowledge tiers

- **Tier 1 — universal storage invariants.** Everything in section 1 that holds regardless of engine:
  money is not a float, a unique assumption needs a constraint, a foreign key needs a delete
  behaviour, a destructive migration needs a stated intent.
- **Tier 2 — the detected `framework`'s documented data-layer idioms.** For `laravel`, how Eloquent
  migrations and models declare constraints, casts, enums, soft deletes and reversibility, and which
  of those they do *not* do for you. Where no framework is detected and the schema is raw `*.sql`
  migrations, tier 2 is the general discipline of hand-written SQL migrations.
- **Tier 3 — codified project conventions.** No `knowledge-*` plugin codifies backend data
  conventions today, so tier 3 is usually **empty** for this domain; say so in coverage rather than
  implying it was applied. The closest codified universal rules are `knowledge-principles:state`, for
  the reduced client-side scope. Every such dependency is soft: absent means tiers 1 and 2 run
  normally plus one coverage line.

## 6. Report

Read `../../core/report-model.md` and follow it as written; nothing from it is restated here.

- Finding-id prefix: **`DATA`** — `DATA-1`, `DATA-2`, …
- `remediating skill` is fully qualified when a skill owns the fix, and left empty when none does —
  which is the common case here, since schema changes rarely have a codified owner. Naming the fix
  in `mechanism` is not a substitute for leaving the field empty honestly.
- Never read `panel-integration.md`: that is dispatcher-only.
