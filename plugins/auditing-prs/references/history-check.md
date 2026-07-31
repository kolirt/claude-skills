# History check — blame bindings (core §19)

Support file for `audit-pr` Step 2 / `prepush-audit`. Finds **hotspots**: lines the
audited range rewrites or deletes that originated in a fix/workaround/revert commit.
Run inside the worktree (`$WT`); `$BASE` is the base of the audited range
(`TRUE_BASE` when stacked, otherwise the merge-base with the PR's target branch).

```bash
cd "$WT"
# For every changed file: take the line ranges the range REMOVES (the '-' side of a
# -U0 diff), blame exactly those ranges at $BASE, and keep origin commits whose
# subject smells like a fix. Output: <file> <sha> <subject>.
for f in $(git diff --name-only "$BASE"...HEAD); do
  git diff -U0 "$BASE"...HEAD -- "$f" \
    | grep -oE '^@@ -[0-9]+(,[0-9]+)?' \
    | sed 's/@@ -//' \
    | while IFS=, read -r start count; do
        count=${count:-1}; [ "$count" -eq 0 ] && continue
        git blame -w -L "$start,+$count" "$BASE" -- "$f" 2>/dev/null \
          | awk '{print $1}'
      done | sort -u | while read -r sha; do
        git log -1 --format="%h %s" "$sha" 2>/dev/null \
          | grep -iE 'fix|hotfix|revert|bug' \
          | sed "s|^|$f |"
      done
done | sort -u
```

Notes:

- `-U0` makes hunk headers map 1:1 to removed-line ranges; `-w` ignores
  whitespace-only attribution.
- A rename shows the file under its old path on the `-` side — that is correct for
  blame at `$BASE`.
- The grep markers are **signals, not proof** (core §19): for each hit, read the
  origin commit (`git show <sha>`) and judge whether the new code preserves what
  that commit fixed. The verdict — *intentional* or a *finding* — is per hotspot,
  never per grep line.
- Empty output = no hotspots; say nothing. Non-empty output goes into the relevant
  searchers' packages as hotspots requiring a verdict.
