# Issue-tracker context (Jira) — fetch bindings

Support file for `audit-pr` Step 0.5 and `prepush-audit`'s tracker fetch. Optional
"what was asked" context; **every failure here is non-fatal** — the audit proceeds
without tracker context.

## Credentials — read from the environment only; never store or print them

- `JIRA_BASE_URL` — e.g. `https://your-org.atlassian.net`
- `JIRA_EMAIL` — the account email
- `JIRA_API_TOKEN` — an **Atlassian API token** (create at `id.atlassian.com` →
  Security → *Create API token*), used with HTTP Basic auth in the form
  `email:token`.

How these reach the environment is the user's choice (direnv, shell profile, a
secrets manager, CI secrets). The skill only reads them.

**Token safety.** Never echo the token into chat, drafts, comments, or logs. Pass it
only inside the `-u` argument of `curl`. If you must show a command to the user,
redact it (`-u "$JIRA_EMAIL:***"`).

## Fetch the issue

Summary, status, type, assignee, description, comments:

```bash
curl -s -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -H "Accept: application/json" \
  "$JIRA_BASE_URL/rest/api/3/issue/{KEY}?fields=summary,status,issuetype,assignee,description,comment"
```

## Parse

`summary`, `status.name`, `issuetype.name`, `assignee.displayName` come straight
from JSON. `description` and each `comment.body` are ADF (Atlassian Document
Format); extract plain text with:

```bash
jq -r '[.. | objects | select(.type? == "text") | .text] | join(" ")'
```

Take **all** comments — the full ticket context matters both for the audit and for
independent verification by the companion panel. The `fields=comment` form may
return only the first page of comments on heavily-discussed issues; if the returned
`comment.total` exceeds the items present, page the dedicated endpoint
`$JIRA_BASE_URL/rest/api/3/issue/{KEY}/comment?startAt=…&maxResults=…` until you
have them all.

## Failure modes — all non-fatal

- 401/403 → credentials missing or token expired: tell the user and proceed without
  tracker context.
- 404 → the branch looks like a key but the issue does not exist: note it in the
  draft and proceed.
- Network error → same: note and proceed.

> **Other trackers.** Jira is the concrete example here. For another tracker keep
> the same shape: optional "what was asked" context, credentials from the
> environment only, all failures non-fatal.
