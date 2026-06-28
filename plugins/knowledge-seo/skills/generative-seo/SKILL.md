---
name: generative-seo
description: Use ONLY for optimizing for AI answer engines / generative search (AI Overviews, ChatGPT Search, Perplexity, Copilot) — llms.txt, AI-crawler access, entity authority. NOT classic meta/schema (those are the meta-tags and structured-data skills).
---

# Generative SEO (GEO / AEO) — stub

Generative Engine Optimization (GEO) — also called Answer Engine Optimization (AEO) —
covers the technical signals that influence whether an AI answer engine cites, quotes, or
surfaces a site when generating responses: machine-readable content declarations, crawl
access for AI agents, structured entity signals, and server-side rendering requirements.
It is distinct from classic SERP SEO (ranking in a ten-blue-links result page) because the
retrieval pipeline, the ranking surface, and the citation mechanisms are fundamentally
different. This skill is a **stub**; the detailed rules will be filled in during the next
build pass.

## TODO (next pass)

- **`llms.txt` (+ optional `.md` companion mirrors)** — a community proposal for a
  plain-text file at `/llms.txt` that lists content an AI system is explicitly invited to
  read. **Caveat:** no major AI answer engine has publicly confirmed it reads this file;
  the spec is not standardised. Cost and risk are low (file to maintain), but benefit is
  uncertain. Treat as optional, not a rule.

- **AI-crawler access** — a deliberate per-bot allow/deny matrix (a business and legal
  decision — licensing, scraping terms, brand risk — NOT a blanket allow or blanket deny).
  Cross-link: `robots` skill handles the `robots.txt` mechanics and lists common AI-crawler
  user-agent tokens.

- **SSR precondition** — many AI fetchers may not execute JavaScript reliably; critical
  content (headings, body text, structured data) must be present in the initial HTML
  response, not injected by client-side rendering. Cross-link: `javascript-seo` skill
  covers rendering-mode requirements and testing approaches; do not duplicate here.

- **Entity authority** — consistent, structured entity signals (name, description,
  `sameAs` links) that help AI systems identify and attribute the site as an authoritative
  source. Cross-link: `structured-data` skill owns the markup rules; do not duplicate here.

- **Agent-friendly markup** — structural and semantic HTML choices that improve
  parsability for AI retrieval agents (landmarks, heading hierarchy, clean DOM output).
  Cross-link: `javascript-seo` skill; do not duplicate here.

- **RSL 1.0 machine-readable AI-licensing** — an emerging standard for declaring
  AI-usage rights inside a machine-readable manifest. **Caveat:** early-stage, adoption
  is low, no engine has confirmed reading it. Optional; document status when building out.

## Out of scope

Editorial GEO tactics — answer-first prose structure, Q&A formatting, TL;DR blocks,
freshness strategies, brand-mention acquisition, PR-driven citation building, and
passage-length "scoring" — are **not** in the technical scope of this skill. Any
passage-length figure cited elsewhere is a labeled heuristic observed in research, never
a hard technical rule enforced here.

## Related skills (by name)

- `robots` — `robots.txt` AI-crawler allow/deny matrix and user-agent tokens
- `javascript-seo` — rendering modes, SSR requirements, agent-friendly markup
- `structured-data` — entity markup, `sameAs`, schema vocabulary
