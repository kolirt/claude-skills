# prepush-audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an executor-side `prepush-audit` skill to the `auditing-prs` plugin that detects the same problems the reviewer's `audit-pr` skill would, by sharing one detection core instead of a drifting copy.

**Architecture:** The `auditing-prs` plugin keeps its name and gains a shared, non-skill reference file `core/detection-core.md` (the detection engine) plus two thin adapters: `audit-pr` (the renamed existing publish skill) and `prepush-audit` (new, local, read-only, chat-only). Both `SKILL.md` files open by reading the core, then bind their own input/output.

**Tech Stack:** Markdown skill files; plugin manifest JSON; `gh` CLI (read-only in prepush); `git` worktrees; agent-companion verifier panel.

## Global Constraints

- Plugin directory and manifest `name` stay `auditing-prs` — only the skills inside are renamed/added. (spec: Architecture)
- The shared core is referenced by adapters, **never inlined/copied** — copying re-creates the drift this design exists to prevent. (spec: Why shared-core)
- Nothing detection-related stays in an adapter; nothing publish/output-specific leaks into the core. (spec: §2 acceptance)
- `prepush-audit` performs **no** GitHub/Jira writes and **no** `git push`; read-only `gh`/Jira/git GETs and a temporary detached worktree are permitted. (spec: Read-only contract)
- Source gathering uses **all** tracker comments, paginated, and **paginated** `gh api` for PR conversation. (spec: core item 1)
- Reconciliation canonical states `matches | partial | ignored`; output mapping `matches→fixed`, `partial→partial`, `ignored→open`; per-ask bridge `matches=done`, `partial=partial`, `ignored=not_done`. (spec: core items 5–6)
- **Commits are deferred.** Per the user's workflow rule, do NOT commit at task boundaries. The working tree accumulates all changes until the user explicitly says to commit. Each task ends with a verification step, not a commit.
- No test harness exists for skills; TDD steps are substituted with structural verification (grep/JSON-validity/reference-resolution checks). (project rule)

## File Structure

```
plugins/auditing-prs/
  .claude-plugin/plugin.json          # MODIFY: description (two skills), version bump
  core/
    detection-core.md                 # CREATE: shared detection engine (not a skill)
  skills/
    audit-pr/SKILL.md                 # RENAME from skills/auditing-prs/; refactor to reference core
    prepush-audit/SKILL.md            # CREATE: local read-only adapter
.claude-plugin/marketplace.json       # MODIFY: auditing-prs entry description/version
```

Responsibilities:
- `core/detection-core.md` — *what gets found* (sources, HEAD discipline, conventions, lenses, per-ask verdict, reconciliation, panel protocol, neutral finding model). Adapter-neutral wording.
- `skills/audit-pr/SKILL.md` — PR input binding (`gh`), publish/format/resolution machinery, non-recipe rendering of `remediation`.
- `skills/prepush-audit/SKILL.md` — local input binding (branch/base/PR-discovery), read-only contract, snapshot selection, delta/first-pass modes, chat-only output with concrete fix rendering, push-readiness verdict.

**Source map for the core extraction** (current text lives in `skills/auditing-prs/SKILL.md`; "→ core" = move/abstract, "→ stays" = remains in audit-pr adapter):
- Step 0.5 tracker fetch (all comments, pagination) → core (abstract "fetch the tracker ticket"), gh/curl specifics → stays as audit-pr binding.
- Step 2 "union of three sources" + "Analysing the existing conversation" + "code at HEAD is the only authority" → core. The concrete `gh pr view/diff/api` commands → stay as audit-pr binding.
- Convention discovery ("open conventions for changed paths") → core.
- Companion section "Verification via agent-companion" (worktree at SHA, raw context, per-ask acceptance + flag new problems) → core panel protocol.
- §4 comment format, Step 3 draft, Step 5 publish, Step 6 resolution, Step 2.5 → stay in audit-pr.

---

### Task 1: Create the shared detection core

**Files:**
- Create: `plugins/auditing-prs/core/detection-core.md`

