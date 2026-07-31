---
name: audit-pr
description: Use when the user asks to audit, review, or comment on a GitHub Pull Request — by PR number, URL, branch, or "current PR". Covers the full flow — fetch via gh (plus optional issue-tracker context), draft in chat, publish with consistent comment conventions, and resolve issues when fixes land. Works on any repository and any GitHub host.
---

# Audit PR (publish adapter)

End-to-end workflow for reviewing GitHub Pull Requests and publishing comments
via `gh`. Covers fetching, drafting, formatting conventions, publishing, and
resolution when fixes are pushed.

## Detection engine

Read `../../core/detection-core.md` first — it defines the sources, HEAD/snapshot
discipline, convention discovery, focus lenses and their criteria map, the per-ask
acceptance verdict, reconciliation states, the verifier-panel protocol, the neutral
finding model, revision-delta discipline, fix-impact verification, mechanism
propagation, the scope boundary, and the convergence condition.
This skill is the **publish adapter**: it binds those to a GitHub PR via `gh` (the
snapshot is the PR head SHA) and adds the comment-format, draft, publish, and
resolution machinery below. Where a step below names a detection rule, the core is
the authority; the commands here are the binding.

## Step 0 — Prerequisites: gh authentication

The skill needs the `gh` CLI installed and **authenticated** against the host
where the PR lives (github.com or a GitHub Enterprise host — same flow).

1. **Check authentication:**
   ```bash
   gh auth status
   ```
   If no account is configured, login is interactive — ask the user to run it
   themselves (in Claude Code, via the `!` prefix):
   > Please run: `! gh auth login`

2. **Resolve the target repository:**
   - If the user gave a full PR URL, parse `owner/repo` and the number from it.
   - Otherwise use the current repository:
     `gh repo view --json nameWithOwner -q .nameWithOwner`.
   - Address it everywhere via `--repo {owner}/{repo}`.
   - **Resolve the default branch too** — the stacked-branch discovery of core §9
     (Step 2) needs it:
     ```bash
     DEFAULT=$(gh repo view {owner}/{repo} --json defaultBranchRef -q .defaultBranchRef.name)
     ```
     NEVER hardcode `main` or `master` anywhere in this skill — the repository
     answers that question, not a convention.

3. **Multiple accounts / hosts.** A project may require a specific GitHub
   account (a separate work account or a bot). Two options — read them from the
   environment if set, do not invent a path:
   - switch account: `gh auth switch --hostname <host> --user <user>`;
   - or point `gh` at a dedicated config directory via the `GH_CONFIG_DIR`
     environment variable (honor it if already set; otherwise use the default
     `gh` config).

   **Non-default host (GitHub Enterprise).** `gh pr …` resolves the host from
   `--repo`, but the raw `gh api repos/…` calls in later steps have no `--repo`
   and target the default authenticated host. When the PR lives on a non-default
   host, export `GH_HOST={host}` for the session (or add `--hostname {host}` to
   each `gh api` call) so every call hits the PR's host. Derive `{host}` from the
   PR URL or `gh repo view {owner}/{repo} --json url -q .url`.

4. **Who appears as the comment author.** The token `gh` uses belongs to a real
   account (a human or a bot), and GitHub shows that account as the comment
   author. That is why every comment carries a disclosure prefix (§4.1). Get the
   active login:
   ```bash
   gh api user -q .login
   ```

## Step 0.5 — Issue-tracker context (Jira, optional)

Optional — enriches the audit with *what was asked*; it never blocks the audit.
**Trigger:** the PR branch encodes an issue key (default regex
`^[A-Z][A-Z0-9]+-[0-9]+`, adjust per project). No key in the branch name → skip
this step silently.

```bash
gh pr view {N} --repo {owner}/{repo} --json headRefName -q .headRefName
```

When triggered, read `../../references/jira-context.md` — credentials (environment
only), token safety, the fetch/parse commands with full comment pagination, and the
non-fatal failure modes. Summarize the tracker context as the first part of the
Step 3 draft.

## Step 1 — Confirm focus

If the user gave only a PR identifier, ask one question and wait:

> Focus?
> (a) architecture
> (b) conventions compliance
> (c) code quality (readability, duplication, complexity)
> (d) security
> (e) performance
> (f) everything

Skip the question if the focus is already named.

## Step 2 — Fetch the PR

