---
name: brainstorm
description: Brainstorm and plan a coding task before writing any code. Use whenever the user says "brainstorm", "давай подумаємо", "спланувати", describes a feature or refactor without asking for immediate implementation, or the task is vague. Do NOT use when the user asks to implement or clearly expects immediate code changes — a plain "add X" or "fix Y" is implementation, not brainstorming. Interviews the user one question at a time, then presents a concise self-contained plan in the conversation. Writes no code while brainstorming.
---

# Brainstorm & Plan

Interview the user until shared understanding, then present one short plan directly in the conversation. Write no code during this process. Create a plan file only if the user asks for one.

## Interview

1. Never explore the codebase yourself — delegate ALL code reading to a Sonnet subagent and have it return a short summary of findings, not raw file contents.
2. If a question can be answered by exploring the codebase, explore (via that subagent) instead of asking.
3. Walk down the design tree, resolving decisions in dependency order.
4. Ask one question at a time with the AskUserQuestion tool. For every question, offer your recommended answer first with a one-line reason.
5. Be relentless about vagueness: if an answer is fuzzy or leaves the decision ambiguous, do NOT move on — press on the same node with follow-up questions until the decision is concrete and unambiguous. Exception: stop pressing once the remaining uncertainty no longer changes the plan.
6. Stop when no unresolved decision would change the plan. If the task is already fully specified, skip the interview and go straight to the plan.

## Plan

Present the plan as a single markdown block, easy to copy into a fresh session. It must be self-contained: understandable by an agent that has NOT seen this conversation — including one running the `implement` skill.

- **Goal** — 1–3 sentences + success-criteria checklist
- **Context** — decisions made in the interview and key codebase facts (exact file paths, relevant APIs, conventions)
- **Approach** — chosen approach; rejected alternatives with one-line reasons
- **Steps** — numbered, concrete, verifiable, with real file paths; >12 steps means split the task
- **Out of scope** — what we agreed NOT to do
- **Risks / open questions** — only real ones

Then stop and wait. If the user gives feedback on the plan, update the plan; do not restart the full interview — but if the change introduces new unresolved decisions, ask targeted questions about that change only (same one-at-a-time rules).
On "go" the brainstorm phase is over and this skill's no-code constraint ends with it: proceed to implement the approved plan as a normal coding session, or suggest pasting the plan into a fresh session with the `implement` skill.

Answer in the user's language.
