---
name: auditing-prs
description: Use when the user asks to audit, review, or comment on a GitHub Pull Request — by PR number, URL, branch, or "current PR". Covers the full flow: fetch via gh (plus optional issue-tracker context), draft in chat, publish with consistent comment conventions, and resolve issues when fixes land. Works on any repository and any GitHub host.
---

# Auditing PRs

End-to-end workflow for reviewing GitHub Pull Requests and publishing comments
via `gh`. Covers fetching, drafting, formatting conventions, publishing, and
resolution when fixes are pushed.

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

This step is **optional** and only enriches the audit with *what was asked*.
If no tracker is configured, skip it cleanly and proceed — it never blocks the
audit.

1. **Trigger.** The PR branch encodes an issue key. Default regex
   `^[A-Z][A-Z0-9]+-[0-9]+` (adjust per project). No key in the branch name →
   skip this step silently.
   ```bash
   gh pr view {N} --repo {owner}/{repo} --json headRefName -q .headRefName
   ```

2. **Credentials — read from the environment only; never store or print them:**
   - `JIRA_BASE_URL` — e.g. `https://your-org.atlassian.net`
   - `JIRA_EMAIL` — the account email
   - `JIRA_API_TOKEN` — an **Atlassian API token** (create at
     `id.atlassian.com` → Security → *Create API token*), used with HTTP Basic
     auth in the form `email:token`.

   How these reach the environment is the user's choice (direnv, shell profile,
   a secrets manager, CI secrets). The skill only reads them.

3. **Token safety.** Never echo the token into chat, drafts, comments, or logs.
   Pass it only inside the `-u` argument of `curl`. If you must show a command to
   the user, redact it (`-u "$JIRA_EMAIL:***"`).

4. **Fetch the issue** (summary, status, type, assignee, description, comments):
   ```bash
   curl -s -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
     -H "Accept: application/json" \
     "$JIRA_BASE_URL/rest/api/3/issue/{KEY}?fields=summary,status,issuetype,assignee,description,comment"
   ```

