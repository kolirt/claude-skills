# 07-shared — segment reference

## Segment table

| Segment | Contents |
|---|---|
| `assets/` | Static files (images, fonts, SVGs). |
| `config/` | Pure identifiers and enums — only when used by 2+ layers, zero behaviour, and no single upper-layer owner. |
| `lib/` | Mini-libraries with a clear boundary wrapping an external system, OR an app-wide UI-state singleton. Each sub-library lives in its own subfolder with an `index.ts` and a `use<Name>` composable. |
| `types/` | Type aliases and interfaces reused across 2+ layers. |
| `ui/` | Stateless, domain-neutral primitive components (buttons, inputs, typography). |
| `utils/` | Pure helper functions with broad reuse across 2+ layers. |

---

## lib vs utils

[invariant · desired] `utils/` contains **a single pure function**: no state, no lifecycle, no external-system boundary, no side effects. If any of those are present, it belongs in `lib/`.

[invariant · desired] `lib/` is **a module with a boundary**: it wraps an external system (fetch, `localStorage`, WebSocket, OAuth, analytics) OR it is an app-wide UI-state singleton (e.g. a notification queue, a modal stack). A `lib/` entry lives in a dedicated subfolder and exposes exactly `index.ts` + a `use<Name>` composable.

[invariant · desired] **All access to an external system goes through the matching `lib/`** — e.g. `localStorage` only through `lib/local-persistence`, HTTP only through `lib/http-request`. Direct calls to `localStorage`, `fetch`, etc. outside their `lib/` are an anti-pattern.

---

## Boundary rule

[invariant · desired] A function goes into `shared/utils` **only when** all three conditions hold:

1. It is broadly reused across 2+ layers.
2. It is domain-neutral (no knowledge of any entity or feature).
3. It is small and pure (no state, no side effects, no external-system calls).

If any condition fails, declare it at the call site. Dumping random helpers into `utils/` is an anti-pattern.
