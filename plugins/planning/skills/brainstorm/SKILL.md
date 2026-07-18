---
name: brainstorm
description: Brainstorm and plan a coding task before writing any code. Use whenever the user says "brainstorm", "давай подумаємо", "спланувати", describes a feature or refactor without asking for immediate implementation, or the task is vague. Do NOT use when the user asks to implement or clearly expects immediate code changes — a plain "add X" or "fix Y" is implementation, not brainstorming. Interviews the user one question at a time, then writes the plan to a file under docs/plans/ and offers it for review (chat-only in plan mode or if the user declines files). Writes no product code while brainstorming.
---

# Brainstorm & Plan

Confirm the task, interview the user until shared understanding, then produce one short
self-contained plan. The default path writes that plan to a file under `docs/plans/`, offers it for
review, and waits for an explicit chat "go". Two exceptions are terminal chat-only: native **plan
mode**, and a user who has **declined** files — there the plan is presented in the conversation and
no file is touched.

Writing the plan artifact — the plan file, `docs/plans/INDEX.md`, and the `CLAUDE.md` pointer — is
permitted and expected. Writing product or source code is forbidden until the user says "go".

## Task understanding gate

On receiving the task, before anything else: restate your understanding of it in 2–4 sentences and
wait for explicit confirmation. Only then proceed to the interview or the plan.

This gate always runs — including when the task looks fully specified. The fully-specified shortcut
below may skip the *interview*; it never skips this gate.

## Interview

1. Never explore the codebase yourself — delegate ALL code reading to a Sonnet subagent and have it return a short summary of findings, not raw file contents.
2. If a question can be answered by exploring the codebase, explore (via that subagent) instead of asking.
3. Walk down the design tree, resolving decisions in dependency order.
4. Ask exactly ONE question per AskUserQuestion call — the `questions` array must contain a single item. NEVER batch several questions into one call even though the tool allows up to 4: every answer reshapes the design tree, and the next question must be able to react to the previous answer. For every question, offer your recommended answer first with a one-line reason.
5. Be relentless about vagueness: if an answer is fuzzy or leaves the decision ambiguous, do NOT move on — press on the same node with follow-up questions until the decision is concrete and unambiguous. Exception: stop pressing once the remaining uncertainty no longer changes the plan.
6. If the user asks a question — or raises a concern — between interview questions, stop the interview and answer it fully first. Then resume by naming the next open decision out loud and continuing one question at a time. An answer the user embedded alongside their question still counts; do not re-ask it.
7. Stop when no unresolved decision would change the plan. If the task is already fully specified, skip the interview and go straight to the plan.

## Plan

The plan opens with an H1 `# Plan: <title>` and contains:

- **Goal** — 1–3 sentences + success-criteria checklist
- **Context** — decisions made in the interview and key codebase facts (exact file paths, relevant APIs, conventions)
- **Approach** — chosen approach; rejected alternatives with one-line reasons
- **Steps** — numbered, concrete, verifiable, with real file paths; >12 steps means split the task
- **Out of scope** — what we agreed NOT to do
- **Risks / open questions** — only real ones

It must be self-contained: understandable by an agent that has NOT seen this conversation —
including one running the `implement` skill. This contract is identical whether the plan is written
to a file or presented in chat.

### Terminal chat-only branches

Check these first. If either holds, present the plan as a single markdown block in the conversation,
skip the file sections below entirely, and go to **On "go"**:

- **Native plan mode** — plan-mode context is present or writes are blocked. When unsure, attempt
  the write; a blocked or denied write means plan mode.
- **The user declined files.**

### Writing the plan file

Otherwise write the plan to `docs/plans/YYYY-MM-DD-<slug>.md`, creating directories as needed.

The title — the text AFTER the `# Plan: ` prefix, which never participates in either — is the single
source for the slug and for the INDEX.md link text. Slug: lowercase, ASCII-transliterated,
non-alphanumerics collapsed to single hyphens, trimmed; if transliteration yields no ASCII
alphanumerics the slug is literally `plan`; on a same-day collision append `-2`, `-3`, …. A
collision is either an existing file at that path OR an existing INDEX.md line already targeting it
— never take over a link target the project already uses.

