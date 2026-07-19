# `{project-root}` root-file fixture (positive guard)

`{project-root}/package.json` is a LEGITIMATE path: `{project-root}` is a real
placement token (placement.md §1) and root-level files such as `package.json` live
directly under it, with no intermediate directory segment. This must stay clean —
nobody should "fix" `_is_known_token_path` into rejecting a bucket token followed by
exactly one segment just because other buckets in this corpus happen to nest deeper.

## Files

- `{project-root}/package.json`

**File:** `{project-root}/package.json`

```json
{
  "name": "example"
}
```
