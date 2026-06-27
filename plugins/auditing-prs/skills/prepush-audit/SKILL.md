---
name: prepush-audit
description: Use when an executor wants to self-check a branch BEFORE pushing or before opening a PR — does the work actually complete the task, and is every prior review Issue addressed? Read-only and chat-only: never writes to GitHub or Jira and never pushes. Surfaces the same findings the audit-pr reviewer would, so problems get fixed first.
---

# Pre-push audit

Executor-side self-check. Same detection engine as `audit-pr`, bound to the **local**
branch and reported **in chat** — never published.

## Detection engine

Read `../../core/detection-core.md` first — it defines the sources, HEAD/snapshot
discipline, convention discovery, focus lenses, the per-ask acceptance verdict,
reconciliation states, the verifier-panel protocol, and the neutral finding model.
This skill is the **local adapter**: it binds the core's sources to the local branch
(PR optional), enforces a read-only contract, and renders findings as concrete fix
recommendations. Where a step below names a detection rule, the core is the authority.

## Input bindings

- **Branch + base.** Current local branch; base per "Snapshot selection" below.
- **Tracker key** from the branch name (same regex convention as `audit-pr`, e.g.
  `^[A-Z][A-Z0-9]+-[0-9]+`); optional tracker fetch (all comments, paginated — core
  §1) — non-fatal if unavailable.
- **PR discovery (read-only).** Look up a PR for the current branch
  (`gh pr list --head "$(git branch --show-current)"`); if one exists, read its
  conversation and the reviewer's published audit (this drives delta mode). If none
  exists, first-pass mode.
- **Focus lenses.** Default to all five (core §4); the executor may narrow them.

## Binding commands (read-only)

These are this adapter's concrete bindings for the core's abstract sources/snapshot —
the same completeness `audit-pr` uses (full pagination, file-at-snapshot reads, a
pinned worktree), but all GET-only and mostly local. Resolve the repo once:
```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
BRANCH=$(git branch --show-current)
```

**PR discovery + base + anchor:**
```bash
PR=$(gh pr list --head "$BRANCH" --repo "$REPO" --json number,headRefOid,baseRefName -q '.[0]')
PR_N=$(echo "$PR" | jq -r '.number // empty')
PR_HEAD=$(echo "$PR" | jq -r '.headRefOid // empty')
# Base: the PR target if a PR exists, else the repo default branch (never assume main).
BASE=$(echo "$PR" | jq -r '.baseRefName // empty')
[ -z "$BASE" ] && BASE=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
# Delta anchor = the commit the LATEST review was submitted against. A review carries
# its own commit_id, so this works for summary-only reviews with no inline comments.
# --slurp combines all --paginate pages into one array, so max_by is GLOBAL, not per-page.
if [ -n "$PR_N" ]; then
  ANCHOR=$(gh api --paginate "repos/$REPO/pulls/$PR_N/reviews" --slurp \
    --jq 'add | map(select(.commit_id)) | max_by(.submitted_at) | .commit_id' 2>/dev/null)
  # Fallback: if there are no reviews with a commit_id, use the latest inline comment.
  [ -z "$ANCHOR" -o "$ANCHOR" = "null" ] && ANCHOR=$(gh api --paginate "repos/$REPO/pulls/$PR_N/comments" --slurp \
    --jq 'add | max_by(.created_at) | .original_commit_id' 2>/dev/null)
fi
# Stale-checkout guard (core: judge the right snapshot): if the PR head is NOT an
# ancestor of local HEAD, the executor's checkout is behind — stop, don't audit stale code.
if [ -n "$PR_HEAD" ] && ! git merge-base --is-ancestor "$PR_HEAD" HEAD 2>/dev/null; then
  echo "Local HEAD is behind PR head $PR_HEAD — pull before auditing"; # then stop
fi
```

