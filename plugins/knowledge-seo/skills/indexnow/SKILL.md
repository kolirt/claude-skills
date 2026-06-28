---
name: indexnow
description: Use to set up IndexNow — instant URL-change notification for Bing/Yandex/Seznam/Naver/Yep (not Google): key file, GET/POST submission, debounce.
---

# IndexNow — instant URL-change notification

IndexNow is an open protocol that lets you push URL changes directly to search engines
the moment content changes, rather than waiting for the next crawl cycle. A single
submission to any participating endpoint is shared automatically with all other
participating engines: **Bing, Yandex, Seznam, Naver, and Yep**.

**Google does not participate in IndexNow.** Use Google Search Console / Indexing API
separately if Google coverage matters.

## API key setup

Every site needs a secret key (8–128 characters, hex/alphanumeric plus hyphens).

### Default hosting (no `keyLocation` needed)

Place a plain-text file at the domain root:

```
https://example.com/<key>.txt
```

File contents must be exactly the key string, UTF-8 encoded, with no extra whitespace.

### Alternative hosting (pass `keyLocation`)

If you cannot host at the root, put the file anywhere and include its full URL in every
submission as `keyLocation`. The engine fetches that URL to verify ownership.

## Rules

- [invariant · desired] **One submission reaches all engines.** Submit to any single
  participating endpoint (e.g. `https://api.indexnow.org/indexnow`); the endpoint
  relays to all others. Do not fan-out to each engine separately.
  ✅ do: submit once to `api.indexnow.org`.
  ❌ don't: submit the same URL to `www.bing.com/indexnow`, `yandex.com/indexnow`, and
  `search.seznam.cz/indexnow` in parallel — why: redundant traffic, potential
  rate-limit on your key across engines.

- [invariant · desired] **Key file content must equal the key exactly.** The file at
  `<key>.txt` must contain only the key string (UTF-8). Extra newlines, BOM, or HTML
  wrappers cause a 403.
  ✅ do: serve the file with `Content-Type: text/plain; charset=utf-8`, body = key only.
  ❌ don't: wrap it in HTML or add a trailing newline from a misconfigured static host —
  why: the engine does a byte-exact match.

- [invariant · desired] **URLs must match the host in the submission.** Every URL in the
  `urlList` must share the same scheme+host declared in the `host` field; mixing hosts
  in one batch returns 422.
  ✅ do: group URLs by host into separate batch requests.
  ❌ don't: mix `https://example.com/a` and `https://shop.example.com/b` in one request —
  why: 422 Unprocessable Entity for the entire batch.

- [preference · desired] **Prefer batch POST over repeated GET for multiple URLs.**
  GET is convenient for a single URL; for two or more, use the POST endpoint with a
  JSON body to stay within rate limits and reduce request overhead.

- [anti-pattern · desired] **Do not submit on trivial changes.** Submitting every
  time a view counter or timestamp updates wastes quota and may trigger rate limiting
  (429). Submit only on meaningful content changes (new page, changed title/body,
  published/unpublished).
  ✅ do: debounce submissions — buffer changes for a short window (e.g. 5–60 s) and
  deduplicate; send at most once per URL per meaningful edit event.
  ❌ don't: call the API inside every database write hook unconditionally — why: spamming
  the same URL within seconds yields 429 and burns daily quota.

- [preference · desired] **Store and reuse the key in a single config location.** Hard-
  coding the key in multiple places makes rotation painful; inject it from an environment
  variable or a config file.

## Submit a single URL (GET)

```
GET https://api.indexnow.org/indexnow?url=<encoded-url>&key=<key>
```

Optional `keyLocation` parameter:

```
GET https://api.indexnow.org/indexnow
    ?url=https%3A%2F%2Fexample.com%2Farticle-1
    &key=a1b2c3d4e5f6a1b2
    &keyLocation=https%3A%2F%2Fexample.com%2Fkeys%2Fa1b2c3d4e5f6a1b2.txt
```

## Submit a batch of URLs (POST)

`POST https://api.indexnow.org/indexnow`
`Content-Type: application/json; charset=utf-8`

```json
{
  "host": "example.com",
  "key": "a1b2c3d4e5f6a1b2",
  "keyLocation": "https://example.com/a1b2c3d4e5f6a1b2.txt",
  "urlList": [
    "https://example.com/article-1",
    "https://example.com/article-2",
    "https://example.com/category/shoes"
  ]
}
```

- `keyLocation` is optional when the key file is at the domain root.
- Maximum **10,000 URLs** per request.
- All URLs in `urlList` must share the `host` value.

## Response codes

| Code | Meaning |
|------|---------|
| 200  | OK — URL(s) accepted and queued for crawl. |
| 202  | Accepted — key validation still pending; URL(s) will be processed once verified. |
| 400  | Bad request — malformed URL, missing parameter, or invalid JSON. |
| 403  | Forbidden — key not found or key file content does not match. |
| 422  | Unprocessable — URL does not belong to the declared host. |
| 429  | Too many requests — rate limit exceeded; back off and retry later. |

## Bing URL Submission API

Bing also offers a **distinct, authenticated alternative**: the
[Bing URL Submission API](https://www.bing.com/indexnow). It requires an API key obtained
from Bing Webmaster Tools and submits only to Bing (not the shared IndexNow network). Use
it when you need Bing-specific quota controls or analytics not available through IndexNow.

## Related skills (by name)

- `sitemaps` — XML sitemaps complement IndexNow; crawlers fall back to sitemaps for
  discovery when IndexNow submissions have not been processed yet.
- `robots` — `robots.txt` controls what crawlers are allowed to fetch; ensure submitted
  URLs are not blocked before pushing them via IndexNow.
