# QAPage — community Q&A threads (single question, multiple answers)
**When:** Page contains exactly one question with one or more user-submitted answers (e.g. Stack Overflow-style threads, community help forums).

## Fields
Required (Google) on `Question` (via `mainEntity`):
- `text` — full text of the question.
- `answerCount` — total number of answers.
- `acceptedAnswer` or `suggestedAnswer` — at least one answer with `text`.

Recommended on `QAPage`:
- no `QAPage`-level required properties beyond `mainEntity`.

Recommended on `Question`:
- `author` — `Person` or `Organization` with `.name` and `.url`.
- `datePublished` — ISO 8601 datetime.
- `upvoteCount` — net vote count (upvotes minus downvotes).
- `image` — any inline images in the question.

Recommended on `Answer` / `Comment`:
- `text` — full answer text (required for the answer to be eligible).
- `author` — same shape as Question.author.
- `datePublished` — ISO 8601 datetime.
- `upvoteCount` — net vote count.
- `url` — deep link to the specific answer.

## Input contract (neutral, not an entity)
```ts
interface QAPageSchemaInput {
  questionText: string;
  answerCount: number;
  questionAuthorName?: string;
  questionAuthorUrl?: string;
  questionDatePublished?: string;    // ISO 8601
  questionUpvoteCount?: number;
  acceptedAnswer?: {
    text: string;
    authorName?: string;
    authorUrl?: string;
    datePublished?: string;
    upvoteCount?: number;
    url?: string;
  };
  suggestedAnswers?: Array<{
    text: string;
    authorName?: string;
    datePublished?: string;
    upvoteCount?: number;
    url?: string;
  }>;
}
```

## JSON-LD skeleton
```json
{
  "@context": "https://schema.org",
  "@type": "QAPage",
  "mainEntity": {
    "@type": "Question",
    "text": "How many teaspoons are in 1 cup?",
    "answerCount": 3,
    "upvoteCount": 12,
    "datePublished": "2025-01-10T08:00:00+00:00",
    "author": {
      "@type": "Person",
      "name": "Jane Doe",
      "url": "https://example.com/profile/janedoe"
    },
    "acceptedAnswer": {
      "@type": "Answer",
      "text": "There are 48 teaspoons in 1 cup.",
      "upvoteCount": 25,
      "datePublished": "2025-01-10T09:00:00+00:00",
      "url": "https://example.com/questions/1#answer-1",
      "author": {
        "@type": "Person",
        "name": "John Smith",
        "url": "https://example.com/profile/johnsmith"
      }
    },
    "suggestedAnswer": [{
      "@type": "Answer",
      "text": "48 teaspoons equal one cup.",
      "upvoteCount": 5,
      "datePublished": "2025-01-11T10:00:00+00:00",
      "url": "https://example.com/questions/1#answer-2",
      "author": {
        "@type": "Person",
        "name": "Alice Jones"
      }
    }]
  }
}
```

## Pitfalls
- `QAPage` is for pages with one question and multiple user answers — not for FAQ pages (use `FAQPage`) or educational Q&A (use `Quiz`).
- The `text` of each answer must be the full answer, not a snippet — Google will not show a truncated answer.
- `acceptedAnswer` is for the single community-selected or author-accepted answer; `suggestedAnswer` is for all other answers. Use the correct property — swapping them causes ineligibility.
- `upvoteCount` should be the net value (upvotes minus downvotes), not raw upvote count.
- `answerCount` must match the actual number of answers rendered on the page.
- If answers contain AI-generated content, add `digitalSourceType` with the appropriate `IPTCDigitalSourceEnumeration` value — Google may downgrade or demote AI-generated answers.
- Do not add `QAPage` to pages that aggregate multiple questions; each `QAPage` represents one question thread.
