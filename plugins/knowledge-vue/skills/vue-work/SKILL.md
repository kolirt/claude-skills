---
name: vue-work
description: Use whenever doing any Vue work — creating or editing a Vue component, composable, page, route, store, SSR code, form, modal, or UI element. Indexes the available Vue pattern skills. Self-activating; no manual inclusion.
---

# Vue work (umbrella)

The entry point for Vue work — it points to the specific pattern skill for the task
at hand. Each pattern skill carries its own rules and (via `placement.md`) its own
file placement.

## Always-on SEO rule

- [invariant · desired] Before finishing ANY change that adds visible content, classify
  it against the content→schema recognition table (the single source of truth is the
  `structured-data` skill's `references/recognition.md`) and fill the matching schema +
  meta WITHOUT being asked — SEO baseline is a reflex, not an opt-in. The user cannot
  enumerate every trigger, so the trigger is intentionally broad: "adding or changing
  visible content". Defer schema specifics to the `structured-data` skill and Vue
  delivery specifics to the `seo` skill, both by name.

## Pattern index
Pick the skill that matches the intent; it carries the specifics.

| Pattern | When | Skill |
|---|---|---|
| modals | "add a modal" / dialog work | `../modals/SKILL.md` |
| vue-router | set up / configure the router | `../vue-router/SKILL.md` |
| pages | "create a page" / add a route / redirect | `../pages/SKILL.md` |
| layouts | create / wire a page layout | `../layouts/SKILL.md` |
| page middlewares | write a route guard/middleware | `../page-middlewares/SKILL.md` |
| http-request | the shared request wrapper (transport) | `../http-request/SKILL.md` |
| tanstack-query | fetch/mutate data, invalidate cache by key | `../tanstack-query/SKILL.md` |
| auth | login / logout / auto-logout / auth gating | `../auth/SKILL.md` |
| plugin registration | wiring a Vue plugin | `../plugin-registration/SKILL.md` |
| forms | building a form | `../forms/SKILL.md` |
| form elements | a new input/control (reka-ui) | `../form-elements/SKILL.md` |
| architecture-fsd | FSD folder structure / domain slices | `../architecture-fsd/SKILL.md` |
| stores | Pinia store setup / state management | `../stores/SKILL.md` |
| persistence | persisting state (localStorage / cookies) | `../persistence/SKILL.md` |
| hydration | SSR hydration, mismatch fixes | `../hydration/SKILL.md` |
| ssr | server-side rendering setup | `../ssr/SKILL.md` |
| seo | baseline meta/OG/JSON-LD on a Vue page | `../seo/SKILL.md` |
| robots | robots.txt + sitemap generation | `../robots/SKILL.md` |
| project-init | scaffold a new Vue project from scratch | `../project-init/SKILL.md` |

> The index is maintained by the capture/codification action: when a new Vue pattern
> skill is added, its row is appended here. Cross-cutting UI invariants (the shared
> reka-ui wrapper discipline) will return as part of the reka-ui capture.
