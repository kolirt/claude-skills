---
name: plugin-registration
description: Use when wiring a Vue plugin into the app (installing + registering a package the developer's way). Skeleton — rules filled via the capture loop.
---

# plugin-registration (Vue) — skeleton

> Skeleton: the rules for this pattern are filled by the `capture` skill's loop
> (human-gated codification). Until then, this skill states the intent and, when
> invoked, MUST ask the developer for the convention rather than guessing. To
> capture, invoke the `capture` skill by name (provided by the `knowledge` base plugin).

Read `../../core/shared-wrapper-discipline.md` first (applies to any UI primitive this pattern introduces).

## Intent
Each plugin gets a registration file in the app-init location; registration files are invoked + registered at the root. Other skills (e.g. modals) defer to this skill for package registration.

## Status
Not yet captured. When invoked, run the `capture` loop for this pattern.
