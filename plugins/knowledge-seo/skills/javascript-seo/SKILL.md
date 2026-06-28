---
name: javascript-seo
description: Use when a JS/SPA app must be crawlable and indexable — SSR/initial-HTML, routing, crawlable links, lazy-loading, render parity, mobile-first, agent-friendly markup.
---

# javascript-seo — crawlability, indexability, and agent-friendly markup for JS apps

Stack-independent rules for making JavaScript-driven applications fully crawlable by search-engine bots and AI fetchers. The central constraint: crawlers and AI agents may not execute JavaScript at all, or may execute it much later than a real browser — so every signal that matters for indexing must be present in the **initial HTML response**.

## Rules

### Crawl → Render → Index pipeline

- [invariant · desired] Assume crawlers operate in two modes: **no-JS** (raw HTML only) and **deferred-JS** (JS queued, potentially never executed). Design so that the raw HTML alone is sufficient to index the page.
- [invariant · desired] **Critical content** — main body text, headings, prices, product names, article copy — must appear in the **initial HTML** served by the origin, not injected by client-side JavaScript after load.
  - ✅ do: render content server-side (SSR) or at build time (SSG) so it appears in the raw `<body>` HTML.
  - ❌ don't: fetch content via client-side `fetch()` / XHR and insert it into the DOM after hydration — crawlers that skip JS will see an empty page.
  - why: Googlebot's two-wave rendering means JS-injected content may be indexed days later or not at all; AI fetchers (GPTBot, ClaudeBot, Perplexity, etc.) often fetch only the raw HTML.

### SSR / SSG over dynamic rendering

- [invariant · desired] **Dynamic rendering is deprecated.** Do not serve a separate pre-rendered snapshot only to crawlers while real users receive a client-side-only build. Maintain a single SSR or SSG pipeline for everyone.
  - ✅ do: use the framework's SSR delivery (e.g. server-rendered HTML on first request) or a static site generator as the single source of truth.
  - ❌ don't: route Googlebot/Bingbot to a headless-chrome pre-renderer while human users get an empty `<div id="app">` shell. Dynamic rendering is explicitly deprecated by Google.
  - why: two code paths diverge over time, creating cloaking risk and maintenance burden. SSR/SSG is the correct long-term answer.

### Routing — History API, not hash routing

- [invariant · desired] Use the **History API** (`pushState` / `replaceState`) for client-side navigation so that each route has a real URL path (`/products/123`). Hash-based routes (`/#/products/123`) are not indexed as separate pages.
  - ✅ do: configure the router in `history` / `HTML5` mode so the URL changes to `/products/123` on navigation.
  - ❌ don't: use `hash` mode (`/#/products/123`) for any page that should appear in search results.
  - why: crawlers index by URL; the fragment (`#...`) is never sent to the server and is ignored by most indexing pipelines.

### Crawlable `<a href>` links

- [invariant · desired] Every URL that should be discoverable by crawlers must be reachable via a real **`<a href="...">`** element in the initial HTML. Click handlers on `<div>` or `<span>` are invisible to link-following crawlers.
  - ✅ do: render `<a href="/category/shoes">Shoes</a>` in the server-rendered HTML, even if the router intercepts the click client-side.
  - ❌ don't: build navigation using only `onClick={() => router.push('/shoes')}` on non-anchor elements — the link is not discovered.
  - why: Googlebot and all AI crawlers follow `href` attributes to discover pages; JavaScript event listeners are not followed.

### Viewport lazy-loading — `loading="lazy"` and IntersectionObserver

- [invariant · desired] Use **`loading="lazy"`** on `<img>` and `<iframe>` elements, or IntersectionObserver for custom lazy-loading components. Never gate content loading on scroll events or user gestures.
  - ✅ do: `<img src="..." loading="lazy" alt="...">` — the browser (or a sufficiently capable crawler) handles the lazy-load automatically.
  - ✅ do: use IntersectionObserver to load below-fold content; the observer fires as the crawler's simulated viewport scrolls.
  - ❌ don't: load content or images only after a `scroll` event fires, or only after the user swipes/clicks — search bots and AI fetchers do not produce these events.
  - why: crawlers render pages in a simulated viewport but do not trigger gesture/scroll events. Content behind those listeners is never fetched.

### Initial-HTML vs hydrated parity

