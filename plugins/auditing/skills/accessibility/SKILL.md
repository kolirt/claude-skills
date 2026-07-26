---
name: accessibility
description: Use on demand to audit whether an application's interface can be operated and understood by someone who is not using it the way the developer does — 'accessibility audit', 'a11y', 'аудит доступності', 'keyboard navigation review', 'screen-reader support', 'is this usable without a mouse'. Static read of markup, components, and interaction code across the whole application; reports findings, never fixes them and never claims WCAG conformance. Not visual-design critique, not copy review, not interface performance (that is auditing:performance), and not SEO markup (that is auditing:seo). Audits of a PR diff or a set of changes belong to the auditing-prs plugin.
---

# Accessibility audit

Judges whether the interface can be operated and understood by someone who is not using it the way
the developer does — by keyboard alone, through a screen reader, at 200% zoom, without colour
perception, or with motion suppressed.

The neighbouring domains ask whether the interface is fast, correct, or commercially coherent. This
one asks a narrower question: can the user reach the thing, know what it is, and act on it.

## 0. Preflight — stack facts this domain needs

Read `../../core/stack-detection.md`. Under the dispatcher the snapshot arrives as an input —
detection is not repeated and the snapshot is not argued with. Invoked directly, this domain runs the
script itself first.

| Fact needed | Why | When absent |
|---|---|---|
| `ui` | Locates the markup and the interaction code that produce the interface | No `ui` surface in this unit: the whole domain is `skipped: not applicable`, recorded in coverage with the missing fact |
| `architecture` (`fsd` / `flat`) | Tells shared primitives from one-off screens, so a defect in a primitive is reported once at its source | Audit files as found; note in coverage that shared-primitive attribution was not possible |
| `i18n` | Language declaration, translated accessible names, direction | Skip the language-and-translation sub-checks; record why |
| `convention_plugins` | Supplies tier 3 (see section 5) | Tiers 1 and 2 run; coverage names the missing tier |

A required fact that is absent produces `skipped: not applicable` with the reason, never an invented
finding and never a guess at what the finding would have been.

## 1. What this domain judges

### Semantics and structure

- Is each element chosen for its meaning rather than its appearance — a clickable `div` or `span`
  carrying a click handler where a `button` or a link belongs?
- Does a link navigate and a button act, rather than the two being swapped?
- Do headings form a single descending outline per page, with no level skipped and no heading used
  purely to get a font size?
- Does the page expose landmarks — a main region, navigation, a header — so a user can jump past the
  chrome?
- Are lists marked up as lists, and is a table used for tabular data rather than for layout?
- Does a data table carry header cells associated with their rows and columns?

### Keyboard operability

- Is every interactive element reachable by keyboard, and activatable once reached — including
  custom controls built out of non-interactive elements?
- Does focus order follow the visual order, rather than the DOM order diverging from the rendered
  layout or a positive `tabindex` reordering it?
- Is there any focus trap that cannot be escaped, and conversely does a modal dialog keep focus
  inside itself while open?
- Is focus placed into a dialog or overlay when it opens and restored to the trigger when it closes?
- Is visible focus indication preserved — no outline removed by styling without an equivalent
  replacement?
- Is there a way to skip repeated blocks to reach the main content?

### Names, labels and state

- Does every control have an accessible name, and does that name describe the action rather than the
  markup ("submit", not "button")?
- Is every form field associated with its label, rather than sitting next to unassociated text?
- Does an icon-only control — a close, a menu toggle, a sort arrow — name its action for a user who
  cannot see the icon?
- Is a placeholder being used as the only label?
- Is state exposed rather than only styled: expanded/collapsed, selected, checked, current,
  disabled, invalid, busy?
- Does a control whose label changes with state keep its name accurate after the change?

### Text alternatives and media

- Do images that carry meaning have alternatives that convey that meaning, not the filename?
- Are decorative images marked as decorative rather than given a redundant description?
- Do icons rendered as text or as inline SVG avoid announcing raw glyph or path noise?
- Do video and audio have captions, and does a media player expose its own controls accessibly?
- Is any information conveyed by colour alone — a status dot, a red border, a chart series — without
  a second cue in text or shape?

### Dynamic content

- Is an asynchronous update announced, or does content change silently: a loaded list, a saved
  confirmation, a validation result, a count?
- Is an error message associated with the field it belongs to, so it is heard when that field is
  reached, rather than only rendered nearby?
- Does an overlay, drawer, or modal hide the page behind it from assistive technology while open?
- Is a toast or transient message reachable and readable before it disappears?
- Can motion be reduced — does the code honour a reduced-motion preference for animation, parallax,
  and autoplaying carousels?
- Does anything move, blink, or auto-advance with no way to pause it?

### Zoom, reflow and target size

- Does content stay usable when magnified — no text clipped, no control pushed off-screen, no
  container that hides its overflow?
- Do fixed pixel widths or viewport units force horizontal scrolling of the page at narrow widths?
- Are interactive targets large enough to hit, and separated enough not to be hit by mistake?
- Is text sized in a way that respects the user's own font-size setting?

## 2. Impact dimensions

