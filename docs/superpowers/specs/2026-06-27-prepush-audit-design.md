# prepush-audit — design spec

## Problem

An executor runs a self-check skill (`pre-push-audit`, in the reference project)
before pushing, yet after the PR is opened the reviewer's skill (`auditing-prs`)
reliably finds problems the self-check missed. The two disagree because the
self-check is a copy of the *old, inferior* `auditing-prs` and never received the
new detection discipline: it has no independent verifier panel, weak
"read-the-file-at-HEAD-not-the-diff" enforcement, truncated tracker context
(only the last 3 comments), no focus lenses, and stale project-coupled convention
discovery.

The fix is not "add one more check." It is to make the executor's pre-push audit
detect the **same** problems the reviewer's audit will, by sharing one detection
engine instead of maintaining a second, drifting copy.

## Goal

A new executor-side skill, `prepush-audit`, that surfaces the same findings
`audit-pr` (the published-review skill) would — **read-only, chat-only, before
push** — so the executor fixes problems before the reviewer ever sees them, and
verifies that a prior published review has actually been addressed.

Parity with the reviewer is the success criterion: when `prepush-audit` reports
"ready," a subsequent `audit-pr` run on the same SHA should find little to nothing
new.

## Architecture: shared detection core + two adapters

The `auditing-prs` plugin keeps its name and hosts two skills plus a shared,
non-skill reference file:

```
plugins/auditing-prs/
  .claude-plugin/plugin.json     # description updated (two skills); version bumped
  skills/
    audit-pr/SKILL.md            # PUBLISH adapter (renamed from auditing-prs)
    prepush-audit/SKILL.md       # LOCAL adapter (new)
  core/
    detection-core.md            # SHARED detection engine (reference, not a skill)
```

The plugin name, marketplace entry, and `agent-companion` plugin are unchanged.
`core/detection-core.md` is a plain reference file (no skill frontmatter) so the
harness does not surface it as a skill. Each `SKILL.md` opens by instructing the
reader to read `../../core/detection-core.md`, then applies its own adapter.

### Why shared-core, not fork-or-trim

A forked/trimmed copy is the status quo that caused the drift in the first place.
The verifier panel (codex, grok-composer, grok) unanimously recommended a single
shared core with thin adapters as the only durable guarantee that the two skills
keep finding the same things over time.

## `core/detection-core.md` — the shared engine

Everything that determines *what gets found* lives here, so both skills inherit it
identically:

1. **Source gathering (union):**
   - Tracker ticket — summary + description + **all** comments, paginated (not a
     truncated subset).
   - Branch diff against the base.
   - PR conversation **if a PR exists** — prior reviews, inline comments, author
     replies, thread resolution state, fetched with **paginated** `gh api` (long
     PRs silently drop earlier history without `--paginate`). This includes the
     reviewer's **published audit report** (its `Issue N` blocks with full
     descriptions), which is the most valuable input for the executor's delta
     check. A prior **summary review constrains new findings**: a PR-level decision
     in an earlier review overrides the tracker ticket alone — read both.
2. **HEAD / snapshot discipline (BLOCKING):** judge the actual files at the
   snapshot under review, never the diff alone. The diff shows base→snapshot delta,
   not the current shape of a file in context. For every still-open prior `Issue N`,
   read the file at the snapshot and judge it against the original ask.
3. **Convention discovery:** dynamically open the conventions that apply to each
   changed path (CONTRIBUTING / CONVENTIONS / CLAUDE.md / directory READMEs;
   specialized guides on top of ancestors). No hardcoded project-specific table.
4. **Focus lenses:** architecture / conventions / code-quality / security /
   performance.
5. **Per-ask acceptance verdict:** for every ask (tracker requirement + every prior
   `Issue N`), return `done | partial | not_done | cannot-verify-offline` with
   `file:line` evidence at the snapshot, and flag any new problems introduced. For a
   prior `Issue N` this verdict is the same judgement as reconciliation (item 6),
   bridged as `matches=done`, `partial=partial`, `ignored=not_done`.