5. **Parse.** `summary`, `status.name`, `issuetype.name`, `assignee.displayName`
   come straight from JSON. `description` and each `comment.body` are ADF
   (Atlassian Document Format); extract plain text with:
   ```bash
   jq -r '[.. | objects | select(.type? == "text") | .text] | join(" ")'
   ```
   Take **all** comments — the full ticket context matters both for the audit and
   for independent verification by the companion panel (§ "Verification via
   agent-companion"). The `fields=comment` form may return only the first page of
   comments on heavily-discussed issues; if the returned `comment.total` exceeds
   the items present, page the dedicated endpoint
   `$JIRA_BASE_URL/rest/api/3/issue/{KEY}/comment?startAt=…&maxResults=…` until
   you have them all.

6. **Failure modes — all non-fatal:**
   - 401/403 → credentials missing or token expired: tell the user and proceed
     without tracker context.
   - 404 → the branch looks like a key but the issue does not exist: note it in
     the draft and proceed.
   - Network error → same: note and proceed.

7. **Summarize the tracker context as the first part of the Step 3 draft.**

> **Other trackers.** Jira is the concrete example here. For another tracker keep
> the same shape: optional "what was asked" context, credentials from the
> environment only, all failures non-fatal.

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

The audit input is the **union of three sources**, fetched up-front:

1. **Tracker issue** — original ask + comments (Step 0.5, if available).
2. **PR metadata + diff** — what the code now does.
3. **Existing PR conversation** — prior review comments, prior summary reviews,
   in-thread replies from the author ("fixed", "won't fix", …), and the
   resolution state of each thread.

Skipping (3) is a hard bug: a "fresh" audit will re-flag issues that were already
raised and addressed, or contradict guidance the user gave in an earlier
revision. Always pull existing conversation **before** drafting.

```bash
# Metadata + diff + head SHA
gh pr view {N} --repo {owner}/{repo}
gh pr diff {N} --repo {owner}/{repo}
gh pr view {N} --repo {owner}/{repo} --json headRefOid -q .headRefOid

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

Record the **head SHA** — required for inline comments. Identify changed files
and open the project's conventions/contribution docs relevant to those paths
(e.g. `CONTRIBUTING.md`, `CONVENTIONS.md`, `CLAUDE.md`, directory READMEs).
Specialized guides add rules on top of ancestors; read both.

### Analysing the existing conversation

For every prior `Issue N` found in the comments, build a small table before
drafting:

| Issue | What was asked | Latest state in code | Action |
|-------|----------------|----------------------|--------|
| 1     | …              | matches / partial / ignored | resolve / follow-up / re-flag |

- **matches** → this audit closes the issue (Step 6); do NOT draft a new finding
  on the same topic.
- **partial** → follow-up on the SAME thread (continue the conversation, don't
  open a parallel one) with the next `Issue N+1` number if it is a genuinely new
  sub-problem.
- **ignored** → re-flag in the new review, but reference the prior comment ("see
  Issue 1 from rev 1") — never restart numbering.

**The code at HEAD is the only authority on the "Latest state" column.** Do NOT
decide `matches / partial / ignored` based on:

- a `[x]` checkbox in a prior summary checklist (only says "marked resolved at
  the time");
- a strikethrough row or "✅ fixed in commit …" marker (same — a claim, not
  proof);
- an author "fixed" reply on the thread (a claim, not proof);
- the absence of a re-flag in a later review (the prior reviewer may have missed
  it);
- **`gh pr diff` output** — it shows the base→HEAD delta, not the current shape
  of the file. A line can look right in the diff and still be wrong in context.
  Reading the diff is NOT verification.

For every still-open prior `Issue N`, fetch the relevant file at `headRefOid` and
read the original issue description against the current code yourself:
```bash
gh api repos/{owner}/{repo}/contents/{path}?ref={head-sha} -q .content | base64 -d
```

**BLOCKING — verification before drafting.** When the user asks for an audit,
self-verification is part of the audit, not an optional follow-up. You MUST fetch
and read the file at HEAD for every still-open prior issue **before** presenting
the reconciliation table or the draft. The user should never have to ask "did you
check?". Closed issues (all three Step 6 mechanisms already applied) may be
trusted without re-fetching.

Rules that fall out of this:

- **Numbering is continuous across revisions.** If rev 1 had Issue 1–3, rev 2's
  first new finding is Issue 4. Never reset to 1.
- **A prior summary review constrains new findings.** If an earlier review
  specified the expected shape, the tracker ticket alone is NOT the source of
  truth — the PR-level decision overrides. Read both before drafting.
- **Author in-thread replies matter.** A "fixed" / "won't fix" / "deferred"
  reply changes what counts as open. Acknowledge such replies in the draft.

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

The draft has **two parts**, in this order:

1. **Tracker context block** (from Step 0.5) — show how you understood the task
   before reading the diff. Helps catch misalignment early. Skip if Step 0.5 was
   skipped.
2. **Audit findings** — drafts of inline comments + summary review per Step 4.

Show drafts as fenced markdown so the user sees exactly what will appear on
GitHub. The tracker context block is **chat-only**; it is not published.

## Step 4 — Comment format

Every published comment (inline + summary + general PR comment) follows the
conventions below.

> **Language.** Write comments in the repository's review language — match the
> language of the PR description and existing threads. The examples below are in
> English; adapt to the project.

### 4.1 — Disclosure prefix

Every body starts with this line, followed by a blank line:
```
> _[Claude review] — automated audit published via Claude Code from account @<gh-username>_
```
Substitute the active `gh` login (Step 0). Because the token belongs to a
human/bot, GitHub shows them as the author — the prefix makes the AI origin
clear. (The prefix wording may be adapted, but the AI origin must stay explicit.)

### 4.2 — Educational tone, expressed minimally

Each issue uses the same three-section scaffold. The scaffold IS the educational
part — it forces the reader to encounter the problem, its mechanism, and a
direction. Inside each section, write as little as possible to land the point.

- 🚫 **Problem** — one sentence, what's wrong.
- 💡 **Why it matters** — root cause / mechanism. 1–3 sentences; one short
  paragraph is the ceiling.
- 🔍 **Where to dig** — direction only, never a recipe. Either point to a
  reference file where the correct shape already lives, or describe the principle
  to apply. NEVER name the exact class, prop, attribute, refactor step, or
  before/after substitution — the reviewer must arrive at the fix themselves.

  Recipes vs directions:
  - ❌ "use `hidden md:flex` on `Button`"
  - ❌ "this should be `min-h`, not `h`"
  - ✅ "toggle visibility by breakpoint, like the rest of the wrapper"
  - ✅ "sizing is the wrapper's responsibility; see how other shared wrappers
    handle it"

DO NOT include the final corrected code. The reader arrives at the fix by reading
the reference or applying the principle — that is where the "educational" comes
from.

**Target ≤ 8–10 lines of body text per issue** (excluding disclosure prefix and
code-quote blocks). If you exceed that, you're explaining, not pointing.

**Optional supplementary markers** — only when they carry information the
scaffold can't, one per issue at most: `🎯 Architectural`, `📌 Side note`,
`⏳ If left as-is`. If a marker doesn't carry weight, omit it.

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

One marker per section heading. Do not sprinkle into prose.

### 4.5 — Issue numbering

- Format: **`Issue N`** — NO hash. GitHub auto-links `#N` to other PRs.
- **Continuous numbering across revisions.** Resolved issues keep their numbers
  forever.
- **Always number AND always include the checklist — even for a single issue.**

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

### 4.7 — Summary review ends with a checklist

The summary body always ends with the checklist (even for a single issue):
```
### 📋 Checklist

- [ ] [**Issue 1**](inline-url) — concrete action: which file, which change
- [ ] **Issue 3** — concrete action (no link if the issue lives in the summary)
```
One sentence per line, action only — not a re-description of the problem.

## Step 5 — Publish

Order of operations:

1. Post inline comments first (one POST per issue); record each returned `id` and
   `html_url`.
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
Read the file at HEAD against the original issue yourself. `gh pr diff` is not
enough. Never close on the user's word alone or on a `[x]` row.

### Mechanism 1 — checklist row

Update the body of **every** summary review that lists the issue (not just the
latest) — via the review-update call shown above. Change the matching row to:
```
- [x] ~~[**Issue N**](inline-url) — original action~~ ✅ fixed in [`{short-sha}`](https://{host}/{owner}/{repo}/commit/{full-sha})
```
Strikethrough preserves history; the resolution note carries a clickable SHA.

**Mechanism 1 is BLOCKING.** The harness treats `PUT .../reviews/{id}` as editing
a pre-existing PR review on the user's account and will prompt for permission.
That is expected. Surface it in one batched message naming every review ID you
need to update (rev 1, rev 2, …) so they approve in one shot. A `[x]` without
`~~...~~ ✅ commit` is not a resolution.

### Mechanism 2 — inline comment banner

PATCH the inline comment body. Prepend a banner and collapse the original:
```
> ✅ **RESOLVED** in commit [`{short-sha}`](https://{host}/{owner}/{repo}/commit/{full-sha}) (rev {N})

<details>
<summary>Original review (click to expand)</summary>

{original body — keep the disclosure prefix and full content}

</details>
```

### Mechanism 3 — GitHub native "Resolve conversation"
```bash
# --paginate follows the reviewThreads cursor, so this works on PRs with more
# than 100 threads; without it you may miss the target thread on a long PR.
THREAD_ID=$(gh api graphql --paginate -f query='
  query($owner:String!, $repo:String!, $pr:Int!, $endCursor:String) {
    repository(owner:$owner, name:$repo) {
      pullRequest(number:$pr) {
        reviewThreads(first:100, after:$endCursor) {
          nodes { id comments(first:1){ nodes{ databaseId } } }
          pageInfo { hasNextPage endCursor }
        }
      }
    }
  }' -f owner={owner} -f repo={repo} -F pr={N} \
  -q ".data.repository.pullRequest.reviewThreads.nodes[] | select(.comments.nodes[0].databaseId == {COMMENT_ID}) | .id")

gh api graphql -f query='
  mutation($id:ID!){ resolveReviewThread(input:{threadId:$id}){ thread{ isResolved } } }' \
  -f id="$THREAD_ID"
```
`COMMENT_ID` is the numeric `id` from the inline comment POST response.

Order: verify → Mechanism 2 → Mechanism 1 → Mechanism 3. Partial resolution:
apply the three mechanisms only to closed issues; leave open ones untouched.

## Verification via agent-companion (when enabled)

When agent-companion mode is active, run the audit past its verifier panel for an
independent check: does the PR deliver the task, is every prior Issue closed, does
it introduce new problems? When the companion is off, skip this section — the
skill runs solo as described above.

It slots in **between Step 2 (your own reconciliation done) and Step 3 (the
draft)**.

This skill's only job here is to **adapt the PR to how the companion works** —
gather the inputs and put the PR code where the panel can read it — and then
**defer to the agent-companion manager protocol** to actually run the
verification. How the panel is dispatched (its command, modes, request format,
and verdict/exit contract) is the companion's concern, not this skill's; follow
the companion protocol for it.

### What this skill must provide (its side of the contract)

1. **The PR code on disk.** The panel verifies code in the local repository, so
   materialize the PR as a detached worktree at the exact head SHA and point the
   verification at it as its scope:
   ```bash
   # Fetch the PR head by the resolved repo URL — do NOT assume a local remote
   # named "origin" points at {owner}/{repo} (it may be a fork, mirror, or absent).
   REPO_URL=$(gh repo view {owner}/{repo} --json url -q .url)
   git fetch "$REPO_URL" "pull/{N}/head"            # works for fork PRs too
   HEAD_SHA=$(git rev-parse FETCH_HEAD)             # pin to what was just fetched
   WT="$(mktemp -d)/pr-{N}"
   git worktree add --detach "$WT" "$HEAD_SHA"
   trap 'git worktree remove --force "$WT" 2>/dev/null' EXIT   # clean up always
   ```
   `--detach` at the exact fetched SHA means a head that moves mid-audit can't
   change what was verified. Reuse this `HEAD_SHA` for your own `contents`-API
   reads so you and the panel judge one snapshot.

2. **Raw context, never your conclusions** (the independence invariant). Provide
   the full tracker ticket (summary + description + all comments) and the full PR
   conversation (every Issue with its original wording, author replies, the diff)
   verbatim, plus the list of asks. Do NOT provide your own verdicts ("confirm
   Issue 2 is fixed in file X") — give the task and the code and let each verifier
   reach its own conclusion against the code at HEAD.

3. **What you want judged.** Each ask, independently: delivered / partial / not
   done (against HEAD, with evidence), plus any new problems the PR introduces.

### How to treat the result

- **Strict acceptance:** the audit is not "done" if any ask is partial or not
  done, or the PR introduces a new blocker.
- Fold the panel's findings into your reconciliation and the Step 3 draft — as
  findings, not ready-to-publish comments; if it surfaces an issue you'd marked
  closed, revisit that row before drafting.
- Scrutinize the verdicts — don't accept them blindly; on reasoned disagreement,
  escalate to the user.
- If the panel can't run at all, say so and continue with the solo audit.

### User-proposed issues

Run a Step 2.5 suspicion past the panel the same way: provide the user's
description (raw) and the worktree, and let the companion verify it independently
under whichever mode its protocol selects. Confirmed → add as the next `Issue N`;
refuted → tell the user with evidence and do not add.

### Cleanup

Remove the worktree **after** synthesis + the gate + any drill-down into raw
verdicts by `file:line` — via the `trap`. Publishing (Step 5) does not need the
worktree: it uses the GitHub head SHA via the `contents` API.

## Anti-patterns

- ❌ Calling `gh` without authentication against the right host/account.
- ❌ Publishing comments without showing drafts in chat first.
- ❌ Writing `Issue #1` instead of `Issue 1` — `#` auto-links to other PRs.
- ❌ Including the final fixed code in a comment.
- ❌ Recipe-style "Where to dig" — exact names, "use X instead of Y", named
  refactor steps. Direction only.
- ❌ Marking an issue resolved without reading the file at HEAD.
- ❌ Resetting issue numbers between revisions.
- ❌ Drafting an audit without first reading existing PR comments / reviews.
- ❌ Echoing or logging the tracker token.
- ❌ Adding a user-proposed issue without investigating it against HEAD first.
- ❌ **(companion)** Handing the panel your conclusions instead of raw context —
  it destroys independence.
- ❌ **(companion)** Re-implementing the companion's mechanics here (dispatcher,
  modes, exit codes) instead of deferring to its manager protocol.
- ❌ **(companion)** Leaving the worktree behind — always clean up via the `trap`.

## Checklist (one audit cycle)

- [ ] `gh auth status` OK; repository resolved.
- [ ] Focus confirmed.
- [ ] Tracker context fetched (Step 0.5) — or noted as unavailable.
- [ ] PR fetched: `view` + `diff` + head SHA recorded.
- [ ] Existing conversation fetched; prior `Issue N`s mapped before drafting.
- [ ] For every still-open prior `Issue N`, the file read at HEAD (not the diff).
- [ ] User-proposed issues investigated against HEAD (Step 2.5) — and, if the
      companion is enabled, routed through the panel for independent confirmation
      (see "User-proposed issues" in the companion section) before being added or
      refuted.
- [ ] Project conventions opened for changed paths.
- [ ] **(if companion)** worktree at head SHA; panel run; gate handled; worktree
      cleaned up.
- [ ] Draft shown in chat; user approved.
- [ ] Inline comments posted; `id` + `html_url` recorded.
- [ ] Summary posted (`--request-changes` if blockers).
- [ ] Final state verified.
