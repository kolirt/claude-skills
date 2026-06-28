---
name: capture
description: Use when the developer wants to teach, capture, document, or update a coding convention or pattern (e.g. "remember how I do modals", "capture this approach", "document this pattern", "you did X wrong, here's how I want it"). Runs the human-gated capture loop and codifies the result into the relevant knowledge plugin. Stack-independent — works for any domain (Vue, Laravel, …).
---

# Capture (stack-independent)

Turn the developer's tacit/contextual conventions into tagged rules and skills.
Stack-neutral — the mechanism is identical for any stack and any domain plugin.

Read `../../core/tag-schema.md` first (rule format).
Read `../../core/codification.md` first (the only write path; owner-invoked, in the plugin repo).

## Interactive capture loop
1. Do the real work on a small **greenfield** project (greenfield = the owner
   dictates the *ideal*, so nothing from a non-ideal repo gets cemented).
2. At each decision point, **ask** the owner how they want it (e.g. "how do you
   want the modal wrapper?"). Do not guess.
3. **Draft** a tagged rule (type + `desired`/`legacy` + do/don't) and run it through
   the **codification action** right there — the owner accepts or rejects before
   anything is written. "Immediately" = without leaving the session, NOT without the
   gate.
4. **Validate**: in a clean context, re-issue the same intent; the captured skill
   should now drive it correctly.
5. **Grow**: a genuinely new pattern becomes a new skill (codification creates it in
   the right domain plugin and updates that plugin's umbrella index).

## What this skill must not do
- Never capture a `legacy` habit as an `invariant`.
- Never inline a core rule's content into a skill — reference the core module.
- (The write-gate rules — explicit owner accept, owner's repo only — live in `codification.md`.)
