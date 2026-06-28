# FAQPage — frequently asked questions markup

**When:** the page presents a list of questions with their full answers expanded inline, and you want to signal Q&A structure to AI systems and search engines.

> **IMPORTANT — Rich result discontinued (May 7, 2026):** Google stopped showing FAQPage rich results for all sites as of May 7, 2026. FAQPage markup no longer produces expandable FAQ snippets in Google Search results. Do NOT implement FAQPage expecting a rich-result display benefit.
>
> **Why to still use it:** FAQPage markup remains valuable as a structured signal for AI extraction (ChatGPT, Gemini, Perplexity, and other LLM-powered tools parse schema.org markup to understand Q&A structure), for internal tooling, and for potential future re-enablement. It does not harm performance. Implement it for AI/entity signal — not for Google rich results.

---

## Fields

### FAQPage

Required: `mainEntity` — array of `Question` nodes (one per FAQ item).

### Question

Required: `name` (Text — the question text), `acceptedAnswer` (Answer node).

### Answer

Required: `text` (Text — the full answer; HTML is stripped, so use plain text or basic formatting).

Recommended on `Question`: `@id` (anchor URL so tools can deep-link to the specific Q&A pair).

---

## Input contract (neutral interface)

```ts
interface FAQPageSchemaInput {
  questions: Array<{
    question: string;
    answer: string;       // plain text; HTML tags are stripped
    id?: string;          // anchor URL for deep-linking, e.g. "https://example.com/faq#q-returns"
  }>;
}
```

---

## JSON-LD skeleton

```json
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    {
      "@type": "Question",
      "@id": "https://example.com/faq#q-returns",
      "name": "What is your return policy?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "You may return any item within 30 days of purchase for a full refund, provided the item is in its original condition and packaging. To initiate a return, contact our support team at support@example.com."
      }
    },
    {
      "@type": "Question",
      "@id": "https://example.com/faq#q-shipping",
      "name": "How long does shipping take?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "Standard shipping takes 3 to 5 business days. Express shipping (1 to 2 business days) is available at checkout for an additional fee."
      }
    },
    {
      "@type": "Question",
      "@id": "https://example.com/faq#q-international",
      "name": "Do you ship internationally?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "Yes, we ship to over 50 countries. International delivery typically takes 7 to 14 business days. Import duties and taxes are the responsibility of the recipient."
      }
    }
  ]
}
```

---

## Pitfalls

- **Do not use FAQPage expecting Google rich results.** The FAQ rich result was discontinued for all sites on May 7, 2026. Implementing FAQPage for rich-result benefit wastes effort; implement it for AI extraction and structure signals only.
- **`mainEntity` not `hasPart`.** The correct property is `mainEntity` (array of Questions). Using `hasPart` is a common mistake carried over from Education Q&A (`Quiz`) and will not be recognised by Google's parser.
- **`name` holds the question, not `text`.** Use `name` for the question text on `Question` nodes. This is counterintuitive compared to other schema types where `text` is the content.
- **`acceptedAnswer.text` must be plain text.** HTML tags within `text` are stripped. Write answers in plain prose; line breaks and lists cannot be expressed via HTML here.
- **Each question–answer pair must be visible on the page.** Markup must correspond to actual visible content. Hidden content (display:none, conditional loads) violates Google's policies and can result in a manual action.
- **Do not use FAQPage for content where only one side provides answers.** FAQPage is for a site FAQ authored by the page owner. For community-generated Q&A (multiple user answers), use `QAPage` + `Question` instead.
- **Avoid keyword stuffing.** Artificially inserting keyword variations into `name` or `text` to manipulate search appearance violates Google's quality guidelines, even without the rich-result surface.
