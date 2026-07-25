Rule 3 (boy-scout) in a Vue codebase.

**Touching one line of a template and being tempted to restructure the SFC.** A fix to one bound
attribute in a template is not license to reorder `<script>`/`<template>`/`<style>`, split the file
into sub-components, or move inline styles to a class.

- ✅ do: fix the one attribute; leave the rest of the SFC exactly as found, however it is organised.
- ❌ don't: fix a typo in a `v-bind` and, while the file is open, extract three sibling `<div>`s into
  a new component "since we're already touching this file."

**What "touched lines only" means when a change is a rename across a props interface.** Renaming a
prop in `defineProps` necessarily touches every call site that passes it — that cascade is the change
itself, not scope creep, because an unrenamed caller would be broken code, not untouched code.

- ✅ do: rename the prop, then update every template and parent component that binds it — all of
  those edits are the same task.
- ❌ don't: while renaming the prop, also reorder the other props in the same interface, or rename a
  sibling prop that was not part of the request.

**A composable touched for a bug fix, left otherwise alone.** Fixing a stale-closure bug inside one
`watch` callback of a composable does not license converting the composable's other `ref`s to
`shallowRef`, adding types to unrelated return values, or reordering its exports.

**A stale comment on a line you touched.** If you edit a line and the comment directly above it now
describes something false, that comment is corrected as part of the same edit — the fix was already
warranted, not a ride-along. A stale comment three functions away, in a file you are merely passing
through, stays untouched and is reported, not fixed, in this diff.

**A store or module-level state file touched for one new field.** Adding one field to a shared
reactive object does not license reorganising the file's other fields, switching its export shape,
or migrating it to a different state pattern the rest of the app has since moved to — that migration
is a named task of its own, not a rider on the field addition.

**The two-gate check applied to a component you half-understand.** A `computed` you must edit sits
inside a component whose surrounding `watch` logic you do not fully follow — the touched gate is open,
the understood gate is not. The minimal edit lands, the surrounding logic stays exactly as found, and
what was left and why is noted for the reviewer rather than guessed at.