**PR conversation — paginated, GET-only (core §1; mirrors `audit-pr`'s fetch):**
```bash
gh api --paginate "repos/$REPO/pulls/$PR_N/comments" \
  --jq '.[] | {id, user: .user.login, path, line, original_commit_id, created_at, body}'
gh api --paginate "repos/$REPO/pulls/$PR_N/reviews" \
  --jq '.[] | {id, user: .user.login, state, submitted_at, body}'
gh api graphql --paginate -f query='
  query($owner:String!,$repo:String!,$pr:Int!,$endCursor:String){
    repository(owner:$owner,name:$repo){ pullRequest(number:$pr){
      reviewThreads(first:100, after:$endCursor){
        nodes{ isResolved comments(first:1){ nodes{ databaseId } } }
        pageInfo{ hasNextPage endCursor } } } } }' \
  -f owner="${REPO%/*}" -f repo="${REPO#*/}" -F pr="$PR_N" \
  --jq '.data.repository.pullRequest.reviewThreads.nodes[] | {comment_id: .comments.nodes[0].databaseId, isResolved}'
```
Tracker fetch is the same read-only GET (with comment pagination) as `audit-pr`'s
Step 0.5 — never a write.

**Snapshot diff (per "Snapshot selection"):**
```bash
git diff "$BASE"...HEAD          # default parity snapshot (committed base...HEAD)
git diff "$BASE"                 # with the --include-working-tree flag (adds staged+unstaged)
git status --porcelain           # detect a dirty tree to warn about
```

**Read a file at the snapshot — local, no contents API needed** (core §2, BLOCKING):
```bash
git show HEAD:{path}             # committed snapshot
# working-tree mode: just read {path} from disk
```
For the delta new-problem scan, limit to the anchor range: `git diff "$ANCHOR"...HEAD`.

**Materialize the committed snapshot as a detached worktree for the panel** (core §7;
SHA pinned so solo + panel + a later `audit-pr` all judge ONE snapshot):
```bash
SNAP=$(git rev-parse HEAD)       # committed branch tip = the parity snapshot
WT="$(mktemp -d)/prepush-$BRANCH"
git worktree add --detach "$WT" "$SNAP"
trap 'git worktree remove --force "$WT" 2>/dev/null' EXIT   # always clean up
```
All of the above are reads or a throwaway worktree — none mutate GitHub, the tracker,
or the branch, and none push.

## Read-only contract

"Read-only" means **no mutation of external systems and no push** — the audit pass
never changes shared state:

- NO GitHub writes (no `gh pr review`, no `gh api` POST/PATCH/PUT/DELETE).
- NO Jira writes. NO `git push`.
- **Permitted reads:** read-only `gh api` GETs, `gh pr view/list`, tracker GETs, and
  all local git reads — the core's source-gathering needs these.
- **Permitted:** a temporary detached worktree for the panel (this is how the core
  materializes a snapshot; it is not a mutation of the repo or branch).
- The audit report stays in chat.
- **Local fix application is a separate, opt-in action, not part of the audit.** After
  the report, the executor may ask to apply a recommended fix; that edits local
  working files only (never GitHub/Jira, never a push). It is the executor's own tool
  acting on their own tree — distinct from, and after, the read-only audit pass.
  Re-running the audit after edits judges the new state.

## Snapshot selection

- **Default — parity mode:** `base...HEAD` (committed branch diff) — exactly what the
  PR shows the reviewer at the same SHA, so results match `audit-pr`.
- **Flag — include working tree:** additionally judge staged + unstaged + untracked
  changes, so the executor can self-check before committing. Mark these "not yet what
  the PR will show until committed."
- **Dirty-tree warning:** when judging the committed default while uncommitted changes
  exist, state plainly that N files are outside the audit (commit or pass the flag).
- The panel always runs on a committed snapshot (a worktree needs a SHA); in
  working-tree mode the solo engine reads the working tree and the skill notes that the
  panel covered the committed snapshot.

**Base discovery** (must match what the PR will diff against):
- If a PR exists, the base is the PR's target branch — read it, do not assume `main`.
- If no PR exists, default to the merge base with the repo's default branch
  (`main`/`master`/whatever the repo uses), discovered, not hardcoded.
- The executor may override the base. Always state the base chosen, so a mismatch with
  the eventual PR target is visible.

## Modes

- **Delta mode (a prior published audit exists):** report the delta, not a re-derived
  full report. Produce:
  (a) a status table mapping each prior `Issue N` to `matches→fixed / partial /
  ignored→open` at the local snapshot (core §6), with a concrete fix recommendation
  for anything not fully fixed; and
  (b) a scan of the changes made since that audit for new problems — by the solo
  engine **and**, when agent-companion is enabled, by the panel (core §7), so
  readiness gates on the same new-problem detection `audit-pr` applies.
  Do **not** reproduce the reviewer's whole report.

  **Prior-audit anchor.** "Changes since that audit" needs an explicit anchor: the
  commit SHA the latest review was submitted against (derive it via the `$ANCHOR`
  binding above — the latest review's `commit_id`, falling back to the latest inline
  comment's `original_commit_id`). The new-changes scan covers `anchor … local
  snapshot` (`git diff "$ANCHOR"...HEAD`). A
  prior audit may be inline-only (no summary review) — inline comments still count;
  with multiple revisions, anchor to the **latest** review. If the local `HEAD` is
  behind the PR head (executor hasn't pulled), say so and stop rather than judge a
  stale snapshot.
- **First-pass mode (no published audit yet):** run the full first detection pass over
  the branch — the original "catch it before the reviewer does" goal. Applies both
  before any PR exists and when a PR exists but has not yet been reviewed.

"No new problems" is not zero work: confirming it still requires a scoped fresh
detection over the changes since the anchor (delta) or over the whole branch
(first-pass).

## Output

Chat-only. Render the core finding model (core §8) with a Problem / Why / How-to-fix
scaffold — `remediation` is rendered as a **concrete fix** (and the skill may offer to
apply it; see the read-only contract). This concrete rendering is the one deliberate
divergence from `audit-pr`; detection is identical.

Sections, in order:
1. **Prior-audit reconciliation table** (delta mode only) — Issue N → fixed / partial /
   open at the snapshot, with a concrete fix recommendation per unfinished item.
2. **New findings** — scaffold (Problem / Why / How-to-fix) per finding.
3. **Push-readiness verdict.**

**Push-readiness verdict.** "Ready" requires **every ask `done`** — both every prior
`Issue N` at `matches` (fixed) AND every tracker/original requirement satisfied — AND
no new blocker-severity finding (core §8). Any ask left `cannot-verify-offline` does
**not** count as ready: list it explicitly as unverifiable and downgrade the verdict to
"ready except for N unverifiable items" — never silently treat it as done. A skipped
panel (agent-companion off) is surfaced the same way (see Panel).

## Panel

If agent-companion is enabled, the panel runs — mandatory, same as `audit-pr`, per the
protocol in core §7. It matters **more** here: an executor auditing their own work has
a confirmation-bias blind spot an independent panel does not. Materialize the committed
snapshot as a detached worktree at its SHA using the `git worktree add --detach "$SNAP"`
binding above (read-only; `trap` cleanup). If
agent-companion is off or no verifier is available, run solo and say so explicitly
("ran without independent verification") — do not claim parity.

## Anti-patterns

- ❌ Any write to GitHub/Jira or any `git push`.
- ❌ Judging the diff instead of the file at the snapshot (core §2).
- ❌ Reproducing the reviewer's whole report in delta mode.
- ❌ Claiming "ready" while asks are `cannot-verify-offline` or the panel was skipped.
- ❌ Hardcoding conventions instead of discovering them per changed path (core §3).
- ❌ Inlining the detection core instead of referencing it.

## Checklist

- [ ] Local HEAD not behind the PR head (stale-checkout guard) — else stop.
- [ ] Base discovered/stated; snapshot selected; dirty tree warned if relevant.
- [ ] Tracker context fetched (all comments) or noted unavailable.
- [ ] PR discovered (read-only); mode chosen (delta vs first-pass).
- [ ] For every prior Issue, file read at the snapshot (`git show HEAD:{path}`), not the diff.
- [ ] Conventions opened for changed paths.
- [ ] Panel run if agent-companion enabled; solo + disclaimer otherwise.
- [ ] Findings in chat with concrete fix recommendations; no external writes.
- [ ] Push-readiness verdict with unverifiable/skipped items explicit.
