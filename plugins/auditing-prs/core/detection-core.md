# Audit detection core

Shared detection engine for the `auditing-prs` plugin. Both `audit-pr` (publish)
and `prepush-audit` (local) read this file, then apply their own input/output
adapter. This file defines **what gets found**; presentation, publishing, and input
bindings live in the adapters.

Terms used adapter-neutrally:

- **The snapshot under review** — the exact code state an adapter binds: a PR head
  SHA (`audit-pr`), or a local `base...HEAD` / working tree (`prepush-audit`).
- **The asks** — every tracker requirement + every prior `Issue N`. These are the
  acceptance criteria the snapshot is judged against.

No `gh`/`curl`/`git` command literals appear here on purpose — the adapters bind the
concrete calls. The core stays neutral so the two skills can share it without drift.

## 1. Source gathering (union)

The audit input is the union of three sources, gathered up-front:

1. **Tracker ticket** (if the branch encodes an issue key) — summary, description,
   and **all** comments. Fetch with **full pagination**: when the reported comment
   total exceeds the items returned, page the dedicated comment endpoint until you
   have them all. A truncated subset (e.g. "last 3 comments") is a detection bug —
   the full ticket context matters for the audit and for independent verification.
2. **The changes** — the diff of the snapshot against its base.
3. **PR conversation, if a PR exists** — prior reviews, inline comments, author
   in-thread replies ("fixed" / "won't fix" / "deferred"), and the resolution state
   of each thread. Fetch **with full pagination** — long conversations otherwise
   silently drop earlier review history, and a "fresh" audit then re-flags issues
   already raised or contradicts earlier guidance. This conversation includes the
   reviewer's **published audit report** (its `Issue N` blocks with full
   descriptions) — the most valuable input for an executor's delta check.

**A prior summary review constrains new findings.** If an earlier review specified
the expected shape, the tracker ticket alone is not the source of truth — the
PR-level decision overrides. Read both before judging.

## 2. HEAD / snapshot discipline (BLOCKING)

Judge the **actual file at the snapshot**, never the diff alone. For every still-open
prior `Issue N`, read the file at the snapshot and judge the original ask against the
current code yourself.

**The code at the snapshot is the only authority** on whether an issue is addressed.
None of the following count as verification:

