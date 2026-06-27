# Codification action (stack-independent)

The **only** path that writes plugin content. Run **by the owner, deliberately,
inside the relevant plugin repo** (`knowledge` / `knowledge-vue` / …). Stack-neutral:
it writes Vue or Laravel content identically.

Read `tag-schema.md` for the rule format this action emits.

## Inputs
- An approved rule/pattern description (from the capture loop, or an observer
  notification the owner chose to act on).

## Procedure
1. **Locate target.** Decide whether this belongs in an existing skill/core module
   or a new one. Run an **overlap check** against existing skills (by intent and by
   the rule's subject): if it overlaps, the action is **update**, not create —
   duplicates cause drift.
2. **Pick the domain plugin.** A Vue pattern lands in `knowledge-vue`, a Laravel
   pattern in `knowledge-laravel`. The owner is working in that repo; place it there.
   There is **no automatic cross-project or cross-plugin write** — the agent only
   edits the repo the owner is in.
3. **Draft.** Produce the exact file edit: a tagged rule bullet (per tag-schema),
   or a new skill scaffold, with `desired`/`legacy` set from what the owner said.
4. **Show + gate.** Present the precise diff/draft. **No write without an explicit
   owner accept.** Accept or reject.
5. **On accept, write.** Apply the edit.
6. **Index upkeep.** If a **new** pattern skill was created, append its row to that
   domain's umbrella index (e.g. `knowledge-vue/skills/vue-work/SKILL.md`): name +
   one-line intent + skill path.

## Who initiates vs who gates
- The agent **may open** this action on its own (e.g. inline during the capture loop).
- The **write** needs the owner's explicit accept on the shown draft.
- The agent never writes plugin content silently. A non-owner cannot codify — there
  is no plugin repo for them to write to.
