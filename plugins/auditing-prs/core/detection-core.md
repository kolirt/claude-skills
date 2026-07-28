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

## 6. Prior-issue reconciliation (delta logic)

For each prior `Issue N`, map its latest state at the snapshot to one of the canonical
states — judged by reading the file at the snapshot (§2), not any prior claim:

- **matches** → fully addressed at the snapshot.
- **partial** → partially addressed; not yet done.
- **ignored** → unaddressed at the snapshot.

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
- `remediation` — the direction to the fix.

The core defines the **fields**. Each adapter decides how to render them — in
particular how `remediation` is expressed (`audit-pr` renders it as a non-recipe
direction; `prepush-audit` renders it as a concrete fix) and the presentation
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
