# PR worktree — snapshot on disk (audit-pr)

Support file for `audit-pr` Step 2: put the PR code on disk at the exact head SHA so
the searcher subagents and the verifier panel can read it. Built from the remote's
PR head — the local checkout (its branch, its freshness) is never read and never
touched.

```bash
HEAD_SHA=$(gh pr view {N} --repo {owner}/{repo} --json headRefOid -q .headRefOid)
# Fetch via an EXISTING local remote so its configured auth/protocol is reused
# (the clone may be SSH, a host alias, gh's https helper, …). Pick the remote
# whose URL contains {owner}/{repo}; fall back to origin. Do NOT build an https
# URL from `gh repo view --json url` — git can't auth a bare https URL on an
# SSH clone ("could not read Username for https://…").
REMOTE=$(git remote -v | awk -v r="{owner}/{repo}" 'index($2,r){print $1; exit}')
REMOTE=${REMOTE:-origin}
git fetch "$REMOTE" "pull/{N}/head"              # PR head ref (works for forks)
# Confirm the exact PR head is now present (a fork PR may need its own remote).
git cat-file -e "${HEAD_SHA}^{commit}" 2>/dev/null \
  || { echo "PR head $HEAD_SHA not fetched from $REMOTE — resolve the remote first"; }
WT="$(mktemp -d)/pr-{N}"
git worktree add --detach "$WT" "$HEAD_SHA"
trap 'git worktree remove --force "$WT" 2>/dev/null' EXIT   # clean up always
```

When the verifier panel runs, put `$WT` in its request as its own line —
`WORKTREE: <absolute path>` — per core §7. Without it the confined verifiers cannot
read the snapshot at all.

`--detach` at the exact head SHA means a head that moves mid-audit can't change what
was verified. Reuse this `HEAD_SHA` for your own `contents`-API reads so you and the
panel judge one snapshot. Remove the worktree **after** synthesis + the gate + any
drill-down into raw verdicts by `file:line` — via the `trap`. Publishing (Step 5)
does not need the worktree: it uses the GitHub head SHA via the `contents` API.