Severity is graded by what the user can no longer do, never by how the code looks. The scale itself
lives in `../../core/report-model.md`.

- **blocker** — a primary task cannot be completed at all by a keyboard user or a screen-reader
  user: a checkout that cannot be submitted, a login whose field cannot be reached, a required
  control that is invisible to assistive technology, a focus trap on a mandatory step.
- **major** — the task is completable but significantly harder (focus order that forces the user to
  re-orient on every step, unnamed controls that must be guessed), or a whole class of content is
  unavailable (every image on a catalogue lacking alternatives, an uncaptioned instructional video).
- **minor** — friction, or a standards gap with a workable path: a redundant alternative text, a
  heading level skipped in a non-navigational block, a target slightly under the recommended size.

Frequency and position matter: the same defect on a core path outranks it on a rarely reached
screen.

## 3. What this domain does NOT cover

- **Visual design quality and copy tone** — whether the interface looks good or reads well is not
  audited here. Only whether meaning survives without sight, colour, or a mouse.
- **SEO-facing markup** — `auditing:seo` owns crawler-facing concerns, and its policy lives in
  `knowledge-seo:meta-tags` and `knowledge-seo:media-seo`. The seam: an `alt` attribute is an
  accessibility obligation here and an SEO signal there. Headings are structure here and a content
  signal there. One finding is enough — the domains do not double-report the same missing attribute;
  whichever domain runs states the obligation from its own side and names the other only if the
  reader would otherwise expect a duplicate.
- **Interface performance** — `auditing:performance` owns how fast the interface loads, renders, and
  responds. A control that is slow belongs there; a control that cannot be reached belongs here.
- **Whether the flow makes business sense** — `auditing:business-analysis` owns product coherence. A
  missing cancel path is its finding; an unreachable cancel button is this domain's.
- **Correctness of the data shown** — `auditing:data` and `auditing:api-contracts` own that.

## 4. How to audit

Static reading only. Nothing is run, launched, or driven.

1. Read the entry points and routing to enumerate the reachable screens, then order them by how
   central the path is. Core paths (authentication, the primary transaction, any form that submits)
   are audited first and most thoroughly.
2. Read shared UI primitives before the screens that consume them. A defect in a shared button,
   input, dialog, or table is one finding at its source with the consuming call sites as reach, not
   one finding per screen.
3. For each screen, read markup and interaction code together: the template says what element was
   chosen, the handlers say what it actually does.
4. Establish absence deliberately. A missing accessible name, a missing label association, a missing
   captions track has no `file:line` — use the `expected surface absent` locator from
   `../../core/report-model.md`, state where the surface was expected, and state how you established
   it is not supplied elsewhere (a wrapper, a directive, a global plugin, a generated attribute).

A finding requires a stated mechanism: this element, this user, this task, blocked or degraded. A
deviation with no consequence for any user is a note or an opportunity, not a finding.

What a static audit cannot see, stated plainly and recorded in coverage as a blind spot rather than
asserted as a result:

- actual screen-reader behaviour — announcement text, order, and verbosity differ per reader and
  browser pairing;
- computed contrast at runtime, which depends on resolved theme values, images behind text, and
  states that only exist while interacting;
- real focus order under a dynamic layout, where conditional rendering and portalled content decide
  the sequence;
- anything decided by a third-party widget or an embedded document.

A finding names the guideline it rests on where one exists, so the reader can look it up. This domain
issues **no WCAG conformance claim** — not a level, not a percentage, not "compliant". Conformance is
a formal assessment involving assistive technology and human judgment; this is a static read that
finds defects.

## 5. Knowledge tiers

Tiers are defined in `../../core/report-model.md`; this section says what fills them here.

- **Tier 1 — universal operability invariants.** Every interactive element reachable and
  activatable; every control has a name; state is exposed, not only styled; meaning is not carried by
  colour alone; focus is visible, managed, and restored; content survives magnification. These hold
  regardless of stack and are always applied.
- **Tier 2 — the platform's documented accessibility semantics.** ARIA roles, states, and properties
  used as specified, plus the detected framework's own accessibility guidance for its components,
  routing, and rendering model.
- **Tier 3 — codified project conventions**, only when a `knowledge-*` plugin supplies them. For a
  Vue project the candidates are `knowledge-vue:components` and `knowledge-vue:form-elements`. Both
  dependencies are **soft**: absent, the domain runs on tiers 1 and 2 and coverage records
  "tier 3 unavailable" with the plugin named. That is a coverage fact, carrying no severity.

## 6. Report

Read `../../core/report-model.md` and follow it as written — output location, finding fields,
evidence locators, severity, confidence, opportunities, run comparison, the mandatory coverage
section, and the closing hand-off. Nothing from it is restated here.

- **Finding-id prefix:** `A11Y` — `A11Y-1`, `A11Y-2`, in report order.
- **Remediating skill:** every finding names the fully-qualified skill that owns the fix where one
  exists — `knowledge-vue:form-elements` for a control-labelling defect, `knowledge-vue:components`
  for a shared-primitive defect. Leave it empty when no skill owns the fix. The audit never applies
  the fix; `auditing:remediate` turns findings into a plan.