- a `[x]` checkbox in a prior summary checklist (only says "marked resolved at the
  time");
- a strikethrough row or "✅ fixed in commit …" marker (a claim, not proof);
- an author "fixed" reply on the thread (a claim, not proof);
- the absence of a re-flag in a later review (the prior reviewer may have missed it);
- **a diff view** — a diff shows the base→snapshot delta, not the current shape of a
  file in context. A line can look right in the diff and still be wrong in the file.
  Reading the diff is not verification.

This is BLOCKING: read the file at the snapshot **before** presenting any
reconciliation table or draft.

## 3. Convention discovery

Identify the changed files and open the conventions that apply to **each changed
path** — `CONTRIBUTING.md`, `CONVENTIONS.md`, `CLAUDE.md`, directory READMEs, and any
specialized guides. Specialized guides add rules on top of their ancestors; read both
the ancestor and the specialized guide. Discover these dynamically from the changed
paths — never from a hardcoded, project-specific table.

## 4. Focus lenses

Examine the snapshot through these lenses (the adapter or the user may narrow them):
**architecture**, **conventions** compliance, **code-quality** (readability,
duplication, complexity), **security**, **performance**.

### Lens criteria (soft dependency on the `auditing` plugin)

A lens without criteria is a name, not a check. When the `auditing` plugin's domain
skills are available in the session, each active lens reads the matching domain
skill's judgement content — its "What this domain judges" catalogue, its impact
dimensions, and its "findings versus notes" line — and judges the snapshot's changes
against it:

- `security` lens → `auditing:security`
- `performance` lens → `auditing:performance`
- `architecture` + `code-quality` lenses → `auditing:code-quality`

**Surface-triggered domains** join regardless of the chosen focus, but only when the
changes touch their surface:

- an endpoint, route, or API request/response shape → `auditing:api-contracts`
- a migration or storage-schema change → `auditing:data`
- failure handling, external calls, retries/timeouts → `auditing:reliability`

**Never wired:** `auditing:audit` and `auditing:remediate` (orchestration and
planning, not criteria), and the whole-product domains (`business-analysis`, `seo`,
`accessibility`) — application-scope audits, not change-review criteria.

Rules of use:

- **Criteria only, never process.** Take what counts as a finding, what does not, and
  how harm is graded. The domain skills' preflight, stack detection, report model,
  output locations, and finding-id prefixes do NOT apply — findings stay in this
  plugin's model (§8) and this plugin's flow.
- **Delta-scoped, always.** The domain skills read a whole codebase; here their
  criteria judge only what the snapshot's changes introduced or worsened. A
  pre-existing condition a domain skill would report is at most a follow-up here
  (§14), never an in-scope finding.
- **Severity mapping.** A domain `blocker` is a `blocker` (§8); `major` and `minor`
  map to `non-blocker` (the finer label may be carried in the rendered finding).
- **The dependency is soft.** With the `auditing` plugin absent, the lenses run on
  general knowledge exactly as before — and the report says so once ("lenses ran
  without codified criteria") instead of implying codified criteria were applied.

### Lens execution — searcher fan-out

Lenses run as parallel **searcher** subagents — one per active lens, plus one per
surface-triggered domain — not inline in the manager's context:

- **Conventions is a searcher too.** Its criteria are the discovered convention
  files (§3) instead of an `auditing` domain skill, so it runs regardless of whether
  that plugin is installed.
- **The manager gathers once; searchers never re-fetch.** Each searcher receives a
  prepared package: the asks, the audited range and changed-file list (the revision
  delta on repeat audits, §11), the mechanisms of issues being closed this revision
  (§13 — so siblings get checked), the materialized snapshot on disk, and **only its
  own** criteria source. Reading code from the snapshot is the searcher's job;
  pulling PR or tracker data again is not — N re-fetches waste calls and can
  straddle a moving head.
- **Searchers return findings in the §8 model.** The manager consolidates: dedupes,
  applies the scope boundary (§14), and drafts. A searcher's finding is a candidate,
  never a verdict.

An adapter without subagent dispatch runs the lenses inline — same criteria, same
rules; fan-out is the execution default, not a semantic change.

## 5. Per-ask acceptance verdict

For **every** ask (each tracker requirement + every prior `Issue N`), return exactly
one of:

- `done` — satisfied at the snapshot;
- `partial` — partially addressed;
- `not_done` — unaddressed;
- `cannot-verify-offline` — cannot be confirmed without runtime/external access.

Each verdict carries `file:line` evidence at the snapshot. Additionally, flag any
**new problems** the changes introduce. For a prior `Issue N` this verdict is the
same judgement as reconciliation (§6), bridged: `matches=done`, `partial=partial`,
`ignored=not_done`.

**A verdict judges the ask's mechanism across the whole delta**, not only the file
the ask names (§13): a sibling site in the delta where the same mechanism still
fails caps the verdict at `partial`. This binds everyone who judges asks — the
manager, the searchers, and the panel — without further instruction.

## 6. Prior-issue reconciliation (delta logic)

For each prior `Issue N`, map its latest state at the snapshot to one of the canonical
states — judged by reading the file at the snapshot (§2), not any prior claim:

- **matches** → fully addressed at the snapshot.
- **partial** → partially addressed; not yet done.
- **ignored** → unaddressed at the snapshot.

A `matches` verdict additionally requires the fix-impact check of §12 — satisfying the
original ask is necessary, not sufficient.

These canonical states are the single source of truth. An adapter that presents them
under other labels uses the fixed mapping: `matches→fixed`, `partial→partial`,
`ignored→open`. What an adapter then *does* with each state — drafting, re-flagging,
issue numbering, fix recommendations — is the adapter's concern, not the core's.

## 7. agent-companion verifier panel protocol

When agent-companion is enabled, run the audit past its verifier panel for an
independent check.

- **Materialize the snapshot** as a detached worktree at its exact SHA, so a head
  that moves mid-audit cannot change what was verified. (The adapter supplies the
  concrete SHA and worktree command; the SHA source differs per adapter.)
- **Hand the panel raw context, never your conclusions** (the independence
  invariant): the full tracker ticket, the full PR conversation verbatim, and the
  list of asks — plus the code. Do not provide your own verdicts; let each verifier
  reach its own against the code at the snapshot.
- **Hand the criteria too — floor, not ceiling.** Give each verifier the same
  criteria the searchers used: the active domain-skill contents and the discovered
  convention files (§3), framed as "apply these rules, and do not limit yourself to
  them". Criteria are shared rules, not conclusions — they sharpen the panel without
  breaking independence. Include the executable-evidence instruction (§17) as best
  effort. What stays withheld is the manager's and the searchers' findings and
  verdicts.
- **Consolidation.** A problem found independently by a searcher and by the panel is
  confirmed. A single-source finding is judged critically by the manager — kept with
  evidence, dropped with a stated reason, or escalated; never silently absorbed and
  never blindly published.
- **What is judged:** the panel runs an **acceptance review of each ask** (the per-ask
  verdict of §5) **and additionally flags new problems the changes introduce** —
  exactly the two outputs an adapter needs. "Acceptance review" only excludes a
  generic find-all-bugs sweep unrelated to the asks or the changes; it does not
  exclude new-problem detection.
- **Transport:** defer to the agent-companion manager protocol for how the panel is
  dispatched and how verdicts/exit codes are collected.
- **Treat verdicts critically** — don't accept them blindly; on reasoned
  disagreement, escalate rather than silently comply.

## 8. Neutral finding model (data, not presentation)

Every finding the engine produces carries these fields:

- `problem` — what is wrong (one sentence).
- `mechanism` — why it matters / the root cause.
- `evidence` — `file:line` at the snapshot.
- `severity` — `blocker` or `non-blocker`; this is what a readiness/publish decision
  gates on.
- `scope` — `in-scope` or `follow-up`, decided by the scope boundary (§14). Only
  in-scope findings gate anything or become issues; follow-ups are routed aside.
- `remediation` — the direction to the fix.

The core defines the **fields**. Each adapter decides how to render them — in
particular how `remediation` is expressed (`audit-pr` renders it as a named outcome
without the edit; `prepush-audit` renders it as a concrete fix) and the presentation
scaffold (headings, emoji). Presentation does not live in the core.

## 9. Stacked-branch base discovery

A **stacked branch** is cut from another working branch instead of the default
branch. Its snapshot then carries commits it did not author — the parent's. The audit
must judge only what this branch adds, so the base it diffs against is discovered, not
assumed.

Discovery is **automatic and evidence-based**: it reads commit ancestry only. Branch
names, ticket keys, and PR titles are never parsed — a naming scheme is a guess, shared
history is a proof.

### Inputs (each adapter binds them)

- **`DEFAULT`** — the repository's default branch. Discovered from the repository;
  never hardcoded to a particular name.
- **`HEAD`** — the head commit of the snapshot under review.
- **`CANDIDATES`** — the head commit of every **other open** pull request in the
  repository (this snapshot's own PR excluded).

### Primitives (each adapter binds them)

- **`merge-base(A, B)`** — the newest commit that is an ancestor of both `A` and `B`.
- **`is-ancestor(A, B)`** — whether `A` is an ancestor of `B`.

Both exist in every reasonable binding — a local VCS and a hosted compare API alike.

### The rule

1. **`MB_default = merge-base(DEFAULT, HEAD)`** — the branch point an ordinary audit
   already diffs from.
2. For every candidate head `C`: **`MB_c = merge-base(C, HEAD)`**.
3. `C` is a **stack ancestor** when `is-ancestor(MB_default, MB_c)` holds **and**
   `MB_c ≠ MB_default`. This means the snapshot shares history with `C` that the
   default branch does not have — which is exactly what stacking is.
4. **Discard** any candidate whose `MB_c == HEAD`. That PR contains all of this
   snapshot's work, so it sits *above* this branch in the stack, not below. (This also
   discards a candidate whose head equals this one.)
5. **`TRUE_BASE`** is the **deepest** surviving `MB_c` — the one that is a descendant
   of every other surviving `MB_c`. **`PARENT_PR`** is the candidate that produced it.
   When several candidates produce the **same** deepest `MB_c` (siblings cut from one
   point), the audited range is identical whichever is named: pick the
   lowest-numbered candidate as `PARENT_PR` so the result is deterministic, and name
   the tied ones in the report.
6. If no candidate survives, **`TRUE_BASE = MB_default`** and the audit proceeds exactly
   as it does without this section.

The base is a **branch point**, never a branch head. Comparing against the parent's
current head fails the moment the parent gains a commit after the child was cut — the
normal state of an active stack. A merge-base is immune to the parent advancing, being
rebased forward, or being merged into by others: it only requires a shared commit the
default branch does not have.

### Outputs

- **`TRUE_BASE`** — the commit the audited range starts at. The snapshot's changes are
  `TRUE_BASE … HEAD`; that range is the subject of the audit.
- **`PARENT_PR`** — the pull request the snapshot is stacked on, or none.
- **`INHERITED_FILES`** — the files whose diff between `MB_default` and `TRUE_BASE` is
  non-empty: the paths the parent branch already changed. Empty when no parent was
  found. Handling is `## 10.`

### Honesty rules

- **No parent found is the normal, silent case.** Most branches are not stacked. Say
  nothing, change nothing, audit as usual.
- **Never silently narrow the scope.** When a parent *is* found, the adapter states the
  detected parent, the audited range, and the count of files excluded as inherited.
- **A truncated candidate set is reported, never dropped.** When the adapter's listing
  limit cuts the set of open pull requests, say so — a parent older than the limit can
  otherwise be missed invisibly.
- **An unreachable candidate is skipped and counted, never treated as a negative
  ancestry result.** A head the adapter cannot read (a fork it has no access to, an
  object it has not fetched) is unknown, not "not an ancestor". Report the count.

### Known blind spots (degrade, never guess)

- **A parent that force-pushed fully rewritten history** leaves no shared commit outside
  the default branch, so `MB_c` collapses to `MB_default` and the stack is invisible.
  The audit degrades to the unstacked behaviour.
- **A parent branch with no open pull request** is not a candidate and cannot be found.
  Same degradation.
- **A squash-merged, closed parent** is not a candidate either, and its commits exist on
  the default branch under different identities, so `MB_default` may not exclude them.
  Self-corrects once the child rebases.

In every blind spot the outcome is today's behaviour, not a wrong base.

## 10. Inherited change handling

When `## 9.` found a `PARENT_PR`, the changes between `MB_default` and `TRUE_BASE`
belong to the parent branch. They are **context, not subject**.

- **Readable.** Inherited code is read freely — understanding the snapshot's change
  usually requires it, and the file-at-snapshot discipline (`## 2.`) still applies to
  the whole file, not just this branch's lines.
- **Not findable.** No finding may anchor its `evidence` (`## 8.`) to a line introduced
  between `MB_default` and `TRUE_BASE`. Those lines are the parent PR's review surface;
  flagging them here duplicates that review and blames this branch for work it did not
  do.
- **The one exception.** A defect in *this branch's own* change that only manifests
  through inherited code is a valid finding — but it anchors to **this branch's** line
  and names the inherited code in `mechanism`. The subject stays what this branch did.
- **The stacked condition itself is not a finding.** That a branch is stacked is
  reported as context by the adapter; it never becomes an issue of its own.

## 11. Revision delta discipline (repeat audits)

On a repeat audit (any prior review exists), the mandatory reading surface is **every
file changed since the last reviewed snapshot** — never the list of files with open
issues. Bind the **anchor** (the snapshot the latest review judged), take the diff
`anchor … snapshot`, and read every file in that delta at the snapshot, regardless of
its issue state.

- **A closed issue does not exempt a file.** An issue-driven reading list drops a file
  exactly when fixes land in it — which is when it most needs reading. Files whose
  issues are all resolved stay on the list as long as they appear in the delta.
- The full-branch diff still defines the overall finding surface (§1); the revision
  delta defines what MUST be re-read this revision.

## 12. Fix-impact verification (two-directional)

A fix is judged in **two directions**, and `matches` (§6) requires both:

1. **Backward** — the original ask is satisfied at the snapshot (§2).
2. **Forward** — the state the fix **created** is judged as a new change in its own
   right: what the fix removed (a total function, a validation, a fallback, an
   invariant), what it now lets in, and what its call sites now receive. Ask
   explicitly: *what does this fix make possible that was impossible before?* A defect
   introduced by a fix is a new finding anchored at the fix's own lines — never
   silently absorbed into the closed issue.

**Proportional depth for contract rewrites.** When a fix (or the remediation that asked
for it) rewrites a contract — a component's props/emits/slots, an exported API, a type
consumed elsewhere, a data-flow direction — closing it requires reading **every
consumer of that contract** at the snapshot, not just the file the issue named. A
one-line local fix needs its file; a contract rewrite needs the contract's whole
surface.

## 13. Mechanism propagation

A confirmed mechanism is a property of a **pattern**, not of the file where it was
first seen. The sweep runs in **both directions**:

- **Defect direction.** Once a finding's mechanism is confirmed at one site, search
  the rest of the changed set (and, on repeat audits, the delta of §11) for the same
  pattern **before drafting**, and attach each additional site as its own `evidence`
  line. Closing the issue at one site while a sibling file keeps the same defect is a
  detection bug, not a next revision's discovery.
- **Fix direction.** When a fix establishes how a state is presented or handled — a
  loading skeleton, a validation, an error state — check the sibling sites in the
  delta that carry the same state: a sibling left on a different treatment is a
  finding or a follow-up ("one state, two presentations"), decided by the scope
  boundary (§14). The question is not only "is the defect elsewhere?" but "is the
  accepted fix applied everywhere it applies?".

**Ownership is explicit — three nets, one definition:**

1. **The manager, at closure — BLOCKING.** No prior issue reaches `matches` (§6)
   until the manager has enumerated the mechanism's sibling sites across the delta
   and recorded a per-site verdict. Closing on the named file alone is the failure
   mode this section exists to stop.
2. **The searchers.** The searcher package (§4) carries the mechanisms of issues
   being closed this revision; each searcher checks siblings within its own lens.
3. **The panel — by definition, not by extra instruction.** §5 defines an ask's
   verdict as the mechanism holding across the whole delta; the panel judges every
   ask against that definition.

## 14. Scope boundary (ticket vs refactor)

Every finding carries a `scope` (§8), decided here. A finding is **in-scope** when at
least one holds:

- it shows a tracker ask `partial` / `not_done` (§5);
- the snapshot's own changes introduced or worsened it;
- it is `blocker` severity, wherever it lives.

Everything else — pre-existing structure the ticket did not ask to change,
architectural relocations ("move this to the domain layer"), type consolidations,
data-flow inversions that merely *improve* code the diff touched — is `follow-up`.
Follow-ups are reported once, in a dedicated non-gating section, as candidates for
separate tickets; they never gate the review, never demand a fix in this change set,
and are never re-flagged revision after revision. A narrow ticket must not grow into a
structural refactor through review pressure.

## 15. Convergence and exit

The review has an explicit exit condition, checked every revision **before** drafting
new findings:

> Every tracker ask is `done` (§5) **and** no in-scope `blocker` finding is open.

When it holds, the review **converges**: state it, close what is closable, and route
anything newly noticed to follow-ups (§14). After convergence a new finding is
admitted only if it is (a) a regression introduced by a fix (§12) or (b) a `blocker`.
Reaching convergence and continuing to add non-blocking findings anyway is a process
defect, not thoroughness.

## 16. Adversarial refutation (the skeptic)

Every verdict that ends a conversation gets an adversary before it is presented:

- **A candidate finding** → task: *prove this is not a bug.* Angles: the case is
  handled elsewhere, the behaviour is intended, the precondition cannot occur.
- **A closure candidate** (an ask about to be `done`, an issue about to be
  `matches`) → task: *prove this is NOT done.* Angles: the original ask only
  partially satisfied; the state the fix created (§12); sibling sites (§13); what
  the contract's consumers now receive.

One skeptic per batch is enough — hand it both lists plus the snapshot and the
delta; it returns "survived" or "refuted + evidence" per item. A refuted finding is
dropped and never published; a refuted closure falls to `partial`, carrying the
skeptic's evidence. The skeptic can be wrong in both directions — the manager
judges its verdicts critically, same as the panel's (§7); on reasoned disagreement,
escalate rather than silently comply.

Refutation may be skipped only for findings independently confirmed by both a
searcher and the panel (§7 consolidation) — cross-confirmation already did the
work. A confirmer looks for evidence of "yes"; the skeptic looks for evidence of
"no"; together they are more honest than either alone.

## 17. Executable evidence

Where a check can be executed cheaply — a grep over the snapshot, a type-check in
the worktree, a small computation (a contrast ratio, a count of call sites) —
executing it is **mandatory** for the manager, the searchers, and the skeptic.
Reading the code and concluding is not evidence when a one-command check exists;
the command's output becomes the finding's `evidence`, cited in it.

**Arbitration:** an executed check outranks any agent's claim — the manager's, a
searcher's, the skeptic's, or a panel verifier's. A claim contradicted by an
executed check is wrong: re-examine the claim, not the output (unless the check
itself was malformed — then fix the check and re-run it).

External panel verifiers cannot be forced to execute anything; the §7 handoff
carries this instruction as best effort.

## 18. Coverage accounting

Fan-out reads selectively — each searcher opens what looks relevant to its lens —
so nothing guarantees every changed file was examined by anyone. Make it a checked
fact, not an assumption:

- **Every searcher reports the files it examined** alongside its findings.
- **The manager folds these into a map**: audited file → lenses that examined it.
  The audited set is the full diff on a first pass, the revision delta (§11) on a
  repeat audit.
- **A file no searcher examined is a coverage gap**: read it before drafting, or
  name it in the report. A gap neither closed nor named is a detection bug —
  "covered everything" may only be said when the map shows it.

## 19. History check (rewritten lines)

The diff shows what the change is; history shows what the change **undoes**. For
the lines the change rewrites or deletes, check where they came from (blame at the
base of the audited range): a line that originated in a fix, workaround, or revert
commit is a **hotspot** — the change may be silently reintroducing the bug that
commit fixed.

- **The manager runs this as an executable check (§17)** over the audited range and
  hands each hotspot to the relevant searcher's package. Every hotspot gets an
  explicit verdict: *intentional* (the asks or the PR conversation sanction the
  removal) or a *finding* anchored at this change's lines.
- Commit-message markers (`fix`, `hotfix`, `revert`, `bug`) and explanatory
  comments on the removed lines are signals, not proof — the verdict comes from
  comparing the old commit's purpose with the new code's behaviour.
- A hotspot with no verdict is a coverage gap (§18). Silence is not allowed.