**Interfaces:**
- Produces: a reference file (no skill frontmatter) that both adapters read via relative path `../../core/detection-core.md`. Defines the eight core elements and the neutral finding model fields `problem`, `mechanism`, `evidence`, `severity`, `remediation`.

- [ ] **Step 1: Create the file with a non-skill heading (no YAML frontmatter)**

The file MUST NOT start with `---` frontmatter (that would make the harness treat it as a skill). Start with a plain H1:

```markdown
# Audit detection core

Shared detection engine for the `auditing-prs` plugin. Both `audit-pr` (publish)
and `prepush-audit` (local) read this file, then apply their own input/output
adapter. This file defines **what gets found**; presentation, publishing, and
input bindings live in the adapters.

Terms used adapter-neutrally: **the snapshot under review** (the exact code state
an adapter binds — a PR head SHA, or a local `base...HEAD`) and **the asks** (every
tracker requirement + every prior `Issue N`).
```

- [ ] **Step 2: Write the eight core elements**

Write these sections verbatim in intent (copy the detailed wording from the current
`skills/auditing-prs/SKILL.md` where it already exists, and from the spec's
"core/detection-core.md" section):

1. **Source gathering (union)** — tracker ticket (summary + description + **all**
   comments, fetched **with pagination/all pages**; page the dedicated comment
   endpoint when the reported total exceeds returned items); the changes/diff against
   the base; PR conversation **if a PR exists** (prior reviews, inline comments,
   author replies, thread resolution state), also fetched **with full pagination** —
   long conversations otherwise silently drop earlier history. This includes the
   reviewer's published audit report. A prior **summary review constrains new
   findings** — a PR-level decision overrides the tracker ticket alone; read both.
   (State this adapter-neutrally — name no `gh`/`curl` command here; the adapters
   bind the concrete paginated calls.)
2. **HEAD / snapshot discipline (BLOCKING)** — judge the actual file at the snapshot,
   never the diff alone. Reproduce the current SKILL.md list of what does NOT count
   as verification (a `[x]` checkbox, a strikethrough/"✅ fixed" marker, an author
   "fixed" reply, the absence of a re-flag, and **a diff view** — a diff shows the
   base→snapshot delta, not the file's current shape, so reading it is not
   verification). "The code at the snapshot is the only authority." (Adapter-neutral
   wording — do not write the literal diff command here; that lives in the adapter.)
3. **Convention discovery** — dynamically open the conventions applying to each
   changed path (CONTRIBUTING / CONVENTIONS / CLAUDE.md / directory READMEs);
   specialized guides stack on ancestors. No hardcoded project table.
4. **Focus lenses** — architecture / conventions / code-quality / security /
   performance.
5. **Per-ask acceptance verdict** — for every ask return
   `done | partial | not_done | cannot-verify-offline` with `file:line` evidence at
   the snapshot, and flag new problems introduced. For a prior `Issue N` this is the
   same judgement as reconciliation, bridged `matches=done`, `partial=partial`,
   `ignored=not_done`.
6. **Prior-issue reconciliation (delta logic)** — map each prior `Issue N` to
   `matches | partial | ignored` against the snapshot (canonical states). Adapters
   presenting other labels use the fixed mapping `matches→fixed`, `partial→partial`,
   `ignored→open`.
7. **agent-companion verifier panel protocol** — materialize the snapshot as a
   detached worktree at its exact SHA; hand the panel **raw context** (ticket +
   conversation + asks) and the code, never your conclusions; collect a per-ask
   independent verdict. The panel runs an **acceptance review of each ask AND flags
   new problems the changes introduce** — "acceptance review" only excludes a generic
   find-all-bugs sweep unrelated to the asks/changes. Defer to the agent-companion
   manager protocol for dispatch/verdict transport.
8. **Neutral finding model (data, not presentation)** — every finding carries
   `problem`, `mechanism`, `evidence` (`file:line`), `severity` (blocker /
   non-blocker — what readiness gates on), `remediation` (direction to the fix). The
   core defines the fields; adapters render `remediation` (non-recipe vs concrete fix)
   and the presentation scaffold.