The audit input is the union of sources defined in core §1 (tracker ticket + PR
metadata/diff + existing PR conversation). The commands below are this adapter's
binding for those sources; the "what and why" of gathering them — including the
all-comments/full-pagination rule and "skipping the existing conversation is a hard
bug" — lives in core §1. Always pull existing conversation **before** drafting.

```bash
# Metadata + target branch + head SHA
gh pr view {N} --repo {owner}/{repo}
gh pr view {N} --repo {owner}/{repo} --json headRefOid,baseRefName \
  -q '[.headRefOid, .baseRefName] | @tsv'
# Diff — authoritative ONLY when "Stacked-branch base discovery" below finds no
# parent. `gh pr diff` is computed against baseRefName, which is the wrong range
# for a stacked branch whose PR targets the default branch.
gh pr diff {N} --repo {owner}/{repo}

# Prior inline comments (every review, every revision).
# --paginate is REQUIRED — without it long PRs return only the first page and
# you will silently miss earlier review history.
gh api --paginate repos/{owner}/{repo}/pulls/{N}/comments \
  --jq '.[] | {id, user: .user.login, path, line, created_at, body}'

# Prior summary reviews
gh api --paginate repos/{owner}/{repo}/pulls/{N}/reviews \
  --jq '.[] | {id, user: .user.login, state, submitted_at, body}'

# Branch commits (to map "fixed" replies → fix SHA)
gh api --paginate repos/{owner}/{repo}/pulls/{N}/commits \
  --jq '.[] | {sha: .sha[0:7], message: .commit.message, date: .commit.author.date}'

# Per-thread resolution state (REST comments do NOT carry it; only GraphQL does).
# Needed for the "resolution state of each thread" input below and to know which
# prior issues are already resolved on GitHub.
gh api graphql --paginate -f query='
  query($owner:String!, $repo:String!, $pr:Int!, $endCursor:String) {
    repository(owner:$owner, name:$repo) {
      pullRequest(number:$pr) {
        reviewThreads(first:100, after:$endCursor) {
          nodes { isResolved comments(first:1){ nodes{ databaseId } } }
          pageInfo { hasNextPage endCursor }
        }
      }
    }
  }' -f owner={owner} -f repo={repo} -F pr={N} \
  --jq '.data.repository.pullRequest.reviewThreads.nodes[] | {comment_id: .comments.nodes[0].databaseId, isResolved}'
```

Record the **head SHA** — this is the snapshot under review (required for inline
comments). Identify changed files and open the conventions for those paths per core
§3 (convention discovery).

### Materialize the snapshot (worktree)

Always put the PR on disk at the exact head SHA — the searchers (below) and the
verifier panel read code from disk, and a detached worktree pins one snapshot for
everyone. Bindings: `../../references/pr-worktree.md` (existing-remote fetch for
fork heads, `--detach` at the SHA, `trap` cleanup). Reuse the same `HEAD_SHA` for
your own `contents`-API reads.

### Searcher fan-out (core §4)

Dispatch one subagent per active lens, plus one per surface-triggered domain the
changed files activate (endpoint/API → `api-contracts`, migration/schema → `data`,
failure handling / external calls → `reliability`), plus a **conventions** searcher
whose criteria are the convention files discovered per core §3. Each searcher's
package (core §4 — searchers never re-fetch):

- the asks (tracker requirements + open prior issues);
- the audited range and changed-file list (the revision delta on repeat audits,
  core §11);
- the worktree path — the searcher reads code itself, but pulls nothing from
  GitHub or the tracker;
- **only its own** criteria source: the mapped `auditing` domain skill, or the
  convention file paths.

Searchers return findings in the core §8 model; consolidate before drafting —
dedupe, scope-gate (core §14). With the `auditing` plugin absent, domain searchers
run on general knowledge — state once in the Step 3 digest that those lenses ran
without codified criteria (the conventions searcher is unaffected).

### Revision delta (core §11)

When any prior review exists, bind the anchor and the delta before drafting:

```bash
# Anchor = the commit the LATEST review was submitted against.
# --slurp combines all --paginate pages, so max_by is global, not per-page.
ANCHOR=$(gh api --paginate repos/{owner}/{repo}/pulls/{N}/reviews --slurp \
  --jq 'add | map(select(.commit_id)) | max_by(.submitted_at) | .commit_id')
# Fallback for inline-only prior audits: latest inline comment's commit.
[ -z "$ANCHOR" -o "$ANCHOR" = "null" ] && ANCHOR=$(gh api --paginate \
  repos/{owner}/{repo}/pulls/{N}/comments --slurp \
  --jq 'add | max_by(.created_at) | .original_commit_id')

# Every file changed since the last reviewed snapshot.
gh api repos/{owner}/{repo}/compare/${ANCHOR}...{head-sha} \
  --jq '{changed_files, files: [.files[].filename]}'
```

