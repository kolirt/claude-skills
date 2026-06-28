---
name: page-experience
description: Use when optimizing page experience — Core Web Vitals (LCP/INP/CLS), performance, HTTPS, security headers, mobile-friendliness, interstitials.
---

# page-experience — Core Web Vitals, performance, HTTPS, security, and mobile-friendliness

Stack-independent rules for improving page experience signals. Covers Core Web Vitals (LCP, INP, CLS) and their supporting metrics, HTTPS hygiene, security headers, and mobile-friendliness. Field data (CrUX, 75th percentile) is the authoritative verdict; lab tools (Lighthouse, PageSpeed Insights) are for diagnosis only.

## Core Web Vitals thresholds (field data · 75th percentile)

| Metric | Good | Needs Improvement | Poor |
|---|---|---|---|
| **LCP** (Largest Contentful Paint) | ≤ 2.5 s | 2.5 – 4.0 s | > 4.0 s |
| **INP** (Interaction to Next Paint) | ≤ 200 ms | 200 – 500 ms | > 500 ms |
| **CLS** (Cumulative Layout Shift) | ≤ 0.1 | 0.1 – 0.25 | > 0.25 |
| **TTFB** (Time to First Byte) — supporting | ≤ 0.8 s | — | — |
| **FCP** (First Contentful Paint) — supporting | ≤ 1.8 s | — | — |

> INP replaced FID (First Input Delay) as a Core Web Vital in March 2024.

## Rules

### Measurement and verdict

- [invariant · desired] **Field data (CrUX) is the ranking signal** — lab scores (Lighthouse/PSI) are diagnostic tools, not the verdict. A page that passes Lighthouse but fails CrUX thresholds at the 75th percentile is still failing Core Web Vitals.
  - ✅ do: use the CrUX Dashboard, Search Console Core Web Vitals report, or the CrUX API to verify real-user data.
  - ❌ don't: report "Core Web Vitals pass" based solely on a Lighthouse score — lab data measures a single synthetic run, not the distribution of real user sessions.
- [preference · desired] Run lab tools (Lighthouse, WebPageTest) in **throttled mobile conditions** (Moto G Power equivalent, 4G) to approximate the slowest cohort of real users.

### LCP optimisation

- [invariant · desired] **Identify the LCP element** (image, `<img>`, hero `background-image` declared via inline style, `<video>` poster, or largest text block) before optimising — the LCP element must be confirmed, not assumed.
- [invariant · desired] The LCP resource **must not be lazy-loaded** — `loading="lazy"` on the LCP image delays discovery and inflates LCP.
  - ✅ do: omit `loading="lazy"` on the LCP image; add `fetchpriority="high"` instead.
  - ❌ don't: apply `loading="lazy"` uniformly to all images without excluding the LCP candidate.
- [invariant · desired] Add `fetchpriority="high"` to the `<img>` (or `<link rel="preload">`) for the LCP resource so the browser deprioritises it less against competing requests.
  - ✅ do: `<img src="hero.webp" fetchpriority="high" alt="...">`
  - ❌ don't: leave the LCP image at default network priority while scripts and stylesheets compete for bandwidth.
- [invariant · desired] **Preload the LCP resource** with `<link rel="preload" as="image" href="...">` in the `<head>` when the resource is not immediately discoverable in the initial HTML (e.g. background images, carousel images injected by JS).
- [invariant · desired] **Reduce TTFB** — LCP cannot begin until the first byte arrives. Target TTFB ≤ 0.8 s (the Good threshold). Use a CDN, edge caching, or server-side rendering where applicable.
- [invariant · desired] **Eliminate render-blocking resources** — parser-blocking `<script>` tags and `<link rel="stylesheet">` in the `<head>` delay FCP and push out LCP. Defer non-critical scripts; inline critical CSS.
  - ✅ do: `<script src="analytics.js" defer>` for non-critical scripts.
  - ❌ don't: load third-party scripts synchronously in the `<head>` when they are not required for above-the-fold rendering.
- [preference · desired] Use the **LCP subpart breakdown** for root-cause analysis: (1) TTFB, (2) resource-load delay (time from TTFB to LCP resource request start), (3) resource load duration, (4) render delay (time from resource loaded to paint). Address the largest subpart first.

### INP optimisation

- [invariant · desired] **Break up long tasks** — any JavaScript task that runs longer than 50 ms on the main thread blocks interaction response. Split long tasks using `setTimeout`, `scheduler.yield()`, or `requestIdleCallback`.
  - ✅ do: use `scheduler.yield()` (or `await new Promise(r => setTimeout(r))`) inside loops that process large data sets.
  - ❌ don't: synchronously process thousands of DOM nodes or data records in a single task.
- [invariant · desired] **Yield to the main thread** between interaction handler work and rendering — after handling user input, yield before running non-essential follow-up logic so the browser can paint the visual response quickly.
- [invariant · desired] **Minimise hydration cost** — heavy client-side hydration inflates INP on page load. Defer hydration of off-screen components; use partial/progressive/lazy hydration patterns where the stack supports them.
- [preference · desired] Profile INP using the Long Animation Frames (LoAF) API or Chrome DevTools Performance panel to identify the specific interaction and script causing the delay before optimising.

### CLS optimisation

- [invariant · desired] **Set explicit `width` and `height` attributes** on all `<img>` and `<video>` elements — or use CSS `aspect-ratio` — so the browser reserves layout space before the resource loads.
  - ✅ do: `<img src="photo.jpg" width="800" height="600" alt="...">`
  - ❌ don't: omit dimensions and rely on the browser to reflow after the image loads.
