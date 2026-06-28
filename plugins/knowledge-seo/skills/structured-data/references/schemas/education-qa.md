# Education Q&A — flashcard and quiz markup

**When:** the page presents educational flashcard-style questions with single definitive answers (e.g. study guides, vocabulary drills, science fact checks) and you want Google to display the content in the Education Q&A rich result experience.

> This type is for **flashcard** educational content — one question, one correct answer. It is distinct from:
> - `QAPage` (community Q&A with multiple user answers, see `qapage.md`)
> - `FAQPage` (site FAQ authored by the publisher; rich result discontinued May 2026)

---

## Fields

### Quiz

Required: `name`, `hasPart` — array of `Question` nodes (one per flashcard).

Recommended: `about` (Thing — the educational topic), `educationalLevel` (e.g. `"high school"`, `"undergraduate"`), `assesses` (competency being assessed).

### Question (each flashcard, nested under `hasPart`)

Required: `eduQuestionType` — must be exactly the string `"Flashcard"`, `text` (the question text), `acceptedAnswer` (Answer node with `text`).

> Note: `Question` inside `Quiz.hasPart` uses `eduQuestionType: "Flashcard"` — this is different from `Question` inside `QAPage.mainEntity` (which does not use `eduQuestionType`).

---

## Input contract (neutral interface)

```ts
interface EducationQASchemaInput {
  quizName: string;
  about?: string;             // topic name
  educationalLevel?: string;  // e.g. "high school"
  flashcards: Array<{
    question: string;
    answer: string;
  }>;
}
```

---

## JSON-LD skeleton

```json
{
  "@context": "https://schema.org",
  "@type": "Quiz",
  "name": "Cell Biology Flashcards",
  "about": { "@type": "Thing", "name": "Cell Biology" },
  "educationalLevel": "high school",
  "hasPart": [
    {
      "@type": "Question",
      "eduQuestionType": "Flashcard",
      "text": "What structure controls what enters and exits the cell?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "The cell membrane (plasma membrane) controls what enters and exits the cell."
      }
    },
    {
      "@type": "Question",
      "eduQuestionType": "Flashcard",
      "text": "What organelle is known as the powerhouse of the cell?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "The mitochondrion is known as the powerhouse of the cell because it produces ATP through cellular respiration."
      }
    },
    {
      "@type": "Question",
      "eduQuestionType": "Flashcard",
      "text": "What is the function of the ribosome?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "Ribosomes synthesize proteins by translating messenger RNA (mRNA) into amino acid chains."
      }
    }
  ]
}
```

---

## Pitfalls

- **`eduQuestionType` must be exactly `"Flashcard"`.** Any other value (capitalisation variants, alternative strings) will cause the question to be skipped by Google's parser.
- **Only one `acceptedAnswer` per `Question`.** Unlike `QAPage`, where multiple answers are supported, each flashcard `Question` must have exactly one `acceptedAnswer`. Multiple `acceptedAnswer` properties on the same question are invalid for this type.
- **`hasPart` not `mainEntity`.** Education Q&A uses `Quiz.hasPart` to nest questions. Using `mainEntity` (the `FAQPage` / `QAPage` pattern) will not be recognised.
- **Content must be genuinely educational and factual.** Google's Education Q&A surface targets academic subject matter. Promotional or product-oriented content does not qualify.
- **Answers must be complete and correct.** The flashcard answer should be a self-contained, accurate response that a student could study from without needing additional context. Partial answers or "see the article for details" answers are not appropriate.
- **Questions and answers must be visible on the page.** Markup must correspond to content actually rendered and readable by users; hidden or dynamically blocked content violates Google's policies.
