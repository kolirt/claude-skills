---
name: media-seo
description: Use when adding images or video — alt/filenames, responsive/modern formats, image & video sitemaps, AI-image labeling, VideoObject.
---

# media-seo — image and video SEO

Stack-independent rules for making images and video crawlable, well-described, and
performant. Covers markup, file hygiene, modern formats, sitemaps, structured data,
and disclosure requirements for AI-generated imagery.

## Rules

### Image crawlability

- [invariant · desired] Serve images in a standard `<img src="...">` element with an
  absolute or root-relative URL that returns the image directly. Crawlers do not execute
  JavaScript to resolve dynamic `src` values or CSS `background-image` declarations.
  - ✅ do: `<img src="/images/product-front.webp" alt="...">`
  - ❌ don't: inject the `src` attribute via a script or rely solely on a CSS
    `background-image` for content images — crawlers will not see them.
- [invariant · desired] Use **descriptive, keyword-relevant filenames** separated by
  hyphens — e.g. `red-leather-wallet-open.webp` instead of `IMG_4821.jpg`. Filenames
  appear in image-search results and in the image URL indexed by crawlers.
- [invariant · desired] Every `<img>` that conveys content must carry a **descriptive
  `alt` attribute** that describes what the image shows in the context of the surrounding
  text. Empty `alt=""` is correct only for purely decorative images.
  - ✅ do: `alt="Open red leather wallet showing card slots and coin pocket"`
  - ❌ don't: `alt="image"`, `alt="photo"`, keyword-stuffed alt text, or omitting `alt`
    entirely — all hurt accessibility and provide no crawlable signal.
- [invariant · desired] Place content images **near the relevant text** on the page.
  Crawlers use proximity to infer relevance; an image isolated from its topic receives
  weaker context signals.

### Responsive images

- [preference · desired] Use `srcset` (or `<picture>` with `<source>`) to serve
  appropriately sized images for the viewport and device pixel ratio. This reduces
  bandwidth, improves LCP, and is a positive page-experience signal.
  - ✅ do: `<img src="hero-800.webp" srcset="hero-400.webp 400w, hero-800.webp 800w,
    hero-1600.webp 1600w" sizes="(max-width: 600px) 100vw, 800px" alt="...">`
- [invariant · desired] Set explicit **`width` and `height` attributes** on every `<img>`
  (or use CSS `aspect-ratio`) so the browser reserves layout space before the image
  loads. Missing dimensions cause layout shift (CLS). See `page-experience` for the CLS
  threshold.

### Modern image formats

- [invariant · desired] Serve images in **WebP with an AVIF offer and a JPEG/PNG
  fallback**. Use `<picture>` to let the browser select the best supported format:

  ```html
  <picture>
    <source srcset="photo.avif" type="image/avif">
    <source srcset="photo.webp" type="image/webp">
    <img src="photo.jpg" alt="Descriptive text" width="800" height="600"
         decoding="async">
  </picture>
  ```

  AVIF achieves ~50% smaller files than JPEG at equivalent quality; WebP achieves
  ~30% savings. The fallback `<img>` ensures compatibility with older browsers.
- [anti-pattern · desired] Do not serve only AVIF without a fallback — Safari < 16 and
  older Android WebViews do not support it. Always include the WebP source and the
  legacy `<img>` fallback.

### Loading and decode behaviour

- [preference · desired] Add `decoding="async"` to `<img>` elements that are not in the
  initial viewport. This hints to the browser that image decoding can be done off the
  critical path, reducing main-thread contention.
  - ✅ do: `<img src="article-inline.webp" decoding="async" alt="...">`
- [invariant · desired] **Do not lazy-load the LCP image.** Applying `loading="lazy"` to
  the Largest Contentful Paint element delays its discovery and inflates the LCP metric,
  which is a Core Web Vitals ranking signal. See `page-experience` for LCP optimisation
  rules including `fetchpriority="high"`.
  - ✅ do: omit `loading` (or set `loading="eager"`) and add `fetchpriority="high"` on
    the hero/LCP image.
  - ❌ don't: apply `loading="lazy"` to all images without excluding the LCP candidate.

### Image sitemap

- [preference · desired] Submit an **image sitemap** (or embed `<image:image>` entries
  in the main sitemap) so Google can discover images that may not be reachable through
  regular crawling — especially images loaded via JavaScript or behind authentication.

  ```xml
  <?xml version="1.0" encoding="UTF-8"?>
  <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
          xmlns:image="http://www.google.com/schemas/sitemap-image/1.1">
    <url>
      <loc>https://example.com/products/red-wallet</loc>
      <image:image>
        <image:loc>https://example.com/images/red-leather-wallet-open.webp</image:loc>
        <image:title>Open red leather wallet</image:title>
        <image:caption>Front view of the red leather wallet showing card slots</image:caption>
      </image:image>
    </url>
  </urlset>
  ```

  Each `<url>` can contain up to 1,000 `<image:image>` child elements. Sitemap
  structure and submission rules are covered by the `sitemaps` skill.

### ImageObject structured data (licensing and metadata)

- [preference · desired] Add `ImageObject` JSON-LD to pages that feature original or
  licensed photography to expose creator, license, and acquisition metadata in Google
  Images.

  ```json
  {
    "@context": "https://schema.org",
    "@type": "ImageObject",
    "contentUrl": "https://example.com/images/red-leather-wallet-open.webp",
    "name": "Open red leather wallet",
    "description": "Front view showing card slots and coin pocket",
    "creator": {
      "@type": "Person",
      "name": "Photographer Name"
    },
    "license": "https://creativecommons.org/licenses/by/4.0/",
    "acquireLicensePage": "https://example.com/licensing"
  }
  ```

  Full structured-data authoring rules are in the `structured-data` skill.

