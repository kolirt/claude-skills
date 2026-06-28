# ProfilePage — user or author profile pages
**When:** Page is the primary profile for a person or organisation on a platform (social network, forum, CMS author page).

## Fields
Required (Google):
- `mainEntity` — `Person` or `Organization` object; the entity this profile page is about.
- `mainEntity.name` — the real name or primary identifier of the entity.

Recommended on `ProfilePage`:
- `dateCreated` — ISO 8601 datetime of when the account was created.
- `dateModified` — ISO 8601 datetime of last meaningful profile update.

Recommended on `mainEntity` (`Person` / `Organization`):
- `alternateName` — social media handle or alias.
- `description` — short byline or credential.
- `identifier` — platform-specific unique ID.
- `image` — URL of the avatar or profile photo.
- `sameAs` — array of URLs to external profiles for the same entity.
- `interactionStatistic` — `InteractionCounter` for received actions (FollowAction, LikeAction).
- `agentInteractionStatistic` — `InteractionCounter` for actions performed by the entity (WriteAction = post count).

## Input contract (neutral, not an entity)
```ts
interface ProfilePageSchemaInput {
  dateCreated?: string;         // ISO 8601
  dateModified?: string;        // ISO 8601
  entityType: 'Person' | 'Organization';
  name: string;
  alternateName?: string;       // handle / username
  description?: string;
  identifier?: string;
  image?: string;               // avatar URL
  sameAs?: string[];            // external profile URLs
  followCount?: number;
  likeCount?: number;
  postCount?: number;
}
```

## JSON-LD skeleton
```json
{
  "@context": "https://schema.org",
  "@type": "ProfilePage",
  "dateCreated": "2024-01-15T10:00:00-05:00",
  "dateModified": "2025-06-01T12:00:00-05:00",
  "mainEntity": {
    "@type": "Person",
    "name": "Jane Doe",
    "alternateName": "janedoe",
    "identifier": "987654321",
    "description": "Senior developer and open-source contributor",
    "image": "https://example.com/avatars/janedoe.jpg",
    "sameAs": [
      "https://example.com/authors/janedoe"
    ],
    "interactionStatistic": [{
      "@type": "InteractionCounter",
      "interactionType": "https://schema.org/FollowAction",
      "userInteractionCount": 450
    }],
    "agentInteractionStatistic": {
      "@type": "InteractionCounter",
      "interactionType": "https://schema.org/WriteAction",
      "userInteractionCount": 128
    }
  }
}
```

## Pitfalls
- `mainEntity` is required on `ProfilePage`; without it Google cannot associate the page with an entity.
- Use `Person` when the entity is an individual; use `Organization` for companies or teams. Default to `Person` if unknown.
- `sameAs` links must resolve and point to the same real-world entity — broken or mismatched links undermine entity disambiguation.
- `dateModified` should reflect meaningful human-edited changes, not automated metadata refreshes.
- Do not add `ProfilePage` markup to pages that are not the primary, canonical profile page for the entity.
- `interactionStatistic` tracks actions *received by* the entity; `agentInteractionStatistic` tracks actions *performed by* the entity — do not swap them.
