---
name: forms
description: Use when building or editing a Vue form. Captures the developer's form discipline (single validation mechanism, ValidationForm/ValidationField wrappers). Skeleton — rules filled via the capture loop.
---

# forms (Vue) — skeleton

> Skeleton: the rules for this pattern are filled by the `capture` skill's loop
> (human-gated codification). Until then, this skill states the intent and, when
> invoked, MUST ask the developer for the convention rather than guessing. To
> capture, invoke the `capture` skill by name (provided by the `knowledge` base plugin).

Read `../../core/shared-wrapper-discipline.md` first (applies to any UI primitive this pattern introduces).

## Intent
Every form uses the developer's single validation mechanism: each field wrapped by the project's ValidationField wrapper; each form wrapped by the project's wrapper over ValidationForm.

## Status
Not yet captured. When invoked, run the `capture` loop for this pattern.