**The filename is frozen at first write.** A later title revision never renames the file and never
re-runs collision handling — only the INDEX.md link text and hook are refreshed, so the link target
stays stable for the life of the plan.

### Index upkeep

Runs only if the plan file was actually written. Idempotent.

Ensure `docs/plans/INDEX.md` exists — first-create skeleton is a `# Plans` heading followed by the
list. Ensure it holds exactly one line for this plan, keyed by the markdown link target (the plan
filename): if one or more lines already point at that target, replace ALL of them with a single
canonical line; otherwise append

```
- [YYYY-MM-DD Title](YYYY-MM-DD-<slug>.md) — one-line hook
```

Ensure the repo-root `CLAUDE.md` — the project root, never a nested one — contains a pointer line
like `Plans history: docs/plans/INDEX.md — check before planning similar tasks`. Append it once if
absent; if the project root has no CLAUDE.md, create one containing only this pointer. Do not use an
`@`-import.

### Decline window

File writing is automatic — no pre-write permission prompt.

- **Declined before the first write** → the terminal chat-only branch above, zero file side effects.
- **Declined after the write** → an undo, not a branch. Delete the plan file and remove its INDEX.md
  line, then unwind exactly what this run added, in order:
  1. If INDEX.md now has no remaining plan list items AND this run created it, delete it — except
     when a pointer to it already existed before this run (a pre-existing pointer is not yours to
     remove), in which case keep the empty INDEX.md skeleton so that pointer never dangles.
  2. Remove the pointer this run added, whether or not INDEX.md survived (1) — an undone run leaves
     nothing of its own behind, and a deleted index must never keep a pointer. If this run created
     CLAUDE.md and it contains nothing beyond that pointer line, delete CLAUDE.md; if CLAUDE.md
     pre-existed, remove ONLY the pointer line this run appended and leave the rest untouched. A
     pointer that already existed before this run is not yours to remove.
  3. Re-present the FULL plan as a markdown block in chat under the terminal chat-only contract —
     the artifact is gone, so chat must carry the complete self-contained plan; the user may never
     have seen it if review happened in the annotator. Do not recreate the file, INDEX line, pointer
     or annotator flow unless the user later asks.

  Anything this run did not add is never touched.

### Review the plan file in Plannotator (if installed)

Runs only if the plan file was written. Plannotator is an optional external tool; it is a feedback
channel only and never decides anything.

1. **Detect.** Non-fatal probe:
   ```bash
   command -v plannotator
   ```
2. **Open the plan file:**
   ```bash
   plannotator annotate "$FILE"
   ```
3. **Act on the result:**
   - `annotated` with feedback → fold the annotations into the SAME file (filename stays frozen),
     refresh its INDEX.md line if the title or hook changed, and reopen the annotator if useful.
   - `approved` → no plan changes.
   - `dismissed` / empty → no plan changes.

If the CLI is absent, the probe fails, the command errors, or the session is interrupted, fall back
to presenting the full plan in chat so the user can still review it. This is a **presentation**
fallback only: the plan file, its INDEX.md line and the CLAUDE.md pointer stay in place and are NOT
undone — it is not the terminal chat-only branch. There is no automated handling for a hung
annotator session; the user interrupts it, and interruption is this same fallback.

In every case the checkpoint ends by returning to chat and summarizing the outcome. Annotator
approval alone NEVER starts implementation.

## On "go"

This governs the file branch and both terminal chat-only branches alike.

After the plan is presented, stop and wait. If the user gives feedback, update the plan; do not
restart the full interview — but if the change introduces new unresolved decisions, ask targeted
questions about that change only, same one-at-a-time rules. A revision rewrites the SAME plan file
and refreshes its INDEX.md line if the title or hook changed — but ONLY while this run's plan file
still exists. In the chat-only branches, and after a decline undid the file, revisions stay in chat
and recreate nothing.

Only an explicit chat "go" ends brainstorming, and this skill's no-code constraint ends with it:
proceed to implement the approved plan as a normal coding session, or suggest a fresh session with
the `implement` skill — pointing at the plan file path when one exists, and otherwise handing over
the full plan markdown block itself so the fresh session has something self-contained to work from.

Answer in the user's language.
