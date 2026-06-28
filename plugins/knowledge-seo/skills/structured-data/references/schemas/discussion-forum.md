# DiscussionForumPosting — forum threads and social media posts
**When:** Page is an original forum post or social media post that is the topic of a discussion thread.

## Fields
Required (Google) on `DiscussionForumPosting`:
- `url` — canonical URL of the post.
- `author` — `Person` or `Organization` with at least `.name`.
- `datePublished` — ISO 8601 datetime of the original post.
- One of `text`, `image`, or `video` — the primary content of the post.

Recommended on `DiscussionForumPosting`:
- `author.url` — link to the author's profile page (mark that page with `ProfilePage`).
- `headline` — post title, if present.
- `text` — full text content of the post.
- `image` — `ImageObject` if the post is image-based.
- `video` — `VideoObject` if the post is video-based.
- `commentCount` — total reply/comment count.
- `comment` — `Comment` objects for individual replies.
- `interactionStatistic` — `InteractionCounter` for upvotes, shares.
- `sharedContent` — content linked or embedded in the post (`WebPage`, `ImageObject`, `VideoObject`, `Comment`).

Recommended on `Comment` (reply):
- `text` — full text.
- `author` — `Person` with `.name` and optionally `.url`.
- `datePublished` — ISO 8601 datetime.
- `url` — deep link to the specific comment.
- `upvoteCount` — net vote count.

## Input contract (neutral, not an entity)
```ts
interface DiscussionForumPostingSchemaInput {
  url: string;
  authorName: string;
  authorUrl?: string;
  datePublished: string;         // ISO 8601
  headline?: string;
  text?: string;
  commentCount?: number;
  upvoteCount?: number;
  comments?: Array<{
    text: string;
    authorName: string;
    authorUrl?: string;
    datePublished: string;
    url?: string;
    upvoteCount?: number;
  }>;
  sharedUrl?: string;            // URL shared in the post
}
```

## JSON-LD skeleton
```json
{
  "@context": "https://schema.org",
  "@type": "DiscussionForumPosting",
  "url": "https://example.com/forum/thread/123",
  "headline": "Best practices for caching API responses",
  "text": "I've been working on a REST API and wondering about optimal caching strategies...",
  "datePublished": "2025-04-01T10:00:00+00:00",
  "author": {
    "@type": "Person",
    "name": "Jane Doe",
    "url": "https://example.com/profile/janedoe"
  },
  "interactionStatistic": {
    "@type": "InteractionCounter",
    "interactionType": "https://schema.org/LikeAction",
    "userInteractionCount": 34
  },
  "commentCount": 5,
  "comment": [{
    "@type": "Comment",
    "text": "Use ETags and Cache-Control headers.",
    "datePublished": "2025-04-01T11:00:00+00:00",
    "url": "https://example.com/forum/thread/123#comment-1",
    "author": {
      "@type": "Person",
      "name": "John Smith",
      "url": "https://example.com/profile/johnsmith"
    },
    "upvoteCount": 12
  }]
}
```

## Pitfalls
- `SocialMediaPosting` is also supported but `DiscussionForumPosting` is the preferred type for forum content — use it unless the platform is explicitly a social media site.
- At least one of `text`, `image`, or `video` must be present unless the post links to an external URL via `sharedContent`.
- `commentCount` should reflect the total count, including comments not marked up — if only some comments are in the JSON-LD, `commentCount` must still equal the total.
- Nested replies go inside `Comment.comment` recursively; do not flatten all replies at the top level of the post's `comment` array.
- Use `DiscussionForumPosting` only for the original top-level post; replies use `Comment`.
- If content was AI-generated, add `digitalSourceType` on the post or comment to declare the source type.
- `sharedContent` of type `WebPage` requires only a `url`; for `ImageObject` or `VideoObject`, follow their respective schemas.