- [ ] **Step 3: Verify the file is a reference, not a skill, and covers all eight elements**

Run (every check ASSERTS — a failure prints `FAIL` and the body of any missing item):
```bash
cd <repo>
f=plugins/auditing-prs/core/detection-core.md
head -1 "$f" | grep -q '^---' && echo "FAIL: has frontmatter (would be treated as a skill)" || echo "OK: no frontmatter"
n=$(grep -cE '^[1-8]\. ' "$f"); [ "$n" -eq 8 ] && echo "OK: 8 numbered elements" || echo "FAIL: found $n numbered elements, expected 8"
# Required core concepts, asserted by content (not by line position):
for kw in 'paginated' 'only authority' 'convention' 'architecture' 'security' \
          'matches' 'ignored' 'cannot-verify-offline' 'flags new problems'; do
  grep -qi "$kw" "$f" && echo "OK: core has '$kw'" || echo "FAIL: core missing '$kw'"
done
# Neutral finding model must name ALL five fields:
for fld in problem mechanism evidence severity remediation; do
  grep -qi "\`$fld\`\|$fld" "$f" && echo "OK: finding field $fld" || echo "FAIL: finding field $fld missing"
done
```
Expected: only `OK:` lines; any `FAIL:` line means add the missing content before proceeding.

- [ ] **Step 4: Verify no publish/output machinery leaked into the core**

