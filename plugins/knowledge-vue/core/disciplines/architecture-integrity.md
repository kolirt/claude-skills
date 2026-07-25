# Architecture integrity (Vue) — module-graph health

Applies to ALL Vue work. The placement docs answer **where a file goes**; this file answers
**whether the module graph is sound** — the four defects that survive correct placement:
import cycles, god-modules, dead modules, and cross-layer leakage.

Referenced by the `architecture` skill. Every location is written as a placement token
(`../placement.md`); resolve tokens through the active `../architectures/<a>.md`.

## Covered elsewhere — deliberately not repeated here

- `../architectures/fsd.md` — the layer table and every token's FSD path; the "where does it
  go" decision order; **§4** the import-DOWN-only direction rule, the no-same-layer-slice-imports
  rule, the entity-to-entity `@x` type-only exception, and app/shared being layer+segment with
  free intra-layer imports; **§5** slice/segment anatomy, the barrel-per-slice and
  barrel-per-segment rules, and transport types belonging with the api calls; **§6** the
  role-to-location table; **§7** the shared-layer segment contents, the utils-vs-lib admission
  test, the external-system-through-lib rule, and the no-mega-barrel rules; **§8** routing
  buckets are not interchangeable.
- `../architectures/non-fsd.md` — every token's flat-source path; **§2** slices exist without
  layers, and the explicit statement that a flat source root has **no** import-down-only rule
  and no `@x` notation; **§3** what goes where; **§4** barrels, the shared-module boundary
  rules, and assets; **§5** api typing; **§6** bootstrap and routing buckets.
- `routing-discipline.md` — routes referenced by name, the single configurable fallback route,
  and 404 being implicit.
- `../placement.md` — the token vocabulary and each token's role, per-consumer rendering, the
  bucket-not-path rule, the `// @arch-relative` escape, and naming conventions.
- `../../skills/vue-work/SKILL.md` — Step 0 project model (`runtime`, `architecture`,
  `projectType` as session constants), the pattern index, the reference-first etalon rule, and
  the always-on SEO rule.

Nothing above is restated below. Where a rule here builds on one of them, it points at it.

## 1. Import cycles

- [invariant · desired] **A cycle is a violation in its own right**, independent of whether
  each edge is individually legal. Two modules that import each other — directly, or through a
  chain that returns to its start — are one module with a boundary drawn through its middle.
  Placement rules judge single edges; nothing else in this plugin judges the walk.
- Detection: from a module's barrel, follow its imports outward; if the walk reaches that same
  barrel again, that is the cycle, and the chain you walked is the evidence. Symptoms that
  point at one before you walk it: a binding that is `undefined` at module-evaluation time and
  defined later; an import that only works when moved inside a function body; a barrel that
  must be imported lazily to load at all; a module that passes its test alone and fails in a
  suite.
- Resolution — take the first that applies:
  1. **Invert the dependency.** The module that owns the data holds no reference to its
     consumer; the consumer imports it.
  2. **Extract the shared piece to the lower, more generic bucket** both sides may already
     import — `{shared-utils}` for a pure helper, `{shared-lib}` for a boundary module,
     `{shared-config}` for a value constant, or an `{entity}` both sides already depend on.
     Admission rules for those buckets are the architecture doc's, not this file's.
  3. **Move the trigger to the consumer.** If A imports B only to fire it on something A owns,
     A should accept it instead — via slot, prop, or callback wired at the call site.
- [anti-pattern · desired] Breaking a cycle by deferring the import — a dynamic `import()`
  inside a function, or re-importing inside a composable body — purely to silence the
  load-order error. The cycle is intact; only its symptom moved, and the next consumer meets it
  again.
- [anti-pattern · desired] Breaking a cycle by duplicating the shared piece into both modules.
  Two copies drift, and the second reader cannot tell which one is authoritative.
- **FSD — mechanical.** Any cycle needs at least one upward edge or one same-layer sibling
  edge, both already banned by `../architectures/fsd.md` §4, so a cycle across layers is caught
  twice over. The exception is the layer+segment buckets (`{app}`, the shared segments), where
  §4 permits free intra-layer imports — inside those, this cycle rule is the **only** guard.
- **Flat source — judgment call.** `../architectures/non-fsd.md` §2 states there is no
  direction rule to violate, so no single edge looks wrong and the cycle itself is the only
  detectable defect. Establish the intended direction from the bucket roles in
  `../placement.md`, then invert the edge that contradicts it.

## 2. God-modules

- [anti-pattern · desired] A **god-module**: one module that accumulates unrelated
  responsibilities until most of the codebase imports it. It breaks no placement rule — it is
  sitting in a legal bucket — yet it makes every consumer depend on every reason it changes.
- Observable symptoms. Two or more together mean god-module; one alone may just be a popular
  module:
  - it is imported by consumers that have nothing to do with each other (an auth flow and a
    chart both reach into it);
  - the public surface grows on every unrelated task — each new consumer adds an export rather
    than using one;
  - the name has become a **category, not a thing** (`common`, `helpers`, `misc`, `manager`,
    `service`): a name no addition can ever contradict;
  - its own imports span buckets with no relation to each other;
  - its boundary cannot be stated in one sentence without "and".
- [invariant · desired] **Split by consumer, not by file size.** Group the exports by who
  imports them; every group whose consumer sets do not overlap becomes its own module with its
  own barrel, placed by the normal rules for what it now is. A long module with one coherent
  boundary and one consumer set is healthy; a short one imported by six unrelated consumers is
  not. Line count is not the signal.