- [invariant · desired] **Reserve space for dynamically injected content** (ads, banners, embeds, cookie notices) — insert a fixed-size placeholder in the DOM before the content loads so it does not push existing content.
  - ✅ do: use a `min-height` container for ad slots so the page does not shift when an ad loads.
  - ❌ don't: inject a full-width banner above the fold after the page has painted — this is a common high-CLS pattern.
- [invariant · desired] Use `font-display: optional` or `font-display: swap` to prevent invisible text during font load (FOIT) and minimise layout shift from font metric differences. Prefer `optional` when layout stability is the priority.
- [invariant · desired] Ensure **bfcache (back/forward cache) eligibility** — pages that fail bfcache reload from scratch on back-navigation, generating a new CLS event. Remove `unload` event listeners; avoid `Cache-Control: no-store` on navigated pages; close open database connections before unload.
  - ✅ do: use `pagehide` instead of `unload`; test bfcache eligibility in Chrome DevTools → Application → Back/forward cache.
  - ❌ don't: attach `window.addEventListener('unload', ...)` — it is a known bfcache blocker.
- [anti-pattern · desired] Do not rely on CSS `transform` animations for layout-affecting elements without also setting `will-change: transform` — unexpected compositing changes can trigger layout shifts on low-end devices.

### Speculation Rules and navigation performance

- [preference · desired] Use the **Speculation Rules API** (`<script type="speculationrules">`) to prefetch or prerender likely next navigations — this can make subsequent page loads feel near-instant and significantly reduce LCP on landing.
  - ✅ do: prerender the most common next page (e.g. a product detail page from a listing page) when confidence of navigation is high.
  - ❌ don't: prerender every link unconditionally — bandwidth cost and origin server load scale with the number of prerenders.
- [invariant · desired] **Migrate deprecated `rel="prerender"`** to Speculation Rules — `<link rel="prerender">` is no longer supported in Chromium; use `{"prerender": [{"source": "list", "urls": [...]}]}` instead.

### HTTPS

- [invariant · desired] Serve all pages and resources over **HTTPS** — HTTP pages are not eligible for many browser features and may be demoted in search results.
- [invariant · desired] **No mixed content** — every sub-resource (images, scripts, stylesheets, fonts, XHR, WebSocket) must load over HTTPS when the page is served over HTTPS. Mixed content causes browser warnings and blocks active content.
  - ✅ do: audit all `src`, `href`, and API endpoint URLs for `http://` references; upgrade them to `https://`.
  - ❌ don't: hard-code `http://` asset URLs in templates or CMS content.
- [invariant · desired] **Sitemap and hreflang URLs must use HTTPS** — `http://` URLs in the sitemap or hreflang attributes signal inconsistency and may cause crawlers to follow redirect chains unnecessarily.
- [preference · desired] Add **HSTS** (`Strict-Transport-Security: max-age=31536000; includeSubDomains`) once HTTPS is stable, and submit the domain to the HSTS preload list to eliminate the first-visit HTTP redirect.

### Security headers

> Security headers are implementable hygiene and improve user trust. They are not direct ranking factors; do not overstate their SEO impact.

- [invariant · desired] **`Strict-Transport-Security`** — enforce HTTPS at the browser level; prevents HTTPS-downgrade attacks.
  - ✅ do: `Strict-Transport-Security: max-age=31536000; includeSubDomains`
- [invariant · desired] **`X-Content-Type-Options: nosniff`** — prevents browsers from MIME-sniffing responses away from the declared content type, reducing script-injection risk.
- [invariant · desired] **`X-Frame-Options: SAMEORIGIN`** (or `Content-Security-Policy: frame-ancestors 'self'`) — prevents the page from being embedded in a third-party iframe (clickjacking protection).
- [invariant · desired] **`Referrer-Policy: strict-origin-when-cross-origin`** (or stricter) — limits referrer leakage to third parties without breaking analytics on same-origin navigation.
- [preference · desired] **`Content-Security-Policy`** — reduces XSS attack surface. Start with a report-only policy (`Content-Security-Policy-Report-Only`) to audit violations before enforcing.
  - ✅ do: enforce CSP in blocking mode only after validating the policy in report-only mode.
  - ❌ don't: set an overly broad CSP (`default-src *`) — it provides no protection and wastes the header.

### Mobile-friendliness

- [invariant · desired] Include a **viewport meta tag** in every page `<head>`: `<meta name="viewport" content="width=device-width, initial-scale=1">`. Without it, mobile browsers render at desktop width and scale down, making the page unusable on touch screens.
  - ❌ don't: use `user-scalable=no` or `maximum-scale=1` — these prevent users from zooming and can fail accessibility audits.
- [invariant · desired] **Tap targets must be at least 48 × 48 px** with adequate spacing — small or overlapping tap targets cause mis-taps on mobile and are flagged by Lighthouse.
- [invariant · desired] **Avoid intrusive interstitials** — full-screen popups, overlays, or banners that obscure main content immediately on page load or during navigation are a negative page-experience signal. Cookie consent notices that are legally required are exempt.
  - ✅ do: show a small, easily dismissible banner anchored to the bottom or top of the viewport.
  - ❌ don't: show a full-page interstitial that hides the main content before the user has read any of it.
- [invariant · desired] **Control ad density** — pages where ads occupy more space than editorial content above the fold are a negative signal. Keep above-the-fold content predominantly editorial.
  - ❌ don't: stack multiple ad slots immediately below the navigation before any editorial content appears.
- [preference · desired] Test mobile rendering using Chrome DevTools device emulation and validate with the Search Console Mobile Usability report to catch issues at scale.

## Related skills (by name)

- javascript-seo
- media-seo
- url-structure
