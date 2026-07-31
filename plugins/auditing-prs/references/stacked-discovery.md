# Stacked-branch discovery — `gh` bindings (audit-pr)

Support file for `audit-pr` Step 2. The rule, the outputs (`TRUE_BASE`, `PARENT_PR`,
`INHERITED_FILES`), and the honesty rules are **core §9** — this file only binds the
concrete calls. Run only when `baseRefName == $DEFAULT` (the SKILL gates this).

## Discovery bindings

```bash
# CANDIDATES — every other open PR's head (exclude this PR's own number).
gh pr list --repo {owner}/{repo} --state open \
  --json number,headRefName,headRefOid,isCrossRepository --limit 200

# merge-base + ancestry in ONE call per pair: merge_base_commit.sha is the
# merge-base; status == "ahead" means B is a strict descendant of A.
gh api repos/{owner}/{repo}/compare/{A}...{B} \
  --jq '{status, merge_base_commit: .merge_base_commit.sha}'
```

- **Truncation.** `--limit 200` bounds the cost at one compare call per open PR. If
  the listing returns 200 entries, the candidate set may be cut — report it (core §9,
  honesty rules); a long-lived parent older than the limit would otherwise be missed
  silently.
- **Unreachable candidate.** A `404`/`403` on a compare call — typically a
  cross-repository fork head a read-only token cannot read — means **skipped and
  counted**, never "not an ancestor" (core §9). A stack whose parent lives in a fork
  is not detected.

## Taking the diff from `TRUE_BASE`

When discovery found a `PARENT_PR`, `gh pr diff` is **not** the audit subject — it
carries the parent's commits. Take the range from `TRUE_BASE` instead, and narrow
the commit list to the same range:

```bash
gh api repos/{owner}/{repo}/compare/{TRUE_BASE}...{head-sha} \
  --jq '{status, changed_files, commits: [.commits[].sha], files: [.files[].filename]}'
```

**State the API's limits, never absorb them silently:** the compare endpoint returns
**at most 300 changed files** and paginates only its commits. When `files` reaches
300 or `changed_files` exceeds the returned count, say in the digest that the file
set was truncated, and recommend re-running the audit against a local checkout
(`prepush-audit`), which has no such cap.

When discovery found no parent, nothing changes: `gh pr diff` stays the subject.
