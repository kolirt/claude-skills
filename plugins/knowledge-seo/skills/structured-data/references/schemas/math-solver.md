# MathSolver — mathematical problem-solving tool markup

**When:** the page hosts a tool that accepts a mathematical expression and returns a solution or step-by-step explanation, and you want the tool surfaced as a math solver rich result in Google Search.

---

## Fields

Required (Google): `name`, `url`, `potentialAction` (one or more `SolveMathAction` nodes).

Each `SolveMathAction` requires:
- `target` — URI template for the solver endpoint with a `{math_expression_string}` parameter (e.g. `"https://example.com/solve?q={math_expression_string}"`).
- `mathExpression-input` — the string `"required name=math_expression_string"` (marks the input slot).

Recommended: `usageInfo` (URL to privacy/terms page), `inLanguage` (BCP 47 language tag, e.g. `"en"`), `learningResourceType` (use value `"Math solver"`), `potentialAction.eduQuestionType` (array of problem types the solver handles, e.g. `"Polynomial Equation"`, `"Derivative"`, `"Trigonometric Equation"`).

> **Dual `@type`:** Mark up the page as both `MathSolver` and `LearningResource` to maximise eligibility across Google surfaces.

---

## Input contract (neutral interface)

```ts
interface MathSolverSchemaInput {
  name: string;
  url: string;
  usageInfo?: string;       // URL to privacy/terms page
  inLanguage?: string;      // BCP 47, e.g. "en"
  solverActions: Array<{
    /** URI template; must contain {math_expression_string} */
    targetTemplate: string;
    /** Problem types this endpoint handles */
    eduQuestionType?: string | string[];
  }>;
}
```

---

## JSON-LD skeleton

### Single solver endpoint (multiple problem types)

```json
{
  "@context": "https://schema.org",
  "@type": ["MathSolver", "LearningResource"],
  "name": "Example Math Solver",
  "url": "https://example.com/math-solver",
  "usageInfo": "https://example.com/privacy",
  "inLanguage": "en",
  "learningResourceType": "Math solver",
  "potentialAction": [
    {
      "@type": "SolveMathAction",
      "target": "https://example.com/solve?q={math_expression_string}",
      "mathExpression-input": "required name=math_expression_string",
      "eduQuestionType": [
        "Polynomial Equation",
        "Derivative",
        "Linear Equation"
      ]
    }
  ]
}
```

### Multiple solver endpoints (separate problem types per endpoint)

```json
{
  "@context": "https://schema.org",
  "@type": ["MathSolver", "LearningResource"],
  "name": "Example Math Solver",
  "url": "https://example.com/math-solver",
  "usageInfo": "https://example.com/privacy",
  "inLanguage": "en",
  "learningResourceType": "Math solver",
  "potentialAction": [
    {
      "@type": "SolveMathAction",
      "target": "https://example.com/algebra?q={math_expression_string}",
      "mathExpression-input": "required name=math_expression_string",
      "eduQuestionType": "Polynomial Equation"
    },
    {
      "@type": "SolveMathAction",
      "target": "https://example.com/trig?q={math_expression_string}",
      "mathExpression-input": "required name=math_expression_string",
      "eduQuestionType": "Trigonometric Equation"
    }
  ]
}
```

### Multi-language: separate JSON-LD blocks per locale

When the solver is available in multiple languages, emit one complete JSON-LD block per language variant (separate `url`, separate `name`, separate `inLanguage`). Each block can be in the same `<script type="application/ld+json">` tag as an array or as separate script tags.

---

## Pitfalls

- **`@type` must be an array containing both `MathSolver` and `LearningResource`.** Using only `MathSolver` reduces eligibility for non-math-specific surfaces.
- **`target` URI template must use the exact placeholder `{math_expression_string}`.** The action schema requires this specific variable name; a different name causes the action to fail.
- **`mathExpression-input` is a hyphenated property name, not a nested object.** The value must be the exact string `"required name=math_expression_string"`. This is a schema.org action input annotation.
- **One block per language, not per page.** If the solver is available in Spanish at a different URL, emit a separate complete JSON-LD block for the Spanish variant with `"inLanguage": "es"` and its own `url` and `potentialAction.target`.
- **`eduQuestionType` values should match recognised math problem categories.** Google uses these to match user queries. Common values: `"Polynomial Equation"`, `"Derivative"`, `"Integral"`, `"Trigonometric Equation"`, `"Linear Equation"`, `"Quadratic Equation"`.
- **The solver endpoint must be functional and publicly accessible.** Google may test the action endpoint. A non-functional or gated endpoint can result in removal from the rich result.
