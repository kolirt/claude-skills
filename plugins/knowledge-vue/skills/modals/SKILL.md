---
name: modals
description: Use when the developer asks to add a modal/dialog in a Vue project. A capability skill — detects whether the modal package is present, installs + registers it the developer's way if not, scaffolds the shared modal wrapper, and shows correct usage.
---

# Modals (Vue) — capability skill

Read `../../core/shared-wrapper-discipline.md` first (modals introduce UI that must
live in the shared wrapper, not inline).
Read `../../core/placement.md` first (where the modal wrapper file goes).
For package registration, DEFER to the `plugin-registration` skill (by name) — do
not restate registration steps here. To capture/refine any rule below, invoke the
`capture` skill by name (from the `knowledge` base plugin).

## Lifecycle
1. **Detect state.** Is the developer's modal package already installed in this
   project? If yes, skip install. No modal solution → continue.
2. **Bootstrap.** Install the modal package, then register it by deferring to the
   `plugin-registration` skill.
   <!-- CAPTURE SLOT: exact package name (e.g. vue-modal) + install/registration
        specifics — filled by the capture loop, tagged in this file. -->
3. **Scaffold.** Create the shared modal wrapper that all modals inherit, in the
   location `placement.md` dictates — never a one-off inlined dialog.
   <!-- CAPTURE SLOT: wrapper shape (base component, inheritance/contract, props/slots)
        — filled by the capture loop, tagged. -->
4. **Usage.** Show how to define and open a modal using the wrapper.
   <!-- CAPTURE SLOT: usage convention — filled by the capture loop, tagged. -->

## Status
Scaffold. Capture slots are filled via the `capture` loop (Task 12 / pilot). When
invoked before capture, ask the developer for each slot rather than guessing.
