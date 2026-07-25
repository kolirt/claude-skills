---
name: architecture
description: Use when a question is about the health of the module graph rather than where a file goes — an import cycle or load-order error, a module that has become a dumping ground that everything imports, suspected dead code nothing references, or a layer/boundary violation (a shared module reaching into a feature, a type that drifted into the wrong bucket). NOT for placement: "where does this file go", resolving a placement token to a path, slice/segment anatomy, and barrel rules belong to the architecture and placement core docs this skill names.
---

# Architecture integrity

A policy skill: it decides whether the existing module graph is sound. It never writes a file,
so it ships no etalon — the rules are the deliverable.

## Read first

- Read `../../core/disciplines/architecture-integrity.md` — the discipline: what each defect
  IS, how to detect it, how to resolve it.
- Read `../../core/placement.md` — the token vocabulary, so findings are reported in tokens and
  never as literal paths.

Resolve tokens to real paths through the active architecture doc
(`core/architectures/<architecture>.md`), using the `<runtime, architecture, projectType>`
project model the `vue-work` skill fixes in its Step 0. Do not re-decide the architecture here.

## The four questions this skill owns

1. **Is there a cycle?** Two modules that import each other, directly or through a chain that
   returns to its start — a violation on its own, whatever the placement tables say about each
   individual edge.
2. **Is this a god-module?** One module holding unrelated responsibilities until consumers that
   share nothing all depend on it. Judged by consumer sets, never by line count.
3. **Is this module dead?** Nothing outside it imports it, or only its own tests do — with the
   honest-detection requirements and the change-safety limit on deleting anything that may be a
   surface consumed outside this repository.
4. **Has a boundary leaked?** A module whose imports contradict the bucket its path claims: a
   generic bucket reaching into a specific one, a shared module importing a user action, a type
   or constant that drifted, or domain knowledge sitting in a domain-neutral bucket.

Anything outside those four is placement, not integrity — hand it back.

## Not this skill

- [invariant · desired] Placement questions are **not** answered here. Which bucket a new file
  belongs in, what a token resolves to, slice and segment anatomy, barrel shape, and the
  shared-bucket admission tests are owned by `../../core/architectures/fsd.md` /
  `../../core/architectures/non-fsd.md` and `../../core/placement.md`. This skill reads those
  docs to judge an existing graph; it does not restate or override them.
- [invariant · desired] Report findings in placement tokens, never in literal paths — a finding
  written as a concrete path is unusable in the other architecture.

## Reporting

- [invariant · desired] A finding names the defect, the evidence (the import chain walked, the
  consumer sets counted, the searches run), and the resolution the discipline prescribes — in
  that order. A defect asserted without its evidence is not a finding.
- [anti-pattern · desired] Refactoring the graph as a side effect of an unrelated task. Surface
  the defect, then let the developer decide whether it is fixed now or recorded.