- [invariant · desired] The **canonical URL**, **`<title>`**, **`<meta name="description">`**, **robots directives**, and **structured-data** (`<script type="application/ld+json">`) must be identical in the server-rendered HTML and in the hydrated DOM. Do not rely solely on JS injection to add these after mount.
  - ✅ do: output `<title>` and canonical `<link>` in the SSR-rendered `<head>` on the server.
  - ❌ don't: set the page title or canonical only inside a `useEffect` / `onMounted` callback — it arrives too late for crawlers that parse HTML without executing JS.
  - why: crawlers snapshot the initial HTML; if metadata is missing there and only appears after hydration, it may never be indexed.
- [preference · desired] When using a head-management library, configure it in SSR mode so tags are serialised into the HTML response — never depend on the client-only injection path for SEO-critical tags.

### SSR for AI crawlers

- [invariant · desired] Treat **AI crawlers** (GPTBot, ClaudeBot, Perplexity-Bot, OAI-SearchBot, etc.) as no-JS clients. They fetch raw HTML and may not execute JavaScript at all. SSR/SSG is the only reliable way to surface content to them.
  - ✅ do: ensure every page's body text, headings, and key metadata are in the initial server response — this serves both traditional search bots and AI crawlers simultaneously.
  - ❌ don't: assume AI crawlers behave like a modern browser with JS enabled; treat them as `curl`.
  - why: the AI-crawler ecosystem is expanding rapidly; JS rendering support is inconsistent across providers and crawler generations.

### Mobile-first parity

- [invariant · desired] Google (and most major crawlers) use a **mobile-first** crawl: the mobile version of a page is indexed. The mobile version must carry the **same content, metadata, structured data, and images** as the desktop version.
  - ✅ do: serve a single responsive HTML document; the same `<title>`, `<meta>`, `<script type="application/ld+json">`, and `<img>` tags must be present regardless of viewport.
  - ❌ don't: conditionally omit structured data, images, or body text on mobile via server-side user-agent detection — the mobile crawl will miss it.
  - ❌ don't: block CSS or JavaScript files from crawlers via `robots.txt` — doing so prevents correct rendering and indexing.
  - why: if the mobile-rendered page is thinner than the desktop version, the indexed content is thinner — even if desktop looks perfect.

### Content-hashed / fingerprinted assets

- [preference · desired] Static assets (JS bundles, CSS, images) should use **content-hash filenames** (e.g. `main.a3f9c1.js`) rather than version query strings or fixed names.
  - ✅ do: configure the build tool to emit `[name].[contenthash].[ext]` filenames; set long-lived `Cache-Control: immutable` headers.
  - ❌ don't: use `?v=1` query strings as the sole cache-busting mechanism — some CDN and crawler caches strip query strings.
  - why: content-hashed filenames guarantee that when a crawler re-crawls an asset URL, it gets the exact same bytes — eliminating stale-render artefacts in crawl caches.

### Agent-friendly markup

- [invariant · desired] Use **semantic HTML** elements (`<nav>`, `<main>`, `<article>`, `<section>`, `<header>`, `<footer>`, `<aside>`) so crawlers and AI agents can understand page structure without executing JavaScript.
  - ✅ do: wrap the primary content in `<main>`, navigation in `<nav>`, and supplemental content in `<aside>`.
  - ❌ don't: build layout from anonymous `<div>` soup — structure is lost to non-rendering agents.
- [invariant · desired] Interactive elements must be real **`<button>`** or **`<a href>`** elements — never `<div onClick>` or `<span onClick>`.
  - ✅ do: `<button type="button">Add to cart</button>` or `<a href="/cart">View cart</a>`.
  - ❌ don't: `<div class="btn" onClick={...}>Add to cart</div>` — AI agents that parse HTML to find actionable elements will not identify this as a button.
  - why: AI agents acting on behalf of users (browser-automation agents, AI shopping assistants) parse the DOM for semantic roles; click-divs are invisible to them.
- [invariant · desired] Every interactive and image element must have an **accessible name** — `alt` on images, `aria-label` or visible text on buttons, `aria-label` on icon-only links.
  - ✅ do: `<img src="shoe.jpg" alt="Red running shoe, size 10">`.
  - ❌ don't: `<img src="shoe.jpg">` or `<button><svg ...></svg></button>` without an accessible label.
  - why: crawlers that extract image meaning, and AI agents that describe or act on page content, rely on textual names.
- [preference · desired] Use **stable CSS selectors and `id` / `data-*` attributes** on key interactive elements so that automated agents and monitoring tools can target them reliably across deployments.
  - ✅ do: `<button data-testid="add-to-cart">Add to cart</button>`.
  - ❌ don't: generate class names with random hashes (e.g. CSS-Modules without a stable `id`) on elements that external agents must interact with.

## Related skills (by name)

- canonicalization-and-redirects
- structured-data
- page-experience
- generative-seo
