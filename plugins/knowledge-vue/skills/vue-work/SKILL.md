---
name: vue-work
description: Use whenever doing any Vue work — creating or editing a Vue component, composable, page, store, SSR code, form, modal, or UI element. Surfaces the developer's cross-cutting Vue invariants and indexes the available Vue pattern skills. Self-activating; no manual inclusion.
---

# Vue work (umbrella)

The entry point for Vue work. It surfaces the cross-cutting invariants (by
reference) and points to the specific pattern skill for the task at hand.

Read `../../core/shared-wrapper-discipline.md` first — it applies to ALL Vue UI work
and is the most-violated rule.

## Pattern index
Pick the skill that matches the intent; it carries the specifics.

| Pattern | When | Skill |
|---|---|---|
| modals | "add a modal" / dialog work | `../modals/SKILL.md` |
| forms | building a form | `../forms/SKILL.md` |
| form elements | a new input/control | `../form-elements/SKILL.md` |
| plugin registration | wiring a Vue plugin | `../plugin-registration/SKILL.md` |
| page middlewares | route guards/middleware | `../page-middlewares/SKILL.md` |

> The index is maintained by the capture/codification action: when a new Vue pattern
> skill is added, its row is appended here.