6. **Prior-issue reconciliation (delta logic):** map each prior `Issue N` to the
   canonical states `matches | partial | ignored` against the snapshot — the same
   reconciliation `audit-pr` performs across revisions. These are the single source
   of truth; any adapter that presents them under other labels (e.g.
   `fixed/partial/open`) must use the fixed mapping `matches→fixed`,
   `partial→partial`, `ignored→open`.
7. **agent-companion verifier panel protocol:** materialize the snapshot as a
   detached worktree at its exact SHA, hand the panel **raw context** (ticket +
   conversation + asks) and the code — never your own conclusions — and collect a
   per-ask independent verdict. The panel runs an **acceptance review of each ask**
   (the per-ask verdict of item 5) **and additionally flags new problems the changes
   introduce** — exactly as `audit-pr`'s companion does. "Acceptance review" only
   excludes a generic find-all-bugs sweep unrelated to the asks or the changes; it
   does not exclude new-problem detection. Defer to the agent-companion manager
   protocol for dispatch/verdict transport.
8. **Neutral finding model (data, not presentation):** every finding carries
   `problem` (what is wrong), `mechanism` (why it matters / root cause),
   `evidence` (`file:line` at the snapshot), `severity` (blocker / non-blocker —
   what the readiness verdict gates on), and `remediation` (the direction to the
   fix). The core defines the *fields*; each adapter decides how `remediation`
   is rendered — `audit-pr` renders it as a non-recipe direction, `prepush-audit`
   renders it as a concrete fix. Presentation (the Problem / Why / Where scaffold,
   emoji, headings) lives in the adapters, not here.

The core states the engine in adapter-neutral terms ("the snapshot under review",
"the audit output destination") so each adapter binds those slots.

## `audit-pr` — publish adapter (renamed, behavior preserved)

The current `auditing-prs` skill, unchanged in behavior:

- Input binding: PR via `gh`; snapshot = PR head SHA via the contents API.
- `gh auth`, optional Jira context, draft-in-chat → publish → resolution
  mechanisms, comment-format conventions (disclosure prefix, `Issue N` heading,
  emoji scheme), continuous issue numbering.
- Renders the core's neutral finding model with the Problem / Why / Where scaffold;
  **`remediation` is rendered non-recipe** ("Where to dig") — educational, for the
  PR author; never the final fix.

The only structural change: the portions of the body that describe detection are
replaced by a reference to `core/detection-core.md`; the publish/format/resolution
machinery and the non-recipe rendering stay in the adapter.

## `prepush-audit` — local adapter (new)

Executor-side self-check before push. Same detection core, different input and
output bindings.

### Input bindings (what this adapter feeds the core)

- **Branch + base.** Current local branch; base per "Snapshot selection" below.
- **Tracker key** extracted from the branch name (same regex convention as
  `audit-pr` Step 0.5); optional Jira fetch (all comments, paginated) — non-fatal
  if unavailable.
- **PR discovery (read-only).** Look up a PR for the current branch; if one exists,
  read its conversation and the reviewer's published audit (this drives delta
  mode). If none exists, first-pass mode.
- **Focus lenses.** Default to all five (architecture / conventions / code-quality
  / security / performance); the executor may narrow them.

### Read-only contract

"Read-only" means **no mutation of external systems and no push** — the audit pass
never changes shared state:

- No GitHub writes (no `gh pr review`, no `gh api` POST/PATCH/PUT/DELETE).
- No Jira writes.
- No `git push`.
- **Explicitly permitted reads:** read-only `gh api` GETs, `gh pr view/list`, Jira
  GETs, and all local git reads — the core's source-gathering needs these.
