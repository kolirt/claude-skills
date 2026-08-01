# Issue resolution — the three mechanisms (audit-pr)

Support file for `audit-pr` Step 6. Verification comes first and lives in the SKILL;
this file holds the exact bodies and calls. Apply ALL THREE mechanisms per closed
issue, in the order: verify → Mechanism 2 → Mechanism 1 → Mechanism 3.

## Mechanism 1 — checklist row

Update the body of **every** summary review that lists the issue (not just the
latest) — via the review-update call in SKILL Step 5. Change the matching row to:

```
- [x] ~~[**Issue N**](inline-url) — original action~~ fixed in [`{short-sha}`](https://{host}/{owner}/{repo}/commit/{full-sha})
```

Strikethrough preserves history; the resolution note carries a clickable SHA.

**Mechanism 1 is BLOCKING.** The harness treats `PUT .../reviews/{id}` as editing a
pre-existing PR review on the user's account and will prompt for permission. That is
expected. Surface it in one batched message naming every review ID you need to
update (rev 1, rev 2, …) so they approve in one shot. A `[x]` without
the strikethrough + commit link is not a resolution.

## Mechanism 2 — inline comment banner

PATCH the inline comment body. Prepend a banner and collapse the original:

```
> **RESOLVED** in commit [`{short-sha}`](https://{host}/{owner}/{repo}/commit/{full-sha}) (rev {N})

<details>
<summary>Original review (click to expand)</summary>

{original body — keep the disclosure prefix and full content}

</details>
```

## Mechanism 3 — GitHub native "Resolve conversation"

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

**Partial resolution:** apply the three mechanisms only to closed issues; leave open
ones untouched.