### IPTC/XMP image metadata

- [preference · desired] Embed **IPTC and XMP metadata** inside image files (using a
  tool such as ExifTool or an image-editing application) to carry creator, copyright,
  and description information directly in the file. This metadata persists when the
  image is downloaded and re-shared, and is read by image-search pipelines.
  - ✅ do: set `Creator`, `CopyrightNotice`, `Description`, and `Keywords` in the
    IPTC IIM and XMP namespaces (`dc:creator`, `dc:rights`, `dc:description`).
  - ❌ don't: strip metadata with a bulk optimizer without first exporting a copy that
    retains the licensing fields.

### AI-generated image labeling

- [invariant · desired] Images generated or substantially modified by an AI model
  **must be labeled** using the IPTC standard field `DigitalSourceType` with the value
  `trainedAlgorithmicMedia` (full URI:
  `http://cv.iptc.org/newscodes/digitalsourcetype/trainedAlgorithmicMedia`). This
  satisfies the IPTC `TrainedAlgorithmicMedia` requirement and is read by Google and
  major news agencies.
  - ✅ do: embed the `Iptc4xmpExt:DigitalSourceType` XMP field in the image file and
    include `additionalProperty` in the `ImageObject` schema pointing to the same value.
  - ❌ don't: publish AI-generated product images without this label — Google Merchant
    Center and image-search surfaces use the `DigitalSourceType` signal for transparency
    enforcement.
- [preference · desired] For Google Merchant Center product feeds, also set the
  `image_link` attribute and — where the feed format supports it — declare
  `digital_source_type: trained_algorithmic_media` to surface the AI-generation
  disclosure in Shopping results.

---

## Video SEO

### VideoObject structured data

- [invariant · desired] Add a `VideoObject` JSON-LD block to every page that features
  video content. The minimum required properties are `name`, `description`,
  `thumbnailUrl`, and `uploadDate`; also include `contentUrl` (a direct link to a
  fetchable video file) and/or `embedUrl`.

  ```json
  {
    "@context": "https://schema.org",
    "@type": "VideoObject",
    "name": "How to fold a leather wallet insert",
    "description": "Step-by-step guide for inserting the card organiser into the wallet.",
    "thumbnailUrl": "https://example.com/videos/thumbnails/wallet-fold-thumb.jpg",
    "uploadDate": "2024-03-15T09:00:00+00:00",
    "duration": "PT3M42S",
    "contentUrl": "https://example.com/videos/wallet-fold.mp4",
    "embedUrl": "https://example.com/embed/wallet-fold"
  }
  ```

  Full structured-data rules are in the `structured-data` skill.

### Stable URLs

- [invariant · desired] The **watch-page URL**, **thumbnail URL**, and **video file URL**
  must all be stable and permanently accessible. Google caches thumbnails and video
  metadata — changing URLs after indexing causes the video to be de-indexed and
  re-crawled from scratch, losing any accumulated signals.
  - ✅ do: use content-addressed or slug-based URLs (`/videos/wallet-fold`) that do not
    change when the video is re-encoded or a page is redesigned.
  - ❌ don't: use CDN signed URLs with expiring tokens as the `contentUrl` or
    `thumbnailUrl` — they become invalid before the next crawl.
- [invariant · desired] The `contentUrl` must point to a **directly fetchable video
  file** (MP4, WebM, etc.) that Googlebot can download without authentication, JavaScript
  execution, or a redirect chain. A player embed alone is not sufficient for video rich
  results.

### Video sitemap

- [preference · desired] Submit a **video sitemap** with `xmlns:video` entries to
  provide structured metadata alongside each watch-page URL. This accelerates discovery
  and improves eligibility for video rich results.

  ```xml
  <?xml version="1.0" encoding="UTF-8"?>
  <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
          xmlns:video="http://www.google.com/schemas/sitemap-video/1.1">
    <url>
      <loc>https://example.com/videos/wallet-fold</loc>
      <video:video>
        <video:thumbnail_loc>
          https://example.com/videos/thumbnails/wallet-fold-thumb.jpg
        </video:thumbnail_loc>
        <video:title>How to fold a leather wallet insert</video:title>
        <video:description>
          Step-by-step guide for inserting the card organiser into the wallet.
        </video:description>
        <video:content_loc>https://example.com/videos/wallet-fold.mp4</video:content_loc>
        <video:duration>222</video:duration>
        <video:publication_date>2024-03-15T09:00:00+00:00</video:publication_date>
      </video:video>
    </url>
  </urlset>
  ```

  Sitemap structure and submission rules are in the `sitemaps` skill.
- [anti-pattern · desired] Do not omit `<video:content_loc>` and rely solely on
  `<video:player_loc>` — without a direct file URL Google cannot verify the video is
  accessible and may exclude the entry from video rich results.

## Related skills (by name)

- `structured-data` — JSON-LD authoring, `ImageObject`, `VideoObject`, and rich-result
  eligibility rules
- `page-experience` — LCP optimisation, `fetchpriority`, lazy-loading exclusions, CLS
  from unsized images
- `sitemaps` — XML sitemap structure, image and video sitemap extensions, submission