- [anti-pattern · desired] Splitting by length or by ordinal (`helpers-a`, `utils2`,
  "part 2 of the module"). The import count is unchanged and every consumer now imports two
  modules instead of one.
- Not god-modules: a boundary module in `{shared-lib}`, a primitive family in `{shared-ui}`,
  or a value-constant module in `{shared-config}`. A wide importer count is their design; the
  test is **unrelated responsibilities inside one module**, never popularity.
- **FSD — mechanical for the destination.** Once the exports are grouped, the layer table fixes
  where each group lands: a group whose consumers all sit in one layer moves to a bucket that
  layer may import; a genuinely cross-layer group stays shared and must pass that layer's
  admission test in `../architectures/fsd.md` §7.
- **Flat source — judgment call for the destination.** Sibling buckets carry no ordering, so
  "which bucket may hold this group" has no numeric answer; decide from the role definitions in
  `../placement.md`, and prefer moving a group to its single consumer over leaving it shared.

## 3. Dead modules

- [invariant · desired] A module is **dead** when nothing outside itself imports it: no other
  module imports its barrel, and its only importers are its own internal files or its own
  tests.
- Establishing "nothing imports this" **honestly** — all of the following, or the claim is not
  established:
  - search for the barrel specifier **and** each exported identifier separately: a
    barrel-only search misses a deep import (itself a barrel violation), an identifier-only
    search misses a re-export that renames;
  - search outside the source tree too — `{project-root}` build config, entry files, and any
    server bundle entry can be a module's only importer;
  - account for **non-static** references: a glob-based resolver, an auto-registered route or
    layout, a component resolved by name from a template, a runtime plugin registry. A module
    reached only by a glob pattern or by name is **alive**, and no import search will show it.
- [anti-pattern · desired] Concluding "nothing imports this" from a single search for one
  identifier over the source tree, then deleting.
- [invariant · desired] A module whose only importers are its own tests is dead code with a
  test keeping it warm. Delete both, or wire it to a real consumer — the test is not a consumer
  and never justifies keeping it.
- [invariant · desired] **Deletion is governed by change safety, not by import count.** An
  unused export may be a public surface someone outside this repository consumes — a published
  package entry, a server-bundle entry, a documented extension point, a contract a framework
  reads at runtime. When the module or the export is part of a surface that leaves the
  repository, it is **unused in-repo, not dead**: report it and leave it.
- Resolution, once genuinely dead: remove the module, its entry in the parent barrel, and its
  tests together. A barrel line pointing at a deleted module, or a test file left behind, is a
  second defect created by the fix.
- **FSD — mechanical at the extremes.** The layer table bounds the search: only lower-numbered
  layers can import a given module, so the set of files to check is finite and known. The
  composition-root layer is imported by nothing by design, so absence of importers there is
  expected and proves nothing.
- **Flat source — judgment call.** With sibling buckets, any module may legally import any
  other, so the search is the whole source tree with no shortcut, and the decision rests on the
  change-safety rule above rather than on where the module sits.

## 4. Cross-layer leakage

The placement tables *imply* a direction of dependency. Only FSD states it as a rule
(`../architectures/fsd.md` §4); the defects below are violations in **both** architectures and
are named as violations here.

- [invariant · desired] **The bucket a module sits in is a claim; its imports are evidence.**
  When the two disagree, the file is a leak — whether or not any single import breaks a stated
  rule. Detect by listing the buckets a module imports from and comparing them with its own.
- The four checkable forms:
  1. **Upward reach.** A more generic module imports a more specific one: `{shared-lib}`,
     `{shared-ui}`, `{shared-utils}`, or `{shared-config}` importing an `{entity}`,
     `{feature}`, `{widget}`, or a page-layer module; an `{entity}` importing a `{feature}`; a
     `{composition}` importing a `{feature}` or `{widget}`.
  2. **A shared bucket importing a feature** — the same defect at its most visible: a
     domain-neutral primitive now knows about one user action, and every other consumer of that
     primitive inherits the dependency.
  3. **Drift of a type or constant.** Count the distinct buckets that import the identifier: a
     shared-bucket type or constant with exactly one consumer belongs back at that consumer; a
     slice-local one imported by 2+ buckets belongs in the shared bucket whose role in
     `../placement.md` matches what it is (a type, or a value constant — not whichever is
     nearer).
  4. **Domain knowledge with no illegal import at all.** A domain-neutral bucket whose file
     names a specific entity in its identifiers, branches on a domain enum, or hard-codes an
     endpoint is leaking even with a clean import list. Read the identifiers, not only the
     imports.
- Resolution: move the module to the bucket its imports already imply, or remove the import
  that contradicts its bucket — invert it, or accept the value as a parameter or slot instead
  of importing it.
- [anti-pattern · desired] Hiding the direction behind a re-export: a barrel in a generic
  bucket that re-exports a specific module. The dependency is unchanged and now has a
  respectable-looking specifier.
- [anti-pattern · desired] Legitimising a runtime leak by moving only the imported symbol's
  *type* into a shared bucket while the runtime import stays. FSD names exactly one type-only
  escape hatch (`../architectures/fsd.md` §4); there is no second one, and a flat source root
  has none.
- **FSD — mechanical.** Compare the two layer numbers; a higher-numbered module importing a
  lower-numbered one is the leak, and no judgment is involved.
- **Flat source — judgment call.** Sibling buckets have no numbers, so rank them by the roles
  in `../placement.md` — page-level assembly depends on widgets and features, those on
  compositions and entities, those on the shared buckets — and treat that ranking as the
  direction the tables imply. Record the ranking decision once per project rather than
  re-deriving it per file.
