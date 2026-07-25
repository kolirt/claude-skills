Rule 3 (boy-scout) in a Laravel codebase.

**Editing one method in a fat controller.** A fix inside `store()` of a 400-line controller does not
license splitting the controller into form requests and actions, extracting the other six methods
into a service class, or reordering methods alphabetically — however deserved that cleanup might be.

- ✅ do: fix `store()`; leave `index()`, `update()`, `destroy()` exactly as found.
- ❌ don't: "while I'm in here" extraction of the whole controller into a service layer as a side
  effect of one bug fix.

**A migration that must not be retroactively tidied.** An already-run migration is history, not a
draft. Touching an old migration file to rename a column definition, reorder its up/down blocks, or
"clean up" its formatting corrupts the record other environments have already applied — the correct
move is always a new migration, never an edit to an old one, regardless of how untidy the old one
looks.

**A stale doc block on a line you touched.** If a fix changes a method's return type or its
parameters, the `@param`/`@return` doc block directly above it is corrected in the same edit — the
edit already made it false. A stale doc block on a different, untouched method in the same class
stays as it is and is reported separately, not silently fixed.

**A form request touched for one new rule.** Adding a single validation rule to an existing
`FormRequest::rules()` array does not license renaming its other rule keys, reordering the array, or
migrating the whole class to a different validation style the project has since adopted elsewhere.

**An Eloquent model touched for one new attribute.** Adding a `$fillable` entry or a single accessor
to a model does not license converting its other accessors to a newer casting style, alphabetising
its relations, or adding type hints to methods you did not otherwise change — each of those is a
separate, nameable piece of work, not part of the attribute addition.

**The two-gate check applied to a job you half-understand.** A queued job needs one new parameter,
but the retry logic around it is not fully understood — the touched gate is open, the understood gate
is not. The parameter is added with the minimal change the job requires; the retry logic is left
exactly as found, with a note on what was left and why, rather than "improved" on a guess.

**A stale `@deprecated` tag left on a class you now use again.** If your change reintroduces a call
to a class marked deprecated in error, correcting that tag is warranted because your edit is what made
it false — a deprecation notice elsewhere in the file, on a class you did not touch, is not yours to
correct today.