- **Allowed:** a temporary detached worktree for the panel (this is how the core
  materializes a snapshot; it is not a mutation of the user's repo or branch).
- The audit report stays in chat.
- **Local fix application is a separate, opt-in action, not part of the audit.**
  After the report, the executor may ask the skill to apply a recommended fix; that
  edits local working files only (never GitHub/Jira, never a push). It is the
  executor's own tool acting on their own tree — distinct from, and after, the
  read-only audit pass. Re-running the audit after edits judges the new state.

### Snapshot selection

- **Default — parity mode:** `base...HEAD` (committed branch diff). This is exactly
  what the PR will show the reviewer at the same SHA, so results match `audit-pr`.
- **Flag — include working tree:** additionally judge staged + unstaged + untracked
  changes, so the executor can self-check before committing. Explicitly marked as
  "not yet what the PR will show until committed."
- **Dirty-tree warning:** when judging the committed default while uncommitted
  changes exist, state plainly that N files are outside the audit (commit or pass
  the flag).
- The panel always runs on a committed snapshot (a worktree needs a SHA); in the
  working-tree mode the solo engine reads the working tree and the skill notes that
  the panel covered the committed snapshot.

**Base discovery (must match what the PR will diff against):**
- If a PR exists, the base is the PR's target branch — read it (read-only) and use
  it; do not assume `main`.
- If no PR exists, default to the merge base with the project's main branch
  (`main`/`master`/the repo's default), discovered, not hardcoded.
- The executor may override the base. The skill always states the base it chose, so
  a mismatch with the eventual PR target is visible.

### Two modes (same core, different input)

- **Prior published audit exists (delta mode):** the value is the delta, not a
  re-derived full report. Produce (a) a status table mapping each prior `Issue N` to
  `matches→fixed / partial / ignored→open` at the local snapshot (core item 6),
  with a concrete **fix recommendation** for anything not fully fixed, and (b) a
  scan of the changes made since that audit for new problems — performed by the
  solo engine **and**, when agent-companion is enabled, by the panel (item 7), so
  push-readiness gates on the same new-problem detection `audit-pr` would apply. Do
  **not** reproduce the reviewer's whole report.

  **Prior-audit anchor.** "Changes since that audit" needs an explicit anchor: the
  commit SHA the latest review was submitted against (derive it from the latest
  review's submission and the PR head at that time). The new-changes scan covers
  `anchor … local snapshot`. A prior audit may be inline-only (no summary review) —
  inline comments still count; with multiple revisions, anchor to the **latest**
  review. If the local `HEAD` is behind the PR head (executor hasn't pulled), say so
  and stop rather than judge a stale snapshot.
- **No prior audit (first-pass mode):** run the full first detection pass over the
  branch — the original "catch it before the reviewer does" goal. This applies
  whenever no published audit exists yet — both before any PR is opened and when a
  PR exists but has not yet been reviewed.

"No new problems" is not zero work: it still requires a scoped fresh detection over
the changes since the anchor (delta) or over the whole branch (first-pass).

### Output

- Chat-only.
- **Concrete fix recommendations** — unlike `audit-pr`, this is the executor's own
  tool, so it states *how* to fix, and may offer to apply the fix. This is the one
  deliberate divergence from the published adapter; detection is identical, the
  output adapter differs.
- Sections: prior-audit reconciliation table (if any) → new findings (scaffold +
  fix recommendation) → push-readiness verdict.

**Push-readiness verdict.** "Ready" requires **every ask `done`** — both every
prior `Issue N` at `matches` (fixed) AND every tracker/original requirement
satisfied — AND no new blocker-severity finding. Any ask left
`cannot-verify-offline` does **not** count as ready: it is listed explicitly as
unverifiable and downgrades the verdict to "ready except for N unverifiable items"
— never silently treated as done. A skipped panel (agent-companion off) is surfaced
the same way (see Panel).

### Panel

- If agent-companion is enabled, the panel runs — mandatory, same as `audit-pr`.
  This matters *more* here than for the reviewer: an executor auditing their own
  work has a confirmation-bias blind spot an independent panel does not.
- If agent-companion is off (or no verifier is available), run solo and say so
  explicitly — "ran without independent verification," do not claim parity.

## Out of scope

- Renaming the plugin, marketplace entry, or the `agent-companion` plugin.
- Multi-round GitHub thread reconciliation beyond reading existing PR state
  read-only (no resolving/posting — that is `audit-pr`'s job).
- Replacing the reference `pre-push-audit` in that project's tree (this plugin
  supersedes it; removing the old one there is a separate, later step).

## Risks / open considerations

- **Drift** if the core is copied into an adapter instead of referenced — adapters
  must reference, never inline, the core.
- **False confidence** — a "ready" verdict that ignored `cannot-verify-offline` or
  a skipped panel. The verdict must surface skipped/unverifiable asks explicitly.
- **Latency/friction** of a mandatory high-effort panel may tempt bypassing; the
  read-only, before-push framing keeps the cost proportionate.