Run (covers BOTH publish-formatting AND adapter binding code — gh/PR/worktree/SHA
specifics belong in adapters, not the core):
```bash
cd <repo>
f=plugins/auditing-prs/core/detection-core.md
hits=$(grep -niE 'disclosure prefix|--request-changes|--comment|resolveReviewThread|### 4\.|Step 5|Step 6|gh pr (view|diff|review)|gh api repos/|commit_id=|worktree add|headRefOid|GH_HOST|JIRA_API_TOKEN' "$f")
if [ -n "$hits" ]; then echo "FAIL: adapter machinery/binding leaked into core:"; echo "$hits";
else echo "OK: no adapter machinery or binding code in core"; fi
```
Expected: `OK: no adapter machinery or binding code in core`. Any hit must move back into
the relevant adapter (the core describes sources abstractly; concrete `gh`/worktree
commands are the adapter's binding).

---

### Task 2: Rename the publish skill to audit-pr and refactor it to reference the core

**Files:**
- Rename: `plugins/auditing-prs/skills/auditing-prs/` → `plugins/auditing-prs/skills/audit-pr/`
- Modify: `plugins/auditing-prs/skills/audit-pr/SKILL.md`

**Interfaces:**
- Consumes: `../../core/detection-core.md` (Task 1).
- Produces: a skill named `audit-pr` whose behavior is unchanged from the current `auditing-prs` skill, with detection prose replaced by a reference to the core.

- [ ] **Step 1: Rename the skill directory with git**

Run:
```bash
cd <repo>
git mv plugins/auditing-prs/skills/auditing-prs plugins/auditing-prs/skills/audit-pr
ls plugins/auditing-prs/skills/
```
Expected: `audit-pr` listed; `auditing-prs` gone.

- [ ] **Step 2: Update the frontmatter name**

In `plugins/auditing-prs/skills/audit-pr/SKILL.md`, change the frontmatter `name:`
from `auditing-prs` to `audit-pr`. Keep the `description` accurate (it may keep
emphasizing the published-review flow). Update the H1 title to `# Audit PR` (or
similar) if it read "Auditing PRs".

- [ ] **Step 3: Insert the core reference and remove the now-duplicated detection prose**

Immediately after the H1/intro, add:
```markdown
## Detection engine

Read `../../core/detection-core.md` first — it defines the sources, HEAD
discipline, convention discovery, focus lenses, per-ask verdict, reconciliation,
the verifier-panel protocol, and the neutral finding model. This skill is the
**publish adapter**: it binds those to a GitHub PR via `gh` and adds the
comment-format, draft, publish, and resolution machinery below.
```
Then replace the detection-describing prose (the abstract parts of Step 0.5, the
"union of three sources" framing, "Analysing the existing conversation", the "code
at HEAD is the only authority" list, the convention-reading instruction, and the
companion "Verification via agent-companion" protocol) with short pointers to the
core. **Keep** the concrete binding commands as the PR *binding* (these are how the
adapter realizes the core's abstract sources) — the `gh`/`curl` fetches, the literal
`gh pr diff`/`gh api` calls, AND the `git worktree add` materialization at the PR head
SHA for the panel — plus all of: §4 comment format, Step 3 draft, Step 5 publish,
Step 6 resolution, Step 2.5. (The core describes the worktree/panel protocol
abstractly; the concrete `git worktree add <head-sha>` stays here because the SHA
source differs per adapter.)

- [ ] **Step 4: Confirm the non-recipe rendering rule stays in the adapter**

Ensure §4.2's "Where to dig — direction only, never a recipe" remains, now framed
as this adapter's rendering of the core's `remediation` field. Add one sentence:
```markdown
`remediation` (from the core finding model) is rendered here as a non-recipe
direction — never the final fix.
```

- [ ] **Step 5: Verify the rename and reference resolve, and behavior content is intact**

Run:
```bash
cd <repo>
grep -q '^name: audit-pr$' plugins/auditing-prs/skills/audit-pr/SKILL.md && echo "OK: renamed"
grep -q 'core/detection-core.md' plugins/auditing-prs/skills/audit-pr/SKILL.md && echo "OK: references core"
test -f plugins/auditing-prs/core/detection-core.md && echo "OK: ref target exists"
grep -qE 'request-changes|resolveReviewThread' plugins/auditing-prs/skills/audit-pr/SKILL.md && echo "OK: publish machinery retained"
grep -qi 'never a recipe\|non-recipe' plugins/auditing-prs/skills/audit-pr/SKILL.md && echo "OK: non-recipe retained"
```
Expected: all five `OK:` lines.

- [ ] **Step 6: Verify the canonical detection prose is no longer duplicated in the adapter**

The full detection *explanations* must live only in the core; the adapter keeps only
brief pointers plus its `gh` binding. Check every moved concept, not just one phrase:
```bash
cd <repo>
f=plugins/auditing-prs/skills/audit-pr/SKILL.md
# These canonical explanation phrases should now appear in the core, NOT re-explained here.
# A short pointer line that merely names a concept is fine; a full restatement is the smell.
for p in 'only authority on the' 'union of three sources' 'Analysing the existing conversation' \
         'Specialized guides add rules on top of ancestors'; do
  c=$(grep -ci "$p" "$f")
  [ "$c" -eq 0 ] && echo "OK: '$p' not duplicated in adapter" || echo "REVIEW: '$p' still in adapter ($c) — confirm it's a pointer, not a restatement"
done
grep -qi 'core/detection-core.md' "$f" && echo "OK: adapter points to core" || echo "FAIL: adapter lost the core reference"
```
Expected: `OK:` lines. A `REVIEW:` line is a prompt to manually confirm the remaining
mention is a one-line pointer (acceptable) rather than the full moved explanation
(must be deleted).

---

### Task 3: Create the prepush-audit local adapter

**Files:**
- Create: `plugins/auditing-prs/skills/prepush-audit/SKILL.md`

**Interfaces:**
- Consumes: `../../core/detection-core.md` (Task 1).
- Produces: a skill named `prepush-audit` (read-only, chat-only) usable by an executor before pushing.

- [ ] **Step 1: Write the frontmatter and intro**

```markdown
---
name: prepush-audit
description: Use when an executor wants to self-check a branch BEFORE pushing or before opening a PR — does the work actually complete the task, and is every prior review Issue addressed? Read-only and chat-only: never writes to GitHub or Jira and never pushes. Surfaces the same findings the audit-pr reviewer would, so problems get fixed first.
---

# Pre-push audit

Executor-side self-check. Same detection engine as `audit-pr`, bound to the
**local** branch and reported **in chat** — never published.

## Detection engine

Read `../../core/detection-core.md` first. This skill is the **local adapter**: it
binds the core's sources to the local branch (PR optional), enforces a read-only
contract, and renders findings as concrete fix recommendations.
```

- [ ] **Step 2: Write the input bindings section**

```markdown
## Input bindings

- **Branch + base.** Current local branch; base per "Snapshot selection" below.
- **Tracker key** from the branch name (same regex convention as audit-pr); optional
  Jira fetch (all comments, paginated) — non-fatal if unavailable.
- **PR discovery (read-only).** Look up a PR for the branch; if one exists, read its
  conversation and the reviewer's published audit (drives delta mode). If none,
  first-pass mode.
- **Focus lenses.** Default to all five; the executor may narrow them.
```

- [ ] **Step 3: Write the read-only contract**

```markdown
## Read-only contract

"Read-only" = no mutation of external systems and no push.
- NO GitHub writes (no `gh pr review`, no `gh api` POST/PATCH/PUT/DELETE).
- NO Jira writes. NO `git push`.
- Permitted reads: read-only `gh api` GETs, `gh pr view/list`, Jira GETs, all local
  git reads.
- Permitted: a temporary detached worktree for the panel (not a repo/branch mutation).
- The audit report stays in chat.
- **Local fix application is a separate, opt-in action, not part of the audit.** After
  the report, the executor may ask to apply a recommended fix; that edits local
  working files only (never GitHub/Jira/push). Re-running the audit judges the new state.
```

- [ ] **Step 4: Write the snapshot-selection section**

```markdown
## Snapshot selection

- **Default — parity mode:** `base...HEAD` (committed branch diff) — exactly what the
  PR shows the reviewer at the same SHA.
- **Flag — include working tree:** additionally judge staged + unstaged + untracked
  changes; mark them "not yet what the PR will show until committed."
- **Dirty-tree warning:** when judging the committed default while uncommitted changes
  exist, state plainly that N files are outside the audit (commit or pass the flag).
- The panel always runs on a committed snapshot (a worktree needs a SHA); in
  working-tree mode the solo engine reads the working tree and the skill notes the
  panel covered the committed snapshot.

**Base discovery:** if a PR exists, use its target branch (read it, don't assume
`main`); else the merge base with the repo's default branch (discovered). The executor
may override; always state the chosen base.
```

- [ ] **Step 5: Write the two-modes section**

```markdown
## Modes

- **Delta mode (a prior published audit exists):** report the delta, not a re-derived
  full report. Produce (a) a status table mapping each prior `Issue N` to
  matches→fixed / partial / ignored→open at the local snapshot, with a concrete fix
  recommendation for anything not fully fixed, and (b) a scan of changes since the
  audit for new problems — by the solo engine AND, when agent-companion is enabled,
  the panel, so readiness gates on the same new-problem detection audit-pr applies.
  Do NOT reproduce the reviewer's whole report.

  **Prior-audit anchor:** the commit SHA the latest review was submitted against
  (derive from the latest review + PR head at that time). New-changes scan covers
  `anchor … local snapshot`. Inline-only audits count; with multiple revisions anchor
  to the latest. If local HEAD is behind the PR head, say so and stop rather than judge
  a stale snapshot.
- **First-pass mode (no published audit yet):** full first detection pass over the
  branch. Applies both before any PR and when a PR exists but is unreviewed.

"No new problems" is not zero work: confirming it still requires a scoped fresh
detection over the changes since the anchor (delta) or over the whole branch
(first-pass).
```

- [ ] **Step 6: Write the output + verdict section**

```markdown
## Output

Chat-only. Render the core finding model with a Problem / Why / How-to-fix scaffold —
`remediation` is rendered as a **concrete fix** (and the skill may offer to apply it;
see the read-only contract). This concrete rendering is the one deliberate divergence
from audit-pr; detection is identical.

Sections: prior-audit reconciliation table (if any) → new findings (scaffold + fix
recommendation) → push-readiness verdict.

**Push-readiness verdict:** "Ready" requires every ask `done` — every prior `Issue N`
at matches AND every tracker/original requirement satisfied — AND no new
blocker-severity finding. Any `cannot-verify-offline` ask does NOT count as ready: list
it explicitly and downgrade to "ready except for N unverifiable items." A skipped panel
is surfaced the same way.

## Panel

If agent-companion is enabled, the panel runs — mandatory, same as audit-pr. It matters
more here: an executor auditing their own work has a confirmation-bias blind spot an
independent panel does not. If agent-companion is off or no verifier is available, run
solo and say so explicitly ("ran without independent verification") — do not claim parity.
```

- [ ] **Step 7: Write an anti-patterns + checklist tail**

```markdown
## Anti-patterns

- ❌ Any write to GitHub/Jira or any `git push`.
- ❌ Judging the diff instead of the file at the snapshot.
- ❌ Reproducing the reviewer's whole report in delta mode.
- ❌ Claiming "ready" while asks are `cannot-verify-offline` or the panel was skipped.
- ❌ Hardcoding conventions instead of discovering them per changed path.
- ❌ Inlining the detection core instead of referencing it.

## Checklist

- [ ] Base discovered/stated; snapshot selected; dirty tree warned if relevant.
- [ ] Tracker context fetched (all comments) or noted unavailable.
- [ ] PR discovered (read-only); mode chosen (delta vs first-pass).
- [ ] For every prior Issue, file read at the snapshot (not the diff).
- [ ] Conventions opened for changed paths.
- [ ] Panel run if agent-companion enabled; solo+disclaimer otherwise.
- [ ] Findings in chat with concrete fix recommendations; no external writes.
- [ ] Push-readiness verdict with unverifiable/skipped items explicit.
```

- [ ] **Step 8: Verify the adapter is complete, read-only, and references the core**

Run:
```bash
cd <repo>
f=plugins/auditing-prs/skills/prepush-audit/SKILL.md
grep -q '^name: prepush-audit$' $f && echo "OK: name" || echo "FAIL: name"
grep -q 'core/detection-core.md' $f && echo "OK: references core" || echo "FAIL: core ref"
for kw in 'Read-only contract' 'Snapshot selection' 'Delta mode' 'First-pass' \
          'Push-readiness' 'Panel' 'concrete fix' 'not zero work' 'anchor'; do
  grep -qi "$kw" $f && echo "OK: $kw" || echo "MISSING: $kw"
done
```
Expected: every `OK:` line and no `MISSING:`.

Note the read-only check is NOT a naive grep for `git push` / `gh pr review`: those
strings appear legitimately inside the prohibition prose ("NO `git push`"), so a raw
grep false-positives. Instead, assert the prohibitions are PRESENT:
```bash
cd <repo>
f=plugins/auditing-prs/skills/prepush-audit/SKILL.md
grep -qiE 'no .*git push|never .*push' $f && echo "OK: forbids push" || echo "FAIL: push prohibition missing"
grep -qiE 'no github writes|POST/PATCH/PUT/DELETE' $f && echo "OK: forbids GitHub writes" || echo "FAIL: write prohibition missing"
grep -qiE 'no jira writes' $f && echo "OK: forbids Jira writes" || echo "FAIL: Jira prohibition missing"
```
Expected: the three `OK:` lines.

---

### Task 4: Update the plugin manifest, marketplace entry, and README

**Files:**
- Modify: `plugins/auditing-prs/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `README.md` (the stale skill-dir link at `README.md:45`)

**Interfaces:**
- Consumes: the two skills (Tasks 2–3) now present in the plugin.

- [ ] **Step 1: Update plugin.json description and bump version**

In `plugins/auditing-prs/.claude-plugin/plugin.json`: keep `name` as `auditing-prs`;
rewrite `description` to cover BOTH skills (the published-review `audit-pr` flow AND
the read-only local `prepush-audit` self-check sharing one detection core); bump
`version` (e.g. `0.1.4` → `0.2.0`, since two skills + a shared core is a feature-level
change). Note the exact new version string — Steps 2–3 reuse it.

- [ ] **Step 2: Mirror the change in marketplace.json**

In `.claude-plugin/marketplace.json`, update the `auditing-prs` plugin entry's
`description` and `version` to match plugin.json exactly. Leave `source` unchanged
(`./plugins/auditing-prs` — the plugin dir, not the skill dir, so the rename does not
affect it).

- [ ] **Step 3: Fix the stale README skill-dir link**

`README.md:45` reads:
```
  ([`skills/auditing-prs/`](plugins/auditing-prs/skills/auditing-prs))
```
The plugin now has two skills, so replace that single link with both renamed skills:
```
  ([`skills/audit-pr/`](plugins/auditing-prs/skills/audit-pr) · [`skills/prepush-audit/`](plugins/auditing-prs/skills/prepush-audit) · shared [`core/`](plugins/auditing-prs/core))
```

- [ ] **Step 4: Verify manifests are valid JSON, versions+descriptions consistent, and README has no stale link**

Run:
```bash
cd <repo>
python3 -m json.tool plugins/auditing-prs/.claude-plugin/plugin.json >/dev/null && echo "OK: plugin.json valid" || echo "FAIL: plugin.json invalid"
python3 -m json.tool .claude-plugin/marketplace.json >/dev/null && echo "OK: marketplace.json valid" || echo "FAIL: marketplace.json invalid"
python3 - <<'PY'
import json
pj=json.load(open('plugins/auditing-prs/.claude-plugin/plugin.json'))
mj=json.load(open('.claude-plugin/marketplace.json'))
entry=next(p for p in mj['plugins'] if p['name']=='auditing-prs')
assert pj['name']=='auditing-prs', "plugin name must stay auditing-prs"
assert pj['version']==entry['version'], f"version mismatch {pj['version']} vs {entry['version']}"
assert pj['description']==entry['description'], "description must match between plugin.json and marketplace.json"
assert entry['source']=='./plugins/auditing-prs', "marketplace source must stay the plugin dir"
print(f"OK: manifests consistent (version {pj['version']}, name/desc/source verified)")
PY
grep -q 'skills/auditing-prs' README.md && echo "FAIL: stale skills/auditing-prs link still in README" || echo "OK: README has no stale skill-dir link"
```
Expected: `OK: plugin.json valid`, `OK: marketplace.json valid`, the `OK: manifests
consistent …` line, and `OK: README has no stale skill-dir link`.

---

### Task 5: Cross-skill consistency verification

**Files:**
- Read-only verification across `core/detection-core.md`, both `SKILL.md`s, and the site build.

**Interfaces:**
- Consumes: Tasks 1–4.

- [ ] **Step 1: Verify both adapters reference the core and the RELATIVE path resolves**

Resolve the `../../core/detection-core.md` reference from each skill dir for real
(don't test a hardcoded path — that would pass even if the reference were wrong):
```bash
cd <repo>
for s in audit-pr prepush-audit; do
  d=plugins/auditing-prs/skills/$s
  ref=$(grep -oE '\.\./\.\./core/detection-core\.md' $d/SKILL.md | head -1)
  if [ -z "$ref" ]; then echo "FAIL: $s does not reference ../../core/detection-core.md"; continue; fi
  target=$(cd "$d" && python3 -c "import os,sys;print(os.path.normpath('$ref'))")
  if [ -f "$d/$ref" ] || [ -f "$target" ]; then echo "OK: $s -> core resolves ($target)"; else echo "FAIL: $s reference does not resolve to a file ($target)"; fi
done
```
Expected: `OK: audit-pr -> core resolves …` and `OK: prepush-audit -> core resolves …`.

- [ ] **Step 2: Verify the reconciliation vocabulary is consistent across all three files**

The core must define ALL THREE of canonical-states, output-mapping, AND the per-ask
bridge (AND, not OR); both adapters must be consistent with it:
```bash
cd <repo>
core=plugins/auditing-prs/core/detection-core.md
ap=plugins/auditing-prs/skills/audit-pr/SKILL.md
pp=plugins/auditing-prs/skills/prepush-audit/SKILL.md
grep -qiE 'matches *\| *partial *\| *ignored' $core && echo "OK: core canonical states" || echo "FAIL: core canonical states"
grep -qi 'matches→fixed' $core && echo "OK: core output mapping" || echo "FAIL: core output mapping"
grep -qi 'matches=done' $core && echo "OK: core per-ask bridge" || echo "FAIL: core per-ask bridge"
grep -qi 'matches→fixed\|matches.*fixed' $pp && echo "OK: prepush uses mapping" || echo "FAIL: prepush mapping"
# audit-pr keeps its native Issue-N matches/partial/ignored language:
grep -qiE 'matches|partial|ignored' $ap && echo "OK: audit-pr reconciliation language present" || echo "FAIL: audit-pr reconciliation language"
```
Expected: every `OK:` line, no `FAIL:`.

- [ ] **Step 3: Repo-wide stale-path scan — nothing still points at the old skill dir**

```bash
cd <repo>
# Exclude the docs/ plan+spec (which legitimately discuss the rename) and .git.
hits=$(grep -rn 'skills/auditing-prs' --include='*.md' --include='*.json' --include='*.sh' --include='*.js' --include='*.vue' . \
  | grep -v '^\./docs/superpowers/' | grep -v '^\./\.git/')
if [ -n "$hits" ]; then echo "FAIL: stale skills/auditing-prs references remain:"; echo "$hits"; else echo "OK: no stale skill-dir references"; fi
```
Expected: `OK: no stale skill-dir references`. Fix any file listed.

- [ ] **Step 4: Verify the site build still succeeds (fail loudly, no pipe masking)**

```bash
cd <repo>
if [ -f build-site.sh ]; then
  set -o pipefail
  if bash build-site.sh > /tmp/prepush-build.log 2>&1; then echo "OK: build-site.sh succeeded"; else echo "FAIL: build-site.sh exited non-zero:"; tail -20 /tmp/prepush-build.log; fi
else echo "no build step"; fi
```
Expected: `OK: build-site.sh succeeded` (or `no build step`). The build reads
`marketplace.json`, whose `source` is the plugin dir — unaffected by the skill rename —
but run it to be sure nothing hardcodes the old skill path.

- [ ] **Step 5: Manual smoke (executor responsibility)**

This step is the user's — not auto-verifiable here. From a feature branch with a known
prior PR review, invoke `prepush-audit` and confirm: (a) it reads the PR review,
(b) reports the Issue N delta against the local state, (c) gives concrete fixes,
(d) makes no GitHub/Jira writes, (e) runs the panel when agent-companion is on.
Report results back; do not mark "done" on the user's behalf.

---

## Self-Review

**Spec coverage:**
- Shared core + two adapters, plugin name unchanged → Tasks 1, 2, 3, 4. ✓
- Core's eight elements (incl. pagination, HEAD discipline, panel acceptance + new
  problems, neutral finding model with severity, reconciliation mapping/bridge) →
  Task 1 Steps 2–4. ✓
- audit-pr renamed, behavior preserved, detection moved to core, non-recipe rendering
  kept → Task 2. ✓
- prepush-audit: input bindings, read-only contract (+ opt-in local fix), snapshot
  selection + base discovery + dirty warning, delta anchor + first-pass, chat-only
  concrete-fix output, push-readiness with cannot-verify/skipped handling, mandatory-
  if-enabled panel with honest solo degrade → Task 3. ✓
- Manifest/marketplace update → Task 4. ✓
- Out of scope (no plugin rename, no reference removal) honored → plugin name pinned in
  Global Constraints + Task 4 verify. ✓

**Placeholder scan:** no "TBD/implement later"; each create-step carries the actual
markdown to write and each verify-step an exact command + expected output.

**Type/name consistency:** skill names `audit-pr` / `prepush-audit`; core path
`../../core/detection-core.md`; canonical states `matches|partial|ignored`; finding
fields `problem|mechanism|evidence|severity|remediation` — used identically across
Tasks 1–3 and the verification greps.
