# VideoObject — video content pages and embedded videos
**When:** Page features a video as primary or prominent content; also referenced by media-seo skill for video SEO.

## Fields
Required (Google): `name`, `thumbnailUrl`, `uploadDate`.

Recommended:
- `description` — human-readable summary of the video.
- `contentUrl` — direct URL to the video file (most effective for indexing).
- `embedUrl` — URL of an embeddable player (fallback when `contentUrl` is unavailable).
- `duration` — ISO 8601 duration (e.g. `PT3M42S`).
- `expires` — ISO 8601 date after which the video is no longer available.
- `hasPart` — `Clip` objects for key moments / chapter markers.
- `interactionStatistic` — `InteractionCounter` for view count.
- `regionsAllowed` — ISO 3166 country codes if geo-restricted.
- `requiresSubscription` — `Boolean` if login/subscription is needed.

## Input contract (neutral, not an entity)
```ts
interface VideoObjectSchemaInput {
  name: string;
  thumbnailUrl: string;        // unique per video; crawlable
  uploadDate: string;          // ISO 8601 with timezone
  description?: string;
  contentUrl?: string;         // direct video file URL
  embedUrl?: string;           // embeddable player URL
  duration?: string;           // ISO 8601, e.g. "PT3M42S"
  expires?: string;            // ISO 8601 date
  viewCount?: number;
}
```

## JSON-LD skeleton
```json
{
  "@context": "https://schema.org",
  "@type": "VideoObject",
  "name": "Video title",
  "description": "A short description of the video.",
  "thumbnailUrl": "https://example.com/thumbnails/video-thumb.jpg",
  "uploadDate": "2025-03-15T09:00:00+00:00",
  "duration": "PT3M42S",
  "contentUrl": "https://example.com/videos/video.mp4",
  "embedUrl": "https://example.com/embed/video",
  "interactionStatistic": {
    "@type": "InteractionCounter",
    "interactionType": "https://schema.org/WatchAction",
    "userInteractionCount": 12000
  }
}
```

## Pitfalls
- `thumbnailUrl` must be unique per video and resolve to a crawlable image; generic site-wide thumbnails cause the rich result to be dropped.
- `uploadDate` is the original publish date, not a re-upload date; inconsistency with page metadata can invalidate the result.
- `description` is required by Google's video indexing pipeline (though listed as recommended for the rich result) — always include it.
- If using `Clip` for key moments, each `Clip` needs `name`, `startOffset`, `endOffset`, and `url`.
- `contentUrl` takes priority over `embedUrl` for Googlebot video fetching; provide both when possible.
- Do not add a `VideoObject` to a page where video is not the primary content — it misleads crawlers.
- Duration format must be ISO 8601 (`PT#H#M#S`), not seconds as a plain integer.