Read **every** file in that list at HEAD (`contents` API, as in "Reconciling prior
issues") — including files whose issues are all closed (core §11). The compare
endpoint's 300-file cap applies here too: when `files` hits 300 or `changed_files`
exceeds the returned count, say so in the digest.

### Stacked-branch base discovery (core §9)

**When `baseRefName` is not the default branch, skip this subsection entirely** — the
PR is already correctly stacked onto its parent, `gh pr diff` is authoritative, and
nothing changes. Run discovery **only** when `baseRefName == $DEFAULT` (Step 0),
which is the failure mode: a branch cut from a parent branch whose PR nevertheless
targets the default branch.

The rule, the outputs (`TRUE_BASE`, `PARENT_PR`, `INHERITED_FILES`), and the honesty
rules are **core §9**. When discovery runs, read
`../../references/stacked-discovery.md` for this adapter's bindings — candidate
listing, compare calls, truncation/unreachable handling, and the `TRUE_BASE` diff
range. When a parent is found, `gh pr diff` is NOT the audit subject — take the
range from `TRUE_BASE` per that file; with no parent, `gh pr diff` stays the subject
exactly as today.

### Reconciling prior issues

For every prior `Issue N` found in the comments, build a small reconciliation table
before drafting, mapping each to the core's canonical states (core §6):

| Issue | What was asked | Latest state @ HEAD | Action |
|-------|----------------|----------------------|--------|
| 1     | …              | matches / partial / ignored | resolve / follow-up / re-flag |

- **matches** → this audit closes the issue (Step 6); do NOT draft a new finding on
  the same topic.
- **partial** → follow-up on the SAME thread (don't open a parallel one) with the
  next `Issue N+1` number if it is a genuinely new sub-problem.
- **ignored** → re-flag in the new review, referencing the prior comment ("see Issue
  1 from rev 1") — never restart numbering.

Decide that state by reading the file at the head SHA per core §2 (HEAD discipline) —
which also lists what does NOT count as verification. Binding: fetch the file at the
head SHA and read the original issue against it yourself:
```bash
gh api repos/{owner}/{repo}/contents/{path}?ref={head-sha} -q .content | base64 -d
```

A `matches` verdict is **two-directional** (core §12): the original ask is satisfied
AND the state the fix created is sound — what it removed, what it now lets in, what
its call sites now receive. When the fix rewrote a contract (props/emits, an exported
API, a consumed type), read every consumer of that contract at HEAD before settling on
`matches`. And once a mechanism is confirmed anywhere, sweep the sibling changed files
(Step 2 file list, in the worktree) for the same pattern before drafting (core §13).

**BLOCKING — verification before drafting.** Fetch and read the file at HEAD for
every still-open prior issue **before** presenting the reconciliation table or the
draft. Closed issues (all three Step 6 mechanisms already applied) may be trusted
without re-fetching.

Publish-adapter rules on top of the core:

- **Numbering is continuous across revisions.** If rev 1 had Issue 1–3, rev 2's first
  new finding is Issue 4. Never reset to 1.
- **A prior summary review constrains new findings** (core §1) — acknowledge the
  PR-level decision, not just the ticket.
- **Author in-thread replies matter.** A "fixed" / "won't fix" / "deferred" reply
  changes what counts as open. Acknowledge such replies in the draft.

## Step 2.5 — User-proposed issues

The user may raise problems they noticed that the audit (and the agents) missed.
Treat each as a candidate, not a given:

1. **Investigate against HEAD yourself.** Fetch and read the relevant file at the
   head SHA and judge whether the suspicion is a real problem.
2. **If real** → add it as the next `Issue N` (continuous numbering), drafted per
   Step 4 like any other finding.
3. **If not real** → tell the user why, with evidence from the code at HEAD, and
   do NOT add it.

When agent-companion is enabled, do not decide on your solo investigation alone:
also route the suspicion through the panel for independent confirmation (companion
section below) and consolidate both before adding (real) or refuting (not real).

## Step 3 — Draft in chat first

NEVER publish to GitHub without showing the draft and getting explicit approval.
The user reviews tone, length, and content before each batch.

The draft has **three parts**, in this order:

1. **Tracker context block** (from Step 0.5) — show how you understood the task
   before reading the diff. Helps catch misalignment early. Skip if Step 0.5 was
   skipped.
2. **Review-state digest** — a concise, complete picture of where the PR stands,
   so the user can grasp everything at a glance before reading the full comment
   drafts. Lead with it. Every item traces to an `Issue N` and is judged against
   the code at HEAD (when the companion ran, this is its consolidated per-ask
   result). Use these buckets:
   ```
   ## Review state @ HEAD <sha>
   ✅ Closing — verified done:   Issue 5 (<commit>), Issue 7 (<commit>)
   🆕 New this review:            Issue 8 — <one line>,  Issue 9 — <one line>
   ⏳ Not fixed / partial / open: Issue 8 — partial: <one line>
   🎯 Asks (<ticket>):           <ask> ✅ · <ask> ✅ · <ask> ❌
   📮 Follow-ups (out of scope): <one line each — separate-ticket candidates, not Issues>
   🏁 Convergence:               converged — asks done, no open blockers / not yet: <what remains>
   ```
   Omit a bucket only if it is genuinely empty. Nothing the audit touched may be
   silently absent — if you are closing it, it is in ✅; if it is new, 🆕; if it
   still fails, ⏳; if it is real but out of ticket scope, 📮 (core §14). The 🏁 line
   is never omitted: state the core §15 condition every revision — and once it holds,
   the review closes; only a fix-introduced regression or a blocker may reopen it.

   **Stacked-branch line — only when Step 2 detected a `PARENT_PR`.** Directly under
   the `## Review state @ HEAD <sha>` heading, above the buckets:
   ```
   🧬 Stacked on PR <parent-N> (<parent-branch>) — audited range <TRUE_BASE>..<head-sha>
      <K> file(s) excluded as inherited · <T> candidate(s) skipped (unreachable) ·
      candidate list truncated: <yes/no> · file set truncated at 300: <yes/no>
   ```
   Then one line offering the guard workflow, e.g.:
   > This PR targets the default branch while its parent is unmerged. A copy-ready
   > workflow that fails a status check on exactly this condition ships with the
   > plugin at `references/stacked-pr-guard.yml` — copy it into the repository
   > yourself if you want it; this skill does not install it.

   Absent entirely when no parent was detected — no noise in the common case. Never
   raise the stacked condition as an `Issue N` (core §10); it is chat context, and
   merge blocking is the workflow's job.
3. **Audit findings** — the publish-ready drafts of inline comments + summary
   review per Step 4.

Show drafts as fenced markdown so the user sees exactly what will appear on
GitHub. The tracker context block and the review-state digest are **chat-only**;
they are not published.

### Optional — review the draft in Plannotator (if installed)

Probe with `command -v plannotator` — non-fatal; if it fails, skip this subsection
silently and use the plain chat checkpoint. When available, offer it as the review
surface for the draft: the user annotates specific lines in a browser UI instead of
replying in chat. It is a drop-in for the "present, then WAIT" checkpoint below —
the iterative-loop rules there still govern; Plannotator only changes *how* the
user reacts, never *whether* they must explicitly approve before Step 5.

Before rendering the file, read `../../references/plannotator-draft.md` — the
file-rendering rules (verbatim publishable bodies, Plannotator-only chrome, fence
handling), the file skeleton, the annotate command, and how to map the annotator's
result onto the Step 3 loop. Fall back to the chat checkpoint whenever Plannotator
is absent, the probe fails, or the user prefers chat.

### Present the draft, then WAIT — do not force a decision

After showing the draft, **stop and hand control back with an open prompt**
("review the draft above; tell me what to change, or say publish when it's good")
and wait for the free-form reply. Never pop a "Publish? yes/no" menu in the same
turn — the draft step is an **open, iterative checkpoint**: the user may take
several turns, reword or drop an issue, change scope, or raise a brand-new one
(Step 2.5); revise and show again, renumbering the surviving batch (§4.5) after
every change — a dropped draft never leaves a hole behind it. Move to Step 5 only
after **explicit** approval in the user's own words. A structured choice is fine
only once they have signalled readiness and the sole open question is *how* to
publish (`--comment` vs `--request-changes`).

## Step 4 — Comment format

Every published comment (inline + summary + general PR comment) follows the
conventions below.

> **Language.** Write comments in the repository's review language — match the
> language of the PR description and existing threads. The examples below are in
> English; adapt to the project.

### 4.1 — Body skeleton (disclosure + Issue heading)

Every inline comment body has the same fixed opening — **both lines, in this
order, every time**:
```
> _[Claude review] — automated audit published via Claude Code from account @<gh-username>_

### Issue N
```
…then a blank line, then the §4.2 scaffold. Two non-negotiable parts:

- **Disclosure prefix** (first line). Substitute the active `gh` login (Step 0).
  The token belongs to a human/bot, so GitHub shows them as author — the prefix
  keeps the AI origin explicit. (Wording may be adapted; the AI origin may not be
  dropped.)
- **`### Issue N` heading** (right after the prefix). MANDATORY on every inline
  comment, and on every issue block inside the summary review. Numbering rules are
  §4.5. A body with the disclosure prefix but no `Issue N` heading is malformed —
  composing the scaffold without first writing the heading is the easy mistake;
  write the heading first. Step 5 will not post a body that lacks it.

### 4.2 — Educational tone, expressed minimally

Each issue uses the same three-section scaffold — this adapter's rendering of the
core neutral finding model (core §8): `problem` → 🚫 Problem, `mechanism` → 💡 Why it
matters, `remediation` → 🔍 Where to dig. The scaffold IS the educational part — it
forces the reader to encounter the problem, its mechanism, and a direction. Inside
each section, write as little as possible to land the point. This adapter renders
`remediation` as a **named outcome without the edit** — never the final fix.

When a stack parent was detected (Step 2), which lines may carry a finding's evidence
is governed by **core §10** — read it there.

- 🚫 **Problem** — one sentence, what's wrong.
- 💡 **Why it matters** — the mechanism, and the cost. Two things only: how the
  wrong behaviour happens, and what it costs. State the mechanism in the code's
  own words — the option, flag, or call that produces it — never a paraphrase of
  what it lets happen.

  The cost sentence is MANDATORY. Which kind it is depends on the finding:
  - **It reaches the product** — say what a person using it sees, believes, or
    loses. Check for this first; it is the default.
  - **It does not reach the product** (structure, naming, dead exports, types) —
    say what the current shape makes more expensive or riskier to change, as a
    fact about the code: what must change together, what a search will not find,
    what a name hides. Never invent a person to carry it. If the sentence needs
    the word "developer" to work, it is a story, not a cost — rewrite it about
    the code.

  Nothing else goes here: not a cross-reference to another issue, not the
  history of where a value moved in this PR, not the fix. Hard ceiling 3
  sentences — count them.

  Cost, both kinds:
  - ❌ "Both values look like real data and cannot be told apart from outside."
    — states no cost at all
  - ✅ "The user reads `0` as a real score of zero, not as data that failed to
    load."
  - ❌ "A developer who searches for `profileStats` by filename will not find
    it." — an invented person
  - ✅ "`stats.ts` exports `profileStats()`; the export is not reachable by
    filename and the two can drift with nothing to catch it."
  - ❌ "`stats.ts:12-14` deliberately lets this request not go through." — a
    paraphrase; name the option that does it
- 🔍 **Where to dig** — name the outcome, never the edit. Say what must become
  true, using the real names: which entity is wrong, which property must change,
  or which layer the decision belongs in. Then stop. Do not supply the change
  itself — no corrected code, no before/after substitution, no ordered refactor
  steps. When the outcome is architectural (move a decision to another layer,
  split a component, make something reusable), naming the outcome IS the whole
  section; the shape of the refactor is the reviewer's. When more than one
  outcome is acceptable, present them as alternatives from the first word
  ("Either X, or Y") — never one stated as an instruction and the other appended
  after an "or", which reads as the first sentence contradicting itself.

  Outcome vs edit:
  - ❌ "use `hidden md:flex` on `Button`" — that is the edit
  - ✅ "`Button` must be hidden below `md`; the wrapper already decides
    visibility by breakpoint"
  - ❌ "add `required: true` to `stats`" — that is the edit
  - ✅ "`stats` must not be optional, or the decision to render `ProfileButton`
    must move to the component that knows whether stats exist"

DO NOT include the final corrected code. The reader must always finish the section
knowing WHAT has to change; how to change it is theirs to work out. An issue the
reader can read twice and still not know what is being asked of them has failed,
however educational it feels.

**Target ≤ 8–10 lines of body text per issue** (excluding disclosure prefix and
code-quote blocks). If you exceed that, you're explaining, not pointing.

**Optional supplementary markers** — only when they carry information the
scaffold can't, one per issue at most: `🎯 Architectural`, `📌 Side note`,
`⏳ If left as-is`. If a marker doesn't carry weight, omit it.

**One confidence per issue.** Every sentence in the body carries the same
certainty about whether the failure happens. A finding whose harm depends on a
precondition you could not check is not confirmed: either verify the
precondition, or state it once in 🚫 as part of what is wrong. Never assert the
harm in 💡 and then take it back in ⏳, a footnote, or a parenthetical, and never
in the first person ("I could not check this offline") — the issue reads as if
written cold.

**Do not embed chat Q&A.** The drafting conversation (the user's questions, your
clarifications, "out of scope" notes) is for refining the draft only — it MUST
NOT leak into the published body. The issue reads as if written cold.

### 4.3 — Soft convention references

Convention files are written for AI agents — verbatim quotes feel robotic in a
human PR comment. Say "project conventions don't allow this" rather than quoting.
Name a convention file only if the reader genuinely needs to open it.

### 4.4 — Emoji markers (visual structure)

GitHub has no coloured text, so emojis are the only scan-friendly differentiator.
Fixed scheme, same meaning every time:

| Emoji | Meaning |
|-------|---------|
| ⚠️ | **Blocker** severity label |
| 🚫 | Problem |
| 💡 | Why it matters |
| 🔍 | Where to dig |
| 🎯 | Architectural |
| 📌 | Side note |
| ⏳ | If left as-is (consequence) |
| ✅ | Resolved |
| 📋 | Checklist (summary only) |
| 📮 | Follow-up — out of ticket scope (digest + summary only) |
| 🏁 | Convergence state (digest only) |

One marker per section heading. Do not sprinkle into prose.

### 4.5 — Issue numbering

- Format: **`Issue N`** — NO hash. GitHub auto-links `#N` to other PRs.
- **A number is claimed at publish, never in the draft.** Only a number that
  reached GitHub is spent. A finding the user drops during the Step 3 loop takes
  its number with it — it does not burn a slot.
- **Renumber the surviving drafts after every revision of the draft.** Dropping,
  merging or adding a finding in Step 3 re-runs the assignment below over the
  whole surviving batch. Numbers move; the user sees the final ones before
  approving.
- **Assignment.** Sort the surviving batch by the position the reader meets it:
  inline findings first, by file path in the order `gh pr diff` lists the files,
  then by line within a file; findings that live only in the summary review come
  after all inline ones. Number that sorted list contiguously, starting at
  `max(published Issue N) + 1` across all prior revisions — 1 on the first
  revision.
- **Publish in that same order** (Step 5 posts inline comments one by one) so both
  the Files-changed and the Conversation tab read ascending.
- **Continuous numbering across revisions.** Published issues keep their numbers
  forever, resolved or not; a later revision never reuses or reassigns them and
  never resets to 1.
- **No gaps inside a revision.** A gap in the batch you are about to publish means
  a dropped draft's number survived it — renumber before the pre-publish guard.
  (Gaps across revisions are impossible, because published numbers are never
  withdrawn.)
- **Always number AND always include the checklist — even for a single issue.**
  The checklist (§4.8) lists issues in ascending number order.

### 4.6 — Cross-references and commit links

`{host}` below is the PR's GitHub host — `github.com` or a GitHub Enterprise host.
Derive it once from the repo URL rather than writing a literal host: take
`gh repo view {owner}/{repo} --json url -q .url` and use its host component.

When one comment references another, link it:
```
[Issue 1](https://{host}/{owner}/{repo}/pull/{N}#discussion_r{comment_id})
```
`comment_id` comes from the `id` field of the POST response when the inline
comment was created.

When you reference a commit, make the SHA clickable too:
```
[`{short-sha}`](https://{host}/{owner}/{repo}/commit/{full-sha})
```

### 4.7 — Scope and follow-ups (core §14)

Only in-scope findings become `Issue N`. A `follow-up` finding (core §14) is rendered
**once**, in the summary review body, under its own heading placed before the
checklist:

```
### 📮 Follow-ups (out of ticket scope, non-blocking)

- <one line each: the observation and the suggested separate ticket>
```

No `Issue N` number, no checklist row, no inline comment — and never repeated in a
later revision's summary. An architectural relocation raised as an `Issue N` on a
narrow ticket, when the diff did not introduce the problem, is exactly what this
section exists to stop.

### 4.8 — Summary review ends with a checklist

The summary body always ends with the checklist (even for a single issue):
```
### 📋 Checklist

- [ ] [**Issue 1**](inline-url) — concrete action: which file, which change
- [ ] **Issue 2** — concrete action (no link if the issue lives in the summary)
```
One sentence per line, action only — not a re-description of the problem. Ascending
by number, which puts the summary-only issues last (§4.5).

## Step 5 — Publish

**Pre-publish guard (do this first).** For every body you are about to POST or
PATCH, confirm it carries both its disclosure prefix AND its `### Issue N` heading
(§4.1). This is the single most common slip — bodies composed straight from the
scaffold lose the number. Do not post any body that fails the check; add the
heading first.

Then read the batch's numbers as a list: they must be contiguous and ascending
from `max(published Issue N) + 1`. A gap or a number out of diff order means the
Step 3 loop dropped or added a finding without renumbering (§4.5) — fix the bodies
and the checklist before posting anything.

Order of operations:

1. Post inline comments first (one POST per issue, in ascending issue number,
   which is diff order per §4.5); record each returned `id` and `html_url`.
2. Patch any inline-comment bodies that need cross-links to siblings (you only
   know the URLs after they exist).
3. Post the summary review last, with all checklist URLs filled in.

### Inline comment
```bash
gh api repos/{owner}/{repo}/pulls/{N}/comments --method POST \
  -f commit_id='{head-sha}' \
  -f path='{relative-path}' \
  -F line={line-number} \
  -f side=RIGHT \
  -f body=$'...'
```
`-F` (capital) for numeric args, `-f` for strings. Use `$'...'` bash quoting for
multi-line bodies with `\n` escapes.

### Summary review
```bash
gh pr review {N} --repo {owner}/{repo} --request-changes --body $'...'
```
Use `--comment` if there are no blockers. Default to `--request-changes` when at
least one blocker exists, `--comment` otherwise.

### Patching an existing comment / review
```bash
gh api repos/{owner}/{repo}/pulls/comments/{comment_id} --method PATCH -f body=$'...'
gh api repos/{owner}/{repo}/pulls/{N}/reviews/{review_id} --method PUT  -f body=$'...'
```

## Step 6 — Resolution when fixes land

Apply ALL THREE mechanisms per closed issue. Two triggers: **proactive** (Step 2
reconciliation found `matches`) and **reactive** (the user says "Issue N fixed" —
verify first, then close).

### Verify first
```bash
gh api repos/{owner}/{repo}/contents/{path}?ref={head-sha} -q .content | base64 -d
```
Read the file at HEAD against the original issue yourself — in both directions (core
§12): the ask is satisfied AND the state the fix created is sound. For a contract
rewrite, read every consumer of the contract at HEAD; then sweep sibling changed
files for the same mechanism (core §13). `gh pr diff` is not enough. Never close on
the user's word alone or on a `[x]` row.

### Close — the three mechanisms

Read `../../references/resolution.md` for the exact bodies and calls, then apply
per closed issue, in order: verify → **Mechanism 2** (inline banner + collapsed
original) → **Mechanism 1** (strikethrough checklist row in EVERY summary review
that lists the issue — BLOCKING: the review `PUT` prompts for permission; batch all
review IDs in one message; a `[x]` without `~~...~~ ✅ commit` is not a resolution)
→ **Mechanism 3** (GitHub native resolve via GraphQL). Partial resolution: apply
the mechanisms only to closed issues; leave open ones untouched.

## Verification via agent-companion (when enabled)

When agent-companion mode is active, run the audit past its verifier panel before
drafting (it slots **between Step 2 and Step 3**). The panel protocol — what raw
context to hand it, that it runs a per-ask acceptance review AND flags new problems,
and how to treat the verdicts critically — is **core §7**. When the companion is off,
skip this section; the skill runs solo as described above.

The worktree already exists — Step 2 materialized it; you, the searchers, and the
panel judge one snapshot. Hand each verifier the core §7 package: the **raw
context** (full tracker ticket, full PR conversation, the asks, the worktree path)
**plus the criteria** — the active domain-skill contents and the discovered
convention file paths, framed floor-not-ceiling — and **never your or the
searchers' conclusions**. Treat the result with **strict acceptance**: the audit is
not "done" if any ask is partial/not_done or the PR introduces a new blocker.
Consolidate per core §7: searcher∩panel = confirmed; single-source findings you
judge critically. Fold the outcome into your reconciliation and the Step 3 draft
(as findings, not ready-to-publish comments); if the panel surfaces an issue you'd
marked closed, revisit that row. If the panel can't run at all, say so and continue
solo.

### User-proposed issues

Run a Step 2.5 suspicion past the panel the same way: provide the user's
description (raw) and the worktree, and let the companion verify it independently
under whichever mode its protocol selects. Confirmed → add as the next `Issue N`;
refuted → tell the user with evidence and do not add.

## Anti-patterns

- ❌ Publishing without explicit approval of a shown draft — including forcing a
  "Publish? yes/no" menu in the same turn as the draft.
- ❌ Drafting without first reading the existing PR conversation, or echoing the
  tracker token anywhere.
- ❌ `Issue #1` instead of `Issue 1` (`#` auto-links to other PRs); a body without
  its `### Issue N` heading; resetting or reassigning published numbers; treating a
  dropped draft's number as spent; numbering in discovery order instead of diff
  order (§4.5).
- ❌ Final corrected code in a comment; a recipe-style "Where to dig"; or one so
  vague ("this pair", "that layer") the reader cannot say what must change.
- ❌ A "Why it matters" with no cost sentence, a cost carried by an invented person,
  a cross-reference or diff-history filler, or an issue that asserts a failure in
  one section and doubts it in another.
- ❌ Closing an issue without reading the file at HEAD; on the original ask alone
  without the fix-impact check (core §12); or closing a contract rewrite without
  reading its consumers.
- ❌ On a repeat audit, reading only files with open issues — the reading list is
  the revision delta (core §11); or skipping the sibling-file sweep for a confirmed
  mechanism (core §13).
- ❌ Raising an out-of-scope structural finding as an `Issue N` instead of a
  follow-up (core §14), or adding new non-blocker findings after convergence
  (core §15).
- ❌ Applying a domain skill's whole-codebase criteria beyond the delta, or claiming
  codified criteria were applied when the `auditing` plugin was absent (core §4).
- ❌ A searcher re-fetching PR or tracker data instead of using the manager's
  package, or receiving another lens's criteria (core §4).
- ❌ Adding a user-proposed issue without investigating it against HEAD first
  (Step 2.5).
- ❌ **(companion)** Handing the panel your or the searchers' conclusions — criteria
  yes, findings never (core §7) — or leaving the worktree behind (the `trap`
  cleans up).

## Checklist (one audit cycle)

- [ ] `gh auth status` OK; repository + default branch resolved; focus confirmed.
- [ ] Tracker context fetched (Step 0.5) — or noted as unavailable.
- [ ] PR fetched: head SHA + `baseRefName` recorded; existing conversation fully
      paginated; prior `Issue N`s mapped before drafting.
- [ ] If `baseRefName` is the default branch: stacked-parent discovery run (core §9);
      when found, diff taken from `TRUE_BASE`, parent/range/inherited/truncation
      stated in the digest.
- [ ] Worktree materialized at the head SHA (Step 2); removed via `trap` after the
      audit.
- [ ] Searchers dispatched — one per active lens + surface-triggered domains +
      conventions, each with the package and only its own criteria (core §4);
      findings consolidated (dedupe, scope-gate). Uncodified lenses disclosed in
      the digest.
- [ ] Repeat audit: anchor bound; every file in the revision delta read at HEAD,
      regardless of issue state (core §11).
- [ ] Still-open prior issues read at HEAD (not the diff); closures verified in both
      directions, contract rewrites at every consumer, mechanism sweep run
      (core §12–13).
- [ ] User-proposed issues investigated against HEAD (Step 2.5; through the panel
      when the companion is enabled).
- [ ] Project conventions opened for changed paths.
- [ ] **(if companion)** panel run on the Step 2 worktree with raw context +
      criteria (never conclusions); searcher∩panel consolidation done; gate
      handled.
- [ ] Findings scope-gated — follow-ups unnumbered, rendered once (core §14);
      convergence checked and stated in the 🏁 line (core §15).
- [ ] Draft presented (digest first; Plannotator if installed); user explicitly
      approved.
- [ ] Pre-publish guard: disclosure prefix + `### Issue N` heading on every body
      (§4.1); numbers contiguous, ascending, in diff order (§4.5).
- [ ] Inline comments posted (`id` + `html_url` recorded); summary posted
      (`--request-changes` if blockers); final state verified.
