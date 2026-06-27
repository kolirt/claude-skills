# Placement (Vue) — where files go

The single stable reference for "where does this file belong". **Dual-mode and
project-aware**: it holds the developer's placement rules for BOTH FSD and non-FSD
projects, as a matrix of *artifact type* (page / component / store / wrapper / …)
× *architecture* (FSD / non-FSD). Placement is **decoupled from FSD** — a skill
references THIS module, never a hard-coded path.

## How a skill uses it
1. Determine the current project's architecture: the project declares it (a marker
   or convention), else detect the FSD layout. If it cannot be determined, ASK the
   developer.
2. Look up the artifact type in the branch for that architecture and place the file
   there. Example: a new page → FSD project: the pages layer per the FSD rules;
   non-FSD project: that project's pages location.

## FSD branch
<!-- CAPTURE SLOT: FSD placement rules (layers, dependency direction, slice shape,
     composition), tagged. Filled via the capture loop. -->

## Non-FSD branch
<!-- CAPTURE SLOT: non-FSD placement rules (e.g. "shared UI lives in src/shared/ui",
     "pages live in src/pages"), tagged. Filled via the capture loop. -->

> The pilot fills only the cells the test project exercises (e.g. the modal wrapper
> location for that project's architecture); the rest of the matrix grows later.
